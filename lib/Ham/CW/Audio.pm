package Ham::CW::Audio;
use 5.020;
use strict;
use warnings;
use Storable ();
use Ham::CW::_Internal::WavWriter;
use Ham::CW::_Internal::IO       qw(read_exact write_bytes with_file);
use Scalar::Util                 qw(openhandle);
use Ham::CW::_Internal::Validate qw(fail integer options samples named_arguments);
use Ham::CW::_Internal::Backend;
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(max_bytes stereo block_samples backend));
    my $policy = $args{stereo} // 'mix';
    fail('CW_E_ARGUMENT', 'stereo must be left, right or mix')
        unless $policy =~ /\A(?:left|right|mix)\z/x;
    return bless {
        stereo        => $policy,
        backend       => Ham::CW::_Internal::Backend::resolve($args{backend}),
        max_bytes     => integer('max_bytes',     $args{max_bytes}     // 64000000, 44, 4294967295),
        block_samples => integer('block_samples', $args{block_samples} // 4096,     1,  1000000)
    }, $class;
}

sub _chunks {
    my ($fh, $size) = @_;
    my ($format, $data);
    my $pos = 12;
    while ($pos < $size) {
        fail('CW_E_WAV_TRUNCATED', 'Incomplete chunk header') if $size - $pos < 8;
        my ($id, $len) = unpack('a4V', read_exact($fh, 8));
        $pos += 8;
        my $padded = $len + ($len % 2);
        fail('CW_E_WAV_TRUNCATED', 'Chunk exceeds RIFF boundary') if $padded > $size - $pos;
        if ($id eq 'fmt ') {
            fail('CW_E_WAV_FORMAT', 'Duplicate or short fmt chunk') if $format || $len < 16;
            $format = [unpack('vvVVvv', read_exact($fh, 16))];
        }
        elsif ($id eq 'data') {
            fail('CW_E_WAV_FORMAT', 'Multiple data chunks are unsupported') if $data;
            $data = [$pos, $len];
        }
        $pos += $padded;
        seek($fh, $pos, 0) or fail('CW_E_IO', 'Cannot skip WAV chunk');
    }
    fail('CW_E_WAV_FORMAT', 'WAV needs fmt and data chunks') unless $format && $data;
    return ($format, $data);
}

sub _format {
    my ($format, $data) = @_;
    my ($encoding, $channels, $rate, $byte_rate, $align, $bits) = @{$format};
    fail('CW_E_WAV_FORMAT', 'Only mono/stereo PCM 8/16/24 is supported')
        unless $encoding == 1
        && ($channels == 1 || $channels == 2)
        && ($bits == 8 || $bits == 16 || $bits == 24);
    fail('CW_E_WAV_FORMAT', 'Invalid rate or block alignment')
        if $rate < 1000
        || $rate > 384000
        || $align != $channels * $bits / 8
        || $byte_rate != $rate * $align
        || $data->[1] % $align != 0;
    return ($channels, $rate, $align, $bits);
}

sub _decode_pcm {
    my ($raw, $bits, $channels, $policy) = @_;
    my @values;
    if ($bits == 8) {
        @values = map { ($_ - 128) / 128 } unpack('C*', $raw);
    }
    elsif ($bits == 16) {
        @values = map { $_ / 32768 } unpack('s<*', $raw);
    }
    else {
        for (my $i = 0; $i < length $raw; $i += 3) {
            my $v = unpack('V', substr($raw, $i, 3) . "\0");
            $v -= 16777216 if $v >= 8388608;
            push @values, $v / 8388608;
        }
    }
    if ($channels == 2) {
        my @mono;
        for (my $i = 0; $i < @values; $i += 2) {
            push @mono,
                  $policy eq 'left'  ? $values[$i]
                : $policy eq 'right' ? $values[$i + 1]
                :                      ($values[$i] + $values[$i + 1]) / 2;
        }
        return \@mono;
    }
    return \@values;
}

sub read_file {
    my ($self, $path) = @_;
    return with_file($path, 'read', sub { $self->read($_[0]) });
}

sub write_file {
    my ($self, $path, $values, @pairs) = @_;
    my %args      = named_arguments(@pairs);
    my $overwrite = integer('overwrite', delete($args{overwrite}) // 0, 0, 1);
    return with_file($path, 'write', sub { $self->write($_[0], $values, %args) }, $overwrite);
}

sub write_blocks {
    my ($self, $path, $next, @pairs) = @_;
    fail('CW_E_ARGUMENT', 'Sample source must be a code reference') unless ref($next) eq 'CODE';
    my %args      = named_arguments(@pairs);
    my $overwrite = integer('overwrite', delete($args{overwrite}) // 0, 0, 1);
    return with_file(
        $path, 'write',
        sub {
            my $writer = $self->writer($_[0], %args);
            while (defined(my $block = $next->())) { $writer->feed($block) }
            return $writer->finish;
        },
        $overwrite
    );
}

sub read_blocks {
    my ($self, $path, $callback) = @_;
    fail('CW_E_ARGUMENT', 'Block callback must be a code reference')
        unless ref($callback) eq 'CODE';
    return with_file(
        $path, 'read',
        sub {
            my $reader = $self->reader($_[0]);
            my %metadata =
                map { ($_ => $reader->{$_}) } qw(sample_rate bits channels sample_count warnings);
            while (my $block = $reader->{next}->()) {
                $callback->($block, Storable::dclone(\%metadata));
            }
            return \%metadata;
        }
    );
}

sub reader {
    my ($self, $fh) = @_;
    fail('CW_E_ARGUMENT', 'An open file handle is required') unless openhandle($fh);
    binmode($fh)    or fail('CW_E_IO', 'Cannot set binary mode');
    seek($fh, 0, 2) or fail('CW_E_IO', 'A seekable WAV handle is required');
    my $size = tell($fh);
    fail('CW_E_RESOURCE', 'WAV exceeds max_bytes') if $size > $self->{max_bytes};
    seek($fh, 0, 0) or fail('CW_E_IO', 'Cannot rewind WAV handle');
    my ($riff, $length, $wave) = unpack('a4Va4', read_exact($fh, 12));
    fail('CW_E_WAV_FORMAT',    'Expected RIFF/WAVE') unless $riff eq 'RIFF' && $wave eq 'WAVE';
    fail('CW_E_WAV_TRUNCATED', 'RIFF size exceeds available bytes') if $length + 8 > $size;
    fail('CW_E_WAV_FORMAT',    'RIFF size is inconsistent')         if $length < 4;
    my @warnings =
        $length + 8 < $size
        ? ({code => 'CW_W_WAV_TRAILING', message => 'Ignored bytes after RIFF boundary'})
        : ();
    my ($format, $data) = _chunks($fh, $length + 8);
    my ($channels, $rate, $align, $bits) = _format($format, $data);
    seek($fh, $data->[0], 0) or fail('CW_E_IO', 'Cannot seek to WAV data');
    my $remaining = $data->[1];
    my $next      = sub {
        return unless $remaining;
        my $count = $self->{block_samples} * $align;
        $count = $remaining if $count > $remaining;
        my $raw = read_exact($fh, $count);
        $remaining -= $count;
        return Ham::CW::_Internal::PDL::decode_pcm($raw, $bits, $channels, $self->{stereo})
            if $self->{backend} eq 'pdl';
        return _decode_pcm($raw, $bits, $channels, $self->{stereo});
    };
    return {
        sample_rate  => $rate,
        bits         => $bits,
        channels     => $channels,
        sample_count => $data->[1] / $align,
        warnings     => \@warnings,
        next         => $next
    };
}

sub read {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self, $fh) = @_;
    my $reader = $self->reader($fh);
    my @out;
    while (my $block = $reader->{next}->()) { push @out, @{$block} }
    return {
        sample_rate => $reader->{sample_rate},
        bits        => $reader->{bits},
        channels    => $reader->{channels},
        warnings    => $reader->{warnings},
        samples     => \@out
    };
}

sub writer {
    my ($self, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(sample_rate sample_count bits));
    my $rate = integer('sample_rate', $args{sample_rate} // 16000, 1000, 384000);
    my $bits = integer('bits',        $args{bits}        // 16,    8,    24);
    fail('CW_E_ARGUMENT', 'bits must be 8, 16 or 24')
        unless $bits == 8 || $bits == 16 || $bits == 24;
    my $count = integer('sample_count', $args{sample_count}, 0, 4294967295);
    my $bytes = $count * $bits / 8;
    fail('CW_E_RESOURCE', 'WAV exceeds configured or RIFF limit')
        if $bytes + 44 + $bytes % 2 > $self->{max_bytes} || $bytes + 36 + $bytes % 2 > 4294967295;
    fail('CW_E_ARGUMENT', 'An open file handle is required') unless openhandle($fh);
    binmode($fh) or fail('CW_E_IO', 'Cannot set binary mode');
    write_bytes(
        $fh,
        pack(
            'a4Va4a4VvvVVvva4V',
            'RIFF',    36 + $bytes + $bytes % 2,
            'WAVE',    'fmt ', 16,     1, 1, $rate, $rate * $bits / 8,
            $bits / 8, $bits,  'data', $bytes
        )
    );
    return bless {
        fh      => $fh,
        backend => $self->{backend},
        bits    => $bits,
        count   => $count,
        written => 0,
        state   => 'READY',
        bytes   => $bytes
        },
        'Ham::CW::_Internal::WavWriter';
}

sub write {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self, $fh, $values, @pairs) = @_;
    my %args = named_arguments(@pairs);
    samples($values, 100000000);
    my $writer = $self->writer($fh, %args, sample_count => scalar @{$values});
    for (my $i = 0; $i < @{$values}; $i += 4096) {
        my $end = $i + 4095;
        $end = $#{$values} if $end > $#{$values};
        $writer->feed([@{$values}[$i .. $end]]);
    }
    return $writer->finish;
}

1;

=encoding UTF-8

=head1 NAME

Ham::CW::Audio - bounded RIFF PCM input and output

=head1 SYNOPSIS

    my $audio = Ham::CW::Audio->new(stereo => 'mix');
    open my $in, '<:raw', 'cq.wav' or die $!;
    my $reader = $audio->reader($in);
    while (my $samples = $reader->{next}->()) { $detector->feed($samples) }

=head1 METHODS

=head2 new

C<new> also accepts C<backend>: C<perl> (default), C<pdl> (requires PDL
2.081 or later), or C<auto> (PDL when available, otherwise Perl). Public
arrays, limits and lifecycle remain unchanged. See L<Ham::CW> for PDL usage.

C<new> accepts C<max_bytes> (64000000), C<block_samples> (4096), and
C<stereo> (C<left>, C<right>, C<mix>; default mix). Mix averages both channels.
C<reader(handle)> requires a readable seekable handle positioned at a complete
WAV file. It validates the entire RIFF/chunk structure before returning a hash
with C<sample_rate>, C<bits>, C<channels>, C<sample_count> and C<next> iterator.
The iterator returns normalized mono arrays or undef at EOF. Keep the handle
open and do not reposition it while reading. C<read(handle)> collects the
same data into a hash with C<samples>. It can use substantially more memory
than the byte size; prefer C<reader> for large files.

PCM unsigned 8-bit and signed little-endian 16/24-bit, mono/stereo, are
supported. Unknown chunks and odd-byte padding are skipped without loading
them. Duplicate fmt/data chunks, compressed formats, inconsistent sizes,
and misalignment are rejected. Trailing bytes outside RIFF are ignored with
a C<CW_W_WAV_TRAILING> entry in the returned C<warnings> array. RF64, WAVE64 and
extensible WAV are unsupported. Empty data is legal.

=head2 read_file, write_file

C<read_file(path)> returns the same samples/metadata as C<read(handle)> and
owns the input handle. C<write_file(path, samples, %options)> accepts the same
options as C<write(handle, samples, %options)>, owns the output handle and
returns writer statistics. Existing output files are preserved and rejected.
On failure handles close and removal of newly created output is attempted.
C<overwrite =E<gt> 1> explicitly replaces an existing destination using a
temporary sibling file, preserving old contents on generation failure.

=head2 read_blocks, write_blocks

C<read_blocks(path, callback)> reads one bounded block at a time, calling
C<callback(samples, metadata)> for each. Metadata is a fresh copy containing
C<sample_rate>, C<bits>, C<channels>, C<sample_count> and C<warnings>.
The method closes the input and returns metadata at EOF; callback exceptions
also close it and propagate. Constructor C<block_samples> controls block size.

C<write_blocks(path, next, sample_rate =E<gt> ..., sample_count =E<gt> ...,
bits =E<gt> 16)> pulls sample arrays from the C<next> code reference until
it returns undef. The declared count must exactly match the stream. It owns
the output, returns writer statistics and uses the same new-file/failure
rules as C<write_file>, including optional C<overwrite>. These methods work with PCM, without Morse decoding.

=head2 writer

C<writer(handle, sample_rate =E<gt> ..., sample_count =E<gt> ..., bits =E<gt> 16)>
returns a bounded mono writer. C<feed(array)> writes normalized samples in
[-1,1]. Positive full scale clips to the largest representable PCM integer;
other values round to nearest, halves away from zero. C<finish> checks the
exact declared count and writes padding. It is idempotent. C<state> and
C<result> report progress. Validation failures leave the writer usable; I/O
failures set FAILED. Feed after finish/failure is rejected. A failed writer
must be replaced with a new writer and fresh output handle; it cannot reset.

=head2 write

C<write(handle, samples, sample_rate =E<gt> ..., bits =E<gt> ...)>
is the collecting convenience method. Handles remain owned by the caller;
check close errors when writing files. Output streams need not seek because
the sample count is known before writing. Limits include header and padding.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
