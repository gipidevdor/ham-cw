package Ham::CW;
use 5.020;
use strict;
use warnings;
use Ham::CW::Encoder;
use Ham::CW::Decoder;
use Ham::CW::Generator;
use Ham::CW::Detector;
use Ham::CW::Audio;
use Ham::CW::MIDI;
use Ham::CW::Events              ();
use Ham::CW::_Internal::IO       qw(with_file);
use Ham::CW::_Internal::Validate qw(fail options named_arguments);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args,
        qw(wpm effective_wpm frequency sample_rate amplitude attack_ms release_ms unknown backend max_samples)
    );
    my %encoder = map { exists($args{$_}) ? ($_ => $args{$_}) : () } qw(wpm effective_wpm unknown);
    my %generator = map { exists($args{$_}) ? ($_ => $args{$_}) : () }
        qw(frequency sample_rate amplitude attack_ms release_ms backend max_samples);
    Ham::CW::Encoder->new(%encoder);
    Ham::CW::Generator->new(%generator);
    return bless {encoder => \%encoder, generator => \%generator}, $class;
}

sub _encoder {
    my ($self, $args) = @_;
    my %overrides =
        map { exists($args->{$_}) ? ($_ => delete $args->{$_}) : () } qw(wpm effective_wpm unknown);
    my %config = (%{$self->{encoder}}, %overrides);
    return Ham::CW::Encoder->new(%config);
}

sub encoder {
    my ($self, @pairs) = @_;
    my %args    = named_arguments(@pairs);
    my $encoder = $self->_encoder(\%args);
    options(\%args);
    return $encoder;
}

sub encode {
    my ($self, $text, @pairs) = @_;
    return $self->encoder(@pairs)->encode($text);
}

sub events {
    my ($self, $text, @pairs) = @_;
    return $self->encoder(@pairs)->events($text);
}

sub sampled_events {
    my ($self, $text, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my $rate = delete($args{sample_rate}) // $self->{generator}{sample_rate} // 16000;
    return Ham::CW::Events::to_samples($self->events($text, %args), $rate);
}

sub decoder {
    my ($self, @pairs) = @_;
    return Ham::CW::Decoder->new(@pairs);
}

sub decode {
    my ($self, $morse, @pairs) = @_;
    return $self->decoder(@pairs)->decode($morse);
}

sub decode_events {
    my ($self, $events, @pairs) = @_;
    my $decoder = $self->decoder(@pairs);
    $decoder->feed($events);
    return $decoder->finish;
}

sub detector {
    my ($self, @pairs) = @_;
    my %args = named_arguments(@pairs);
    $args{sample_rate} //= $self->{generator}{sample_rate} // 16000;
    $args{backend}     //= $self->{generator}{backend}     // 'perl';
    return Ham::CW::Detector->new(%args);
}

sub decode_samples {
    my ($self, $values, @pairs) = @_;
    Ham::CW::_Internal::Validate::samples($values, 100000000);
    my $detector = $self->detector(@pairs);
    for (my $offset = 0; $offset < @{$values}; $offset += 4096) {
        my $end = $offset + 4095;
        $end = $#{$values} if $end > $#{$values};
        $detector->feed([@{$values}[$offset .. $end]]);
    }
    return $detector->finish;
}

sub generator {
    my ($self, @pairs) = @_;
    my %args   = named_arguments(@pairs);
    my %config = (%{$self->{generator}}, %args);
    return Ham::CW::Generator->new(%config);
}

sub _generation {
    my ($self, $text, $args) = @_;
    my $encoder   = $self->_encoder($args);
    my %overrides = map { exists($args->{$_}) ? ($_ => delete $args->{$_}) : () }
        qw(frequency sample_rate amplitude attack_ms release_ms backend max_samples);
    return ($encoder->events($text), $self->generator(%overrides));
}

sub stream_samples {
    my ($self, $text, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my ($events, $generator) = $self->_generation($text, \%args);
    options(\%args, 'block_size');
    return $generator->stream($events, $args{block_size});
}

sub samples {
    my ($self, $text, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my ($events, $generator) = $self->_generation($text, \%args);
    options(\%args);
    return $generator->generate($events);
}

sub wav_bytes {
    my ($self, $text, @pairs) = @_;
    my $bytes = '';
    open my $handle, '>:raw', \$bytes or fail('CW_E_IO', 'Cannot open in-memory WAV output');
    $self->generate_wav($text, $handle, @pairs);
    close $handle or fail('CW_E_IO', 'Cannot close in-memory WAV output');
    return $bytes;
}

sub decode_wav_bytes {
    my ($self, $bytes, @pairs) = @_;
    fail('CW_E_ARGUMENT', 'WAV bytes must be a defined scalar') if !defined($bytes) || ref($bytes);
    fail('CW_E_ARGUMENT', 'WAV bytes cannot contain Unicode characters above U+00FF')
        unless utf8::downgrade($bytes, 1);
    open my $handle, '<:raw', \$bytes or fail('CW_E_IO', 'Cannot open in-memory WAV input');
    my $result = $self->decode_wav($handle, @pairs);
    close $handle or fail('CW_E_IO', 'Cannot close in-memory WAV input');
    return $result;
}

sub midi_bytes {
    my ($self, $text, @pairs) = @_;
    my %args    = named_arguments(@pairs);
    my $encoder = $self->_encoder(\%args);
    return Ham::CW::MIDI->new(%args)->encode($encoder->events($text));
}

sub write_wav {
    my ($self, $text, $path, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my $overwrite =
        Ham::CW::_Internal::Validate::integer('overwrite', delete($args{overwrite}) // 0, 0, 1);
    return with_file($path, 'write', sub { $self->generate_wav($text, $_[0], %args) }, $overwrite);
}

sub write_midi {
    my ($self, $text, $path, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my $overwrite =
        Ham::CW::_Internal::Validate::integer('overwrite', delete($args{overwrite}) // 0, 0, 1);
    return with_file($path, 'write', sub { $self->generate_midi($text, $_[0], %args) }, $overwrite);
}

sub read_wav {
    my ($self, $path, @pairs) = @_;
    return with_file($path, 'read', sub { $self->decode_wav($_[0], @pairs) });
}

sub generate_wav {
    my ($self, $text, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    my ($events, $gen) = $self->_generation($text, \%args);
    options(\%args, qw(bits max_bytes block_size));
    my $rate    = $gen->{sample_rate};
    my $sampled = Ham::CW::Events::to_samples($events, $rate);
    my $count   = 0;
    $count += $_->{samples} for @{$sampled->{segments}};
    my $audio = Ham::CW::Audio->new(
        backend => $gen->{backend},
        exists($args{max_bytes}) ? (max_bytes => $args{max_bytes}) : ()
    );
    my $next   = $gen->stream($sampled, $args{block_size});
    my $writer = $audio->writer(
        $fh,
        sample_rate  => $rate,
        sample_count => $count,
        bits         => $args{bits} // 16
    );
    while (my $block = $next->()) { $writer->feed($block) }
    return $writer->finish;
}

sub generate_midi {
    my ($self, $text, $fh, @pairs) = @_;
    my %args    = named_arguments(@pairs);
    my $encoder = $self->_encoder(\%args);
    return Ham::CW::MIDI->new(%args)->write($fh, $encoder->events($text));
}

sub decode_wav {
    my ($self, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args,
        qw(frequency wpm effective_wpm stereo max_bytes min_frequency max_frequency frequency_step max_frames min_contrast min_purity backend block_samples)
    );
    $args{backend} //= $self->{generator}{backend} // 'perl';
    my %audio = map { exists($args{$_}) ? ($_ => delete $args{$_}) : () }
        qw(stereo max_bytes block_samples);
    $audio{backend} = $args{backend};
    my $reader   = Ham::CW::Audio->new(%audio)->reader($fh);
    my $detector = Ham::CW::Detector->new(%args, sample_rate => $reader->{sample_rate});
    while (my $block = $reader->{next}->()) { $detector->feed($block) }
    my $result = $detector->finish;
    return $result unless @{$reader->{warnings}};
    my $snapshot = $result->as_hash;
    push @{$snapshot->{warnings}}, @{$reader->{warnings}};
    return Ham::CW::Result->new(%{$snapshot});
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW - Morse text, timing and PCM tools in pure Perl

=head1 SYNOPSIS

    use Ham::CW;
    my $cw = Ham::CW->new(wpm => 20, frequency => 700);
    print $cw->encode('CQ CQ DE TESTCALL'), "\n";
    print $cw->decode('... --- ...'), "\n";
    $cw->write_wav('CQ CQ DE TESTCALL', 'cq.wav');
    $cw->write_midi('CQ CQ DE TESTCALL', 'cq.mid');
    my $result = $cw->read_wav('cq.wav');
    print $result->text, "\n";
    warn "Review reception warnings\n" if $result->has_warnings;

=head1 STATUS

Version 0.001 is an initial development release. Text/timing and PCM contracts
are specified; audio reception remains experimental. Minimum declared Perl is
5.20. See F<docs/verification.md> for versions and platforms actually tested.
No native libraries, external audio programs or network access are required.

=head1 METHODS

=head2 new

C<new> accepts C<wpm> (20), C<effective_wpm> (WPM), C<frequency> (700),
C<sample_rate> (16000), C<amplitude> (0.8), C<attack_ms> (5),
C<release_ms> (5), C<unknown> (error), C<backend> (perl),
and C<max_samples> (10000000). Unknown options raise an exception.
These configure encoding/generation; reception takes its own optional hints.

=head2 encode

C<encode(text)> returns Morse, C<decode(morse)> returns text, and
C<events(text)> returns TimedEvents. See L<Ham::CW::Encoder>,
L<Ham::CW::Decoder> and L<Ham::CW::Events> for syntax and rounding.

=head2 encoder, generator, decoder, detector

These factory methods return fresh instances of the corresponding public
classes. C<encoder(%options)> and C<generator(%options)> inherit generation
defaults, with per-call overrides. C<decoder(%options)> uses explicit decoding
options. C<detector(%options)> inherits sample rate and backend, with tone and
timing estimated unless explicitly supplied. Each instance supports the
methods and lifecycle documented by its class.

=head2 events, sampled_events, decode_events

C<events(text, %options)> accepts encoding overrides C<wpm>, C<effective_wpm>
and C<unknown>. C<encode> accepts the same overrides. They do not mutate the
object. C<decode(morse, %options)> accepts Decoder options, including
C<prefer_prosigns>. Constructor generation timing is not a decoding hint.

C<sampled_events(text, sample_rate =E<gt> ..., %encoding_options)> returns
canonical sample-count events. Its rate defaults to the configured generation
rate. C<decode_events(events, %decoder_options)> accepts either timed or
sampled events and returns a finalized Result.

=head2 samples, stream_samples

C<samples(text, %options)> returns normalized mono samples as an array
reference. C<stream_samples(text, %options)> returns an iterator yielding sample
arrays or undef at EOF. Each stream owns a fresh generator. Options override
C<wpm>, C<effective_wpm>, C<unknown>, C<sample_rate>, C<frequency>,
C<amplitude>, C<attack_ms>, C<release_ms>, C<backend> and C<max_samples>.
The stream also accepts C<block_size> (4096 default). Both methods enforce the
whole-message sample ceiling. Collected arrays can consume substantial memory.

    my $next = $cw->stream_samples('CQ TEST', block_size => 1024);
    while (my $block = $next->()) {
        # Pass the block to your own audio sink.
    }

=head2 decode_samples

C<decode_samples(samples, %detector_options)> returns a finalized Result.
Input is a mono array of finite numbers in [-1,1], up to 100000000 samples.
The sample rate defaults to the constructor rate or 16000 Hz; override it
for external samples. Frequency and timing remain independently estimated.
The detector's C<max_frames> history limit also applies. For live sources,
use C<detector>, C<feed>, C<result> and C<finish> instead.

=head2 wav_bytes, midi_bytes, decode_wav_bytes

C<wav_bytes(text, %options)> and C<midi_bytes(text, %options)> collect binary
file bytes in memory. They accept the same options as C<generate_wav> and
C<generate_midi>. C<decode_wav_bytes(bytes, %options)> decodes a binary WAV
scalar and returns a Result, accepting the options of C<decode_wav>.
These methods manage their in-memory handles. Prefer file/streaming methods
when collecting the whole file would use too much memory.

=head2 write_wav

C<write_wav(text, path, %options)> saves a WAV file and returns writer
statistics. C<write_midi(text, path, %options)> saves a new MIDI file and
returns its byte count. Options are those of C<generate_wav> and
C<generate_midi>, respectively. These methods open in binary mode and close
the file for you. The path must be a nonempty string without NUL characters.
By default existing output paths are rejected with C<CW_E_IO>, preserving
their contents.
A failed write closes the handle and attempts to remove its newly created
output. No audio playback is performed.

Use C<overwrite =E<gt> 1> to replace an existing destination explicitly. The
replacement is generated in a temporary file in the same directory, then
renamed after successful generation and close. A processing failure preserves
the existing destination. This option also applies to C<write_midi>.

=head2 write_midi

See C<write_wav> for file ownership and output-path rules, and
C<generate_midi> for MIDI options.

=head2 read_wav

C<read_wav(path, %options)> opens a WAV file in binary mode, decodes it and
closes it. It returns a L<Ham::CW::Result>, with C<text>, C<has_text>,
C<has_warnings> and C<warnings> accessors. Options are those of C<decode_wav>.
Tone and speed are estimated unless supplied explicitly on this call; the
constructor's generation settings are not reception hints. Backend preference
is inherited. For example:

    my $result = $cw->read_wav('received.wav', frequency => 650, wpm => 20);
    print $result->text if $result->has_text;
    for my $warning (@{$result->warnings}) {
        warn "$warning->{code}: $warning->{message}\n";
    }

Empty or uncertain reception is represented by result text and warnings;
I/O and invalid arguments throw L<Ham::CW::Error>. Having text or completing
processing does not certify accurate reception. File open/close errors
include C<path>, C<action> and C<reason> in their exception context.

=head2 generate_wav

C<generate_wav(text, handle, bits =E<gt> 16, max_bytes =E<gt> 64000000)>
writes a mono PCM WAV in bounded blocks and returns writer statistics.
It also accepts the per-call generation options listed under C<samples>
and C<block_size> (4096).
Handles are caller-owned; close them and check errors.

=head2 generate_midi

C<generate_midi(text, handle, %options)> writes a standard MIDI file. Options
are those of L<Ham::CW::MIDI>, plus per-call C<wpm>, C<effective_wpm>
and C<unknown>; defaults use MIDI note 77 (about 698 Hz),
independently of the audio oscillator frequency. WPM and Farnsworth timing
come from the encoder configuration. MIDI playback timbre depends on the player.

=head2 decode_wav

C<decode_wav(handle, %options)> reads a seekable WAV and returns
L<Ham::CW::Result>. Options: C<frequency>, C<wpm>, C<effective_wpm>,
C<stereo>, C<max_bytes>, C<min_frequency>, C<max_frequency>,
C<frequency_step>, C<max_frames>, C<min_contrast>, C<min_purity>, C<backend>,
C<block_samples> (4096).
The default history limit is 24000 frames (about 120 seconds); increase
C<max_frames> for longer recordings, up to 1000000 frames. Reception supports
up to 60 WPM. Omit frequency/WPM for estimation. Farnsworth reception needs
C<effective_wpm> for dependable word boundaries. Always inspect warnings;
completion does not imply reliable reception. See L<Ham::CW::Detector>.

=head1 PDL BACKEND

C<backend =E<gt> 'pdl'> enables Perl Data Language vectorized audio processing
for both WAV generation and reception. Install PDL 2.081 or later first.
C<'perl'> keeps the core-only implementation; C<'auto'> selects PDL if
loadable, falling back to Perl otherwise. Explicit PDL selection fails with
C<CW_E_ARGUMENT> when unavailable. C<decode_wav> can override the backend.
Text, event and MIDI operations retain their shared implementation.

Samples remain Perl array references. Double-precision DSP can introduce
small numerical differences, including one PCM unit near quantization ties.
The detector uses equivalent sinusoidal projections and bounded frame
batches. Performance depends on chunk sizes and frequency candidate count;
run F<maint/benchmark.pl> on the target machine. PDL requires a compatible
native installation on each platform.

=head1 ERRORS

Fatal failures throw L<Ham::CW::Error>. Stable public codes:
C<CW_E_ARGUMENT>, C<CW_E_SYMBOL>, C<CW_E_TIMING>, C<CW_E_WAV_FORMAT>,
C<CW_E_WAV_TRUNCATED>, C<CW_E_IO>, C<CW_E_RESOURCE>, C<CW_E_STATE>,
C<CW_E_INTERNAL>. Recoverable reception anomalies are code/message hashes
in Result warnings. Validation errors leave incremental objects unchanged.

=head1 STREAMING

The generator exposes a pull iterator; the WAV reader also exposes a pull
iterator. WAV output, event decoding and detection use incremental feed and
finish. Results are snapshots. All accumulators have documented limits;
this version does not provide an unlimited-duration radio receiver. See the
individual modules for lifecycle rules and retained history.

=head1 TASK GUIDE

See F<docs/usage.md> for a task-to-method table, complete workflows, option
units, errors and all streaming lifecycles. F<examples/workflows.pl> runs a
self-contained tour in temporary files.

=head1 AUTHOR

Giacomo Picchiarelli

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2026 Giacomo Picchiarelli.
Released under the Artistic License 2.0. See F<LICENSE>.

=cut
