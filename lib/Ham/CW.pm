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

Ham::CW - Morse text, timing, WAV audio and MIDI tools

=head1 SYNOPSIS

    use 5.020;
    use strict;
    use warnings;
    use Ham::CW;

    my $cw = Ham::CW->new(wpm => 20, frequency => 700);
    print $cw->encode('CQ TEST'), "\n";
    print $cw->decode('... --- ...'), "\n";  # SOS

    my $bytes = $cw->wav_bytes('SOS');
    my $result = $cw->decode_wav_bytes($bytes, frequency => 700, wpm => 20);
    print $result->text, "\n";
    for my $warning (@{$result->warnings}) {
        warn "$warning->{code}: $warning->{message}\n";
    }

This example works in memory and creates no files. To save audio instead:

    $cw->write_wav('SOS', 'cw-demo.wav');

The destination must be new. To replace it deliberately on a later run, pass
C<overwrite =E<gt> 1>. File output does not play the recording.

=head1 DESCRIPTION

Ham::CW converts text to Morse notation, timed keying events, normalized
samples, PCM WAV files and standard MIDI files. It also decodes Morse
notation, event sequences and suitable audio. CW means continuous wave;
here, keyed ON/OFF tones represent Morse marks and gaps.

The default implementation needs Perl 5.20 or later and core Perl modules.
It does not capture a microphone, play audio, control a radio or communicate
with MIDI hardware. PDL is an optional numerical backend, described below.
Audio reception is experimental and targets a single reasonably stable tone.
Inspect reception warnings before using the decoded message.

=head1 INSTALLATION AND DOCUMENTATION

From an extracted distribution or repository root, run:

    perl Makefile.PL
    make
    make test
    make install

Use the make program for your Perl installation; on Windows this may be
C<gmake>. Installation needs permission to write to Perl's library directory.
For a user-owned destination, configure with
C<perl Makefile.PL INSTALL_BASE=/your/install/directory> and add its
C<lib/perl5> directory to C<PERL5LIB> when running applications.

A source checkout can be used without installing: run scripts as
C<perl -Ilib script.pl> from the repository root. Read this reference with
C<perldoc lib/Ham/CW.pm>, or C<perldoc Ham::CW> after installation.
The distribution name is C<Ham-CW>; the Perl package is C<Ham::CW>.

=head1 TERMS AND DATA

B<WPM> means words per minute on a 50-unit reference-word scale. A dot lasts
C<1.2 / wpm> seconds. C<effective_wpm> adds longer letter/word gaps while
retaining the character speed; this is Farnsworth spacing. Actual message
duration depends on its characters. See L<Ham::CW::Encoder/TIMING>.

B<Sample rate> is samples per second, in Hz. A normalized sample is a finite
number from -1 to 1. Sample arrays are mono Perl array references, not packed
PCM bytes. B<Frequency> is the audio tone in Hz. B<PCM> (pulse-code modulation) stores each sampled value as an integer in
supported WAV files. Bit depth is the number of bits used per channel sample.

B<Events> are hashes describing alternating ON and OFF runs, measured either
in microseconds or integer sample counts. They are not sample arrays.
L<Ham::CW::Events> specifies both formats with complete examples.

Text is a Perl character string. Decode external UTF-8 bytes before passing
them as text; C<use utf8> enables UTF-8 literals in a Perl source file.
WAV/MIDI byte strings are binary data and must not be text-encoded.

=head1 OPTIONS AND DEFAULTS

Named options are passed as name/value pairs. Unknown names, duplicate names
and incomplete pairs raise C<CW_E_ARGUMENT>. Numeric options must be finite;
integer ranges below include both endpoints. Optional undefined values use
defaults or automatic estimation as specified by the receiving method.
An empty text string is valid and generates an empty event/sample sequence.

=head2 Generation defaults

C<new(%options)> accepts the following options only:

=over 4

=item * C<wpm>: 20; numeric range 1..200.

=item * C<effective_wpm>: the configured WPM; range 1..WPM.

=item * C<unknown>: C<error> (default) or C<skip> for unsupported text.

=item * C<sample_rate>: 16000 Hz; integer range 1000..384000.

=item * C<frequency>: 700 Hz, or one quarter of the sample rate when 700 is outside the valid range. Range 1..C<sample_rate / 2 - 1> Hz.

=item * C<amplitude>: 0.8; numeric range 0..1 as a fraction of full scale. Zero is silent.

=item * C<attack_ms>, C<release_ms>: 5 each; numeric range 0..1000 milliseconds. These fade the start/end of each mark; ramps are shortened to fit short marks.

=item * C<max_samples>: 10000000; integer range 1..100000000. Limits the whole generated message, including silence, even when streaming.

=item * C<backend>: C<perl> (default), C<pdl> or C<auto>.

=back

These settings configure generation. Generation methods accept per-call
overrides without changing the object. An explicitly stored
C<effective_wpm> remains in force when only C<wpm> is overridden; change both
when needed. C<block_size>, WAV bit depth and MIDI settings are per-operation
options, not constructor options.

=head2 Reception settings

Reception estimates tone and character speed unless supplied on the
receiving call. Constructor C<wpm>, C<effective_wpm> and C<frequency> are
B<not> implicit reception hints. WAV reception reads its rate from the file;
raw sample reception uses the configured sample rate unless overridden.
The backend preference is inherited in both cases.

For a known sender using Farnsworth spacing:

    my $r = $cw->read_wav('received.wav',
        frequency => 650, wpm => 20, effective_wpm => 12);

Audio reception accepts explicit speeds from 1 to 60 WPM; automatic timing
estimation covers 5..60 WPM. This accepted range is not an accuracy guarantee.
L<Ham::CW::Detector/new> lists every detector option and its range.
L<Ham::CW::Decoder/new> lists the separate event-decoding options.

=head1 METHODS

=head2 new

    my $cw = Ham::CW->new(%generation_defaults);

Validates the defaults above and returns a new object. It opens no files.

=head2 encode

    my $morse = $cw->encode($text, %encoding_options);

Returns dot/dash notation: one space between letters and C< / > between
words. Options are C<wpm>, C<effective_wpm> and C<unknown>; timing options do
not change textual notation. Unsupported symbols throw C<CW_E_SYMBOL> unless
C<unknown =E<gt> 'skip'> is selected. See L<Ham::CW::Encoder/SYMBOLS>.

=head2 decode

    my $text = $cw->decode($morse, %decoder_options);

Strictly decodes a Morse string. Spaces separate letters; slashes separate
words. Invalid syntax or unknown groups throw C<CW_E_SYMBOL>. For example,
C<... --- ...> returns C<SOS>. C<prefer_prosigns =E<gt> 1> selects operational
tokens for shared waveforms. Decoder options do not inherit generation speed.

=head2 events

    my $timed = $cw->events($text, %encoding_options);

Returns C<< {unit => 'us', segments => [...]} >>. Options are C<wpm>,
C<effective_wpm> and C<unknown>. The sequence omits a final word gap.

=head2 sampled_events

    my $sampled = $cw->sampled_events($text,
        sample_rate => 8000, %encoding_options);

Returns C<< {sample_rate => 8000, segments => [...]} >> with integer sample
counts. The rate defaults to the generation rate. Cumulative event boundaries
are rounded; too coarse a resolution raises C<CW_E_TIMING>.

=head2 decode_events

    my $result = $cw->decode_events($events, %decoder_options);

Decodes a complete timed or sampled sequence and returns a finalized
L<Ham::CW::Result>. It does not inherit generation speed. Invalid event
structure throws an exception; uncertain timing or groups produce warnings
and may produce replacement characters. See L<Ham::CW::Decoder>.

=head2 samples

    my $samples = $cw->samples($text, %generation_options);

Returns the complete normalized mono sample array. Accepts all generation
options listed above. C<max_samples> bounds the full message; a Perl array
may occupy much more memory than its equivalent PCM data.

=head2 stream_samples

    my $next = $cw->stream_samples($text, block_size => 1024);
    while (my $block = $next->()) {
        # Consume this array of normalized mono samples.
    }

Accepts generation options plus C<block_size> (4096 by default; integer
1..1000000). Returns a code reference yielding sample arrays, then C<undef>
at end of input. Each stream has its own generator. Block boundaries do not
change the waveform for a fixed backend. The total sample limit still applies.

=head2 decode_samples

    my $result = $cw->decode_samples($samples,
        sample_rate => 8000, frequency => 650, wpm => 20);

Returns a finalized Result from a mono array, processing it in 4096-sample
blocks. Accepts Detector options. The rate defaults to the object's generation
rate (16000 Hz unless changed); supply the actual rate for external arrays.
The collected input is limited to 100000000 samples; the detector frame limit
also applies. Use L</detector> for a source that supplies successive blocks.

=head2 write_wav

    my $stats = $cw->write_wav($text, $path, %wav_options);

Creates and closes a mono WAV file. Returns
C<< {state => 'FINISHED', samples => $written_count} >>. Accepts
L</generate_wav> options plus C<overwrite> (0 or 1; default 0).
See L</FILE OWNERSHIP AND REPLACEMENT> for file handling and failure behavior.

=head2 write_midi

    my $count = $cw->write_midi($text, $path, %midi_options);

Creates and closes a type-0 MIDI file; returns the file size in bytes.
Accepts L</generate_midi> options plus C<overwrite> (default 0).
MIDI contains notes and timing, not rendered audio.

=head2 read_wav

    my $result = $cw->read_wav($path, %reception_options);

Opens, decodes and closes a WAV file; returns a finalized Result. Accepts
L</decode_wav> options. Empty or uncertain reception is represented in the
Result; invalid paths, unsupported files and resource errors throw exceptions.

=head2 wav_bytes

    my $bytes = $cw->wav_bytes($text, %wav_options);

Returns a binary WAV scalar. Accepts L</generate_wav> options, without
C<overwrite>. Collects the entire encoded file in memory.

=head2 midi_bytes

    my $bytes = $cw->midi_bytes($text, %midi_options);

Returns a binary MIDI scalar. Accepts L</generate_midi> options, without
C<overwrite>. Collects the entire encoded file in memory.

=head2 decode_wav_bytes

    my $result = $cw->decode_wav_bytes($bytes, %reception_options);

Reads a binary WAV scalar and returns a finalized Result. Accepts
L</decode_wav> options. The complete WAV byte string must already be in memory.

=head2 generate_wav

    my $stats = $cw->generate_wav($text, $handle, %wav_options);

Writes a mono PCM WAV to an open binary output handle and returns writer
statistics as described under L</write_wav>. Accepts all generation options,
C<block_size> (4096; 1..1000000), C<bits> (8, 16 or 24; default 16), and
C<max_bytes> (64000000; integer 44..4294967295). The byte ceiling includes
header and padding; the sample ceiling applies separately.
The handle need not seek and remains owned by the caller.

=head2 generate_midi

    my $count = $cw->generate_midi($text, $handle, %midi_options);

Writes a standard MIDI file to an open binary output handle and returns its
byte count. Accepts C<wpm>, C<effective_wpm> and C<unknown> plus
L<Ham::CW::MIDI/new> options: C<note>, C<velocity>, C<channel>, C<program>,
C<bpm>, C<ppqn> and C<max_bytes>. Defaults include note 77, independently of
the audio oscillator frequency. The caller owns and closes the handle.

=head2 decode_wav

    my $result = $cw->decode_wav($handle, %reception_options);

Reads a complete, seekable RIFF/WAVE file from offset zero. The caller owns
the handle; the library rewinds it and leaves it open. Supported input is
mono/stereo PCM 8/16/24-bit. See L<Ham::CW::Audio/FORMATS>.

Accepts Detector options except C<sample_rate>, which comes from the header.
Additional options are C<stereo> (C<mix>, C<left> or C<right>; default C<mix>),
C<max_bytes> (64000000; 44..4294967295), and C<block_samples>
(4096; integer 1..1000000). Reader warnings propagate to the Result.

The default C<max_frames> is 24000, approximately 120 seconds including
silence. To retain a longer recording, raise C<max_frames> explicitly and
allow for greater memory use. File size and frame limits are independent.

=head2 encoder

    my $encoder = $cw->encoder(%encoding_options);

Returns a fresh L<Ham::CW::Encoder>, inheriting encoding defaults and applying
overrides. Methods are C<encode> and C<events>.

=head2 generator

    my $generator = $cw->generator(%generator_options);

Returns a fresh L<Ham::CW::Generator>, inheriting generation defaults and
applying overrides. It consumes event sequences, not text. Encoding options
such as C<wpm> belong on C<events> or C<encoder>, not this factory.

=head2 decoder

    my $decoder = $cw->decoder(%decoder_options);

Returns a fresh L<Ham::CW::Decoder> with explicit decoding options only.
Use C<feed>, C<result>, C<finish> and C<reset> for successive event blocks.

=head2 detector

    my $detector = $cw->detector(%detector_options);

Returns a fresh L<Ham::CW::Detector>, inheriting sample rate and backend.
Tone and timing are estimated unless explicitly supplied. Feed normalized
mono blocks, call C<result> for a preview, then C<finish> once input ends.
Snapshots are cumulative; do not append the same snapshot repeatedly.

=head1 FILE OWNERSHIP AND REPLACEMENT

Path methods open and close their own handles. Paths must be nonempty strings
without NUL characters. Parent directories must already exist. Existing
output paths, including symlinks, are rejected by default with C<CW_E_IO>.
On failure, a newly created output is closed and removal is attempted.

With C<overwrite =E<gt> 1>, output is first written to a temporary file in the
same directory and renamed after successful generation and close. Failure
before replacement preserves the old destination and attempts temporary-file
cleanup. Existing regular-file permission bits are preserved and symbolic-link
destinations are rejected. Replacement creates a new file identity; ownership,
ACLs and other hard links are not transferred. Replacement can fail if directory
permissions or the operating system prevent rename.

Handle methods never close caller-owned handles. Set binary mode when
opening WAV/MIDI files and check C<close> errors yourself:

    open my $out, '>:raw', 'handle-demo.wav' or die $!;
    $cw->generate_wav('SOS', $out);
    close $out or die $!;

Unlike path methods, this C<open> truncates an existing file immediately.
A failed handle write can leave partial output for the caller to discard.

=head1 RESULTS AND WARNINGS

Reception returns L<Ham::CW::Result>. C<text> may be empty, partial or contain
U+FFFD replacement characters. C<has_text> only tests nonempty text.
C<complete> means finalized, not correct. C<warnings> returns an array of
C<< {code => ..., message => ...} >> hashes. Inspect it even when text exists.
C<frequency> and C<wpm> can be undefined when estimation fails.

Result reference fields are copied on input and access. Diagnostic fields
explain analysis; they are not confidence scores. L<Ham::CW::Result> documents
every accessor, warning code and diagnostic field.

=head2 Replacement file semantics

Explicit C<overwrite =E<gt> 1> preserves an existing regular destination's
permission bits. Symbolic-link destinations, including dangling links, are
rejected with C<CW_E_IO>. A new path follows the process umask. Replacement
uses a new file identity; ownership, ACLs and other hard links are not
transferred. See F<docs/architecture.md> for the shared file contract.

=head1 ERRORS

Failures throw L<Ham::CW::Error>. Capture C<$@> immediately after C<eval>:

    my $ok = eval { $cw->encode('CQ!'); 1 };
    if (!$ok) {
        my $error = $@;
        if (ref($error) && $error->isa('Ham::CW::Error')) {
            warn $error->code . ': ' . $error->message . "\n";
        }
        else { die $error; }
    }

=over 4

=item * C<CW_E_ARGUMENT>: invalid option, value or data shape.

=item * C<CW_E_SYMBOL>: unsupported text/prosign or invalid textual Morse.

=item * C<CW_E_TIMING>: invalid event alternation or insufficient sample/tick resolution.

=item * C<CW_E_WAV_FORMAT>: unsupported or inconsistent WAV format.

=item * C<CW_E_WAV_TRUNCATED>: insufficient bytes for the declared structure.

=item * C<CW_E_IO>: open, read, write, seek, close or replacement failure.

=item * C<CW_E_RESOURCE>: configured or format size/history limit exceeded.

=item * C<CW_E_STATE>: invalid incremental lifecycle or invalidated iterator.

=item * C<CW_E_INTERNAL>: unspecified/internal failure.

=back

Validation failures preserve decoder/detector history and writer counters.
I/O failures can leave partial output; a WAV writer enters C<FAILED> and must
be replaced. No error code or successful call guarantees error-free reception.

=head1 OPTIONAL PDL BACKEND

C<perl> is the default and needs no non-core runtime dependency. C<pdl>
requires PDL 2.081 or later and fails with C<CW_E_ARGUMENT> if unavailable.
C<auto> selects PDL when loadable and otherwise uses Perl. It chooses by
availability, not measured speed. Install PDL in the Perl environment running
your application before selecting it.

Both backends use public Perl arrays and the same event/file interfaces.
Floating-point waveforms can differ slightly; a PCM value near a rounding
boundary may differ by one integer unit. Feed boundaries do not change the
waveform within one backend. PDL can be slower for short blocks or a known
single tone. Measure your workload with F<maint/benchmark.pl>.

=head1 SEE ALSO

L<Ham::CW::Encoder>, L<Ham::CW::Decoder>, L<Ham::CW::Events>,
L<Ham::CW::Generator>, L<Ham::CW::Detector>, L<Ham::CW::Audio>,
L<Ham::CW::MIDI>, L<Ham::CW::Result>, L<Ham::CW::Error>.

In the source distribution, F<docs/usage.md> is a task guide and
F<examples/workflows.pl> is a runnable tour using temporary files.
F<docs/verification.md> records dated checks and their limits.

=head1 AUTHOR

Giacomo Picchiarelli

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2026 Giacomo Picchiarelli.
Artistic License 2.0. See F<LICENSE>.

=cut
