# Task guide

[Overview](../README.md) · [Examples](../examples/README.md) · [Contributing](../CONTRIBUTING.md)

Start with a command or choose a library recipe. Installation, interface
selection and detailed reception limits follow the recipes.

[Commands](#command-line-use) · [Library](#library-recipes) ·
[Installation](#requirements-and-installation) · [Recovery](#when-you-need-help) ·
[Limits](#practical-limits)

## Command-line use

Installation supplies `ham-cw` and its manual. The command is a frontend to
the same library, with core-only dependencies and an optional PDL backend.

| Task | Command |
| --- | --- |
| Text to Morse | `ham-cw encode "CQ TEST"` |
| Morse to text | `ham-cw decode -- "-.. ."` |
| Timed events as JSON | `ham-cw events "SOS"` |
| Sampled events as JSON | `ham-cw events --sample-rate 8000 "SOS"` |
| WAV practice file | `ham-cw wav --wpm 20 --effective-wpm 12 --output practice.wav "CQ TEST"` |
| MIDI file | `ham-cw midi --note 77 --output practice.mid "CQ TEST"` |
| Read a recording | `ham-cw receive recording.wav` |
| Receive with hints | `ham-cw receive --frequency 650 --wpm 20 recording.wav` |
| Machine-readable reception | `ham-cw receive --json recording.wav` |
| Fail on reception warnings | `ham-cw receive --strict recording.wav` |

Use `--input FILE` for UTF-8 text files or omit positional text to read stdin.
Receive stdin is spooled to a temporary seekable file with a byte limit.
Use `--output FILE` for named text, JSON, WAV or MIDI output. Existing outputs
are preserved unless `--overwrite` is explicit; failed replacements retain
the previous file. `--output -` explicitly selects raw stdout for binary data.
Named binary files avoid shell-specific redirection behavior on Windows.
Options are case-sensitive, unabbreviated and may appear before or after
positional arguments; repeats are errors. Use `--` before dash-leading Morse.
Quote shell metacharacters and prosigns; the examples use double quotes.

Exit codes are 0 for success, 1 for empty reception or strict warnings,
2 for invalid usage/options, 3 for invalid data, resource limits or I/O errors,
and 4 for an unexpected internal failure. Text warnings and errors use stderr;
receive JSON includes its warnings in the result object. Partial text remains
available with `--strict`, but a nonzero status tells automation to inspect it.
`--help`, `--version` and `ham-cw help COMMAND` provide installed guidance.
The default text-input limit is 8192 bytes; `--max-input-bytes` may explicitly
raise it to at most 1048576. Generation and reception retain their own limits.

## When you need help

Start with `ham-cw help COMMAND`. Each help page shows an example, options
by purpose, units and defaults. Usage errors also point to that page.

| What you see | Next action |
| --- | --- |
| An option is rejected | Open help for that command. Use full, case-sensitive option names. |
| Morse beginning with a dash is parsed as an option | Add `--`: `ham-cw decode -- "-.. ."`. |
| An output file already exists | Choose a new path, or add `--overwrite` for deliberate replacement. |
| WAV or MIDI output is missing | Supply `--output practice.wav` or `--output practice.mid`. |
| A character or prosign is rejected | Check the [symbol policy](#symbol-policy); quote tokens such as `"<AR>"`. |
| No text, partial text or reception warnings | Use `--json` to inspect the result. Supply known `--frequency` and `--wpm`; include `--effective-wpm` for Farnsworth spacing. |
| Stereo reception is unexpectedly weak | Try `--stereo left` or `--stereo right`; mixing can cancel opposite-phase audio. |
| PDL is unavailable | Use `--backend perl`, or install PDL in the same Perl environment. |
| PDL does not improve speed | Compare your operation and hints with the [measured workloads](benchmarks.md). `auto` selects availability. |
| A resource limit is reached | Check recording length and the [retained-history limits](#practical-limits) before raising the corresponding limit explicitly. |

Keep decoded text and warnings together when judging a recording. For scripts,
`--strict` preserves recovered text but returns status 1 when warnings are present.
Adjust advanced thresholds only after checking tone, timing and input channel.

## Library recipes

The installed API reference is POD embedded in the public modules. From a
checkout, run `perldoc lib/Ham/CW.pm`; after installation, run `perldoc Ham::CW`.
This guide provides runnable recipes. Each Perl block is a separate script;
run it from the repository root with `perl -Ilib your-script.pl`, or without
`-Ilib` after installing Ham::CW. No external audio program is required.

## Choose the data representation

| Representation | Meaning | Example |
| --- | --- | --- |
| Text | Perl character string | `'SOS'` |
| Morse | Dot/dash groups; spaces for letters, `/` for words | `'... --- ...'` |
| Timed events | ON/OFF integer microseconds | `{unit => 'us', segments => [...]}` |
| Sampled events | ON/OFF integer sample counts at one rate | `{sample_rate => 8000, segments => [...]}` |
| Samples | Mono numbers in [-1,1]; no embedded rate | `[0, 0.1, -0.1]` |
| WAV/MIDI bytes | A complete binary file in a scalar | Returned by `wav_bytes` / `midi_bytes` |
| Result | Decoded text plus events, warnings and diagnostics | Returned by reception methods |

External text bytes must be decoded to characters first. `use utf8` enables
non-ASCII literals in Perl source; it does not decode files automatically.
Binary WAV/MIDI output must not pass through a text encoding. For text output
containing accented/replacement characters, configure the output encoding,
for example `binmode STDOUT, ':encoding(UTF-8)'`.

## Text and prosigns

```perl
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new;
print $cw->encode('CQ <AR>'), "\n";
print $cw->decode('... --- ... / - . ... -'), "\n";  # SOS TEST
print $cw->decode('.-.-.', prefer_prosigns => 1), "\n";  # <AR>
print $cw->encode('CQ!', unknown => 'skip'), "\n";
```

`<AR>` is one operational signal (prosign); `AR` is two letters. Shared
waveforms lose the original spelling, so decoding uses the documented
punctuation/prosign preference. The encoder supports A–Z, digits, accented E,
only the written signs and operational signals in ITU-R M.1677-1. The
accepted tokens are `<AR>`, `<AS>`, `<BT>`, `<CT>`, `<HH>`, `<SK>` and `<SN>`.
The ITU multiplication sign `×` shares the X signal and decodes as X.
Extended tokens `<BK>`, `<KN>`, `<KA>`, `<VE>` and `<SOS>` are rejected;
ordinary `SOS` remains three letters. Other symbols and Unicode
whitespace are rejected unless explicitly skipped. See the complete lists in
[Encoder POD](../lib/Ham/CW/Encoder.pm) and the shared-waveform table in
[Decoder POD](../lib/Ham/CW/Decoder.pm).

## Farnsworth practice and files

This recipe creates files in a temporary directory, so it can be run repeatedly.

```perl
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use Ham::CW;

my $directory = tempdir(CLEANUP => 1);
my $wav = File::Spec->catfile($directory, 'practice.wav');
my $midi = File::Spec->catfile($directory, 'practice.mid');
my $cw = Ham::CW->new(wpm => 20, effective_wpm => 12, frequency => 650);
$cw->write_wav('CQ TEST', $wav, bits => 24);
$cw->write_midi('CQ TEST', $midi, note => 77, program => 80);
my $result = $cw->read_wav($wav,
    frequency => 650, wpm => 20, effective_wpm => 12);
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
```

WPM measures character speed on a 50-unit reference scale. Effective WPM
lengthens letter/word gaps. Generation defaults to 20 WPM and ordinary spacing.
Constructor settings configure generation; reception hints must be supplied
separately. A recording can come from a different sender. WAV files supply
their rate in the header. MIDI notes/programs are independent of audio frequency;
channels are 1–16, programs 0–127. Playback sound depends on the synthesizer.

For permanent paths, replace the temporary paths with your own. Parent
directories must exist. Output creation protects existing files; use
`overwrite => 1` deliberately to prepare a replacement in a temporary sibling
and rename it after successful writing. Failed generation preserves old
contents. Existing regular-file permission bits are preserved; preparation
checks reject detected symbolic-link destinations. Inspection and rename are
separate operations, so concurrent directory-entry changes are not excluded. Replacement creates a new file identity and does
not transfer ownership, ACLs or other hard links. Cleanup is attempted on failure.

Generation calls can override defaults without changing the object. An
explicit effective speed remains in force when overriding only `wpm`, so
change both when necessary. The encoder/event decoder accept explicit 1–200
WPM; audio reception accepts 1–60 WPM and automatic estimation covers 5–60.

## Samples, streaming and incremental reception

```perl
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new(sample_rate => 8000, frequency => 650, wpm => 20);
my $next = $cw->stream_samples('SOS', block_size => 1024);
my $detector = $cw->detector(frequency => 650, wpm => 20);
my $blocks = 0;
while (my $block = $next->()) {
    $detector->feed($block);
    if (++$blocks % 8 == 0) {  # About once per second for this block size/rate.
        my $preview = $detector->result;
        # Cumulative preview: do not append it as a delta.
    }
}
my $final = $detector->finish;
print $final->text, "\n";
$detector->reset;

my $samples = $cw->samples('SOS');
my $collected = $cw->decode_samples($samples, sample_rate => 8000, wpm => 20);
print $collected->text, "\n";
```

The iterator yields sample arrays, then `undef`. The detector rate must match
the array's actual rate; raw arrays carry no rate metadata. The factory inherits
sample rate/backend, but not generation tone or speed. A known tone is optional.
Each facade stream owns an independent generator; changing block boundaries
does not change its waveform within one backend.

`finish` is idempotent and makes the object FINISHED. Feed after finish is an
error until `reset`. Validation failures preserve history. Previews can revise
earlier text and estimates as evidence arrives. Unchanged snapshots are cached;
a fresh preview after feed still sorts/resegments the history in O(N log N),
so real applications should throttle preview calls instead of calling per block. Returned snapshots remain
independent after a reset. Manual `Generator->stream` instead requires its
own READY object; reset invalidates old iterators.

`max_samples` bounds complete generation, `max_frames` bounds retained detector
features and `max_segments` bounds retained event-decoder runs. The defaults are
10,000,000 samples, 24,000 frames (about 120 seconds) and 100,000 runs. These are
separate limits, including silence. Streaming controls block-buffer size; it
does not provide unlimited-duration reception. See each module's POD for ranges.

## Custom events and MIDI export

```perl
use strict;
use warnings;
use Ham::CW;
use Ham::CW::Events qw(validate_events to_samples to_timed);
use Ham::CW::MIDI;

my $cw = Ham::CW->new;
my $timed = $cw->events('SOS');
my $sampled = to_samples($timed, 8000);
my $again = to_timed($sampled);
print validate_events($again), "\n";  # duration
my $decoder = $cw->decoder(wpm => 20);
$decoder->feed($sampled);
print $decoder->finish->text, "\n";
my $samples = $cw->generator(sample_rate => 8000)->generate($sampled);
my $midi_bytes = Ham::CW::MIDI->new(note => 77)->encode($timed);
print length($midi_bytes), " MIDI bytes\n";
```

Timed events use `unit => 'us'` and positive integer `duration` fields;
sampled events use `sample_rate` and positive integer `samples` fields.
Runs alternate `state => 'on'` and `state => 'off'`. Empty sequences and
leading/trailing OFF runs are valid. Across event-decoder feeds, equal states
at a block boundary are merged. Within each block, states must alternate.

Conversions round cumulative boundaries, avoiding per-segment drift. They
return fresh hashes but a round trip can lose resolution. Zero-length converted
runs are rejected; choose a higher rate or longer events. Sampled events must
match a generator's rate. Converting event units does not resample audio.

## Raw WAV processing and caller-owned handles

```perl
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use Ham::CW;
use Ham::CW::Audio;

my $directory = tempdir(CLEANUP => 1);
my $path = File::Spec->catfile($directory, 'raw.wav');
my $cw = Ham::CW->new(sample_rate => 8000);
my $audio = Ham::CW::Audio->new(block_samples => 1024);
my $samples = $cw->samples('SOS');
my $next = $cw->stream_samples('SOS', block_size => 1024);
$audio->write_blocks($path, $next,
    sample_rate => 8000, sample_count => scalar(@{$samples}), bits => 16);
my $metadata = $audio->read_blocks($path, sub {
    my ($block, $info) = @_;
    # Process normalized mono samples using $info->{sample_rate}.
});
print "$metadata->{sample_count} frames\n";
open my $in, '<:raw', $path or die $!;
my $recording = $audio->read($in);
close $in or die $!;
print scalar(@{$recording->{samples}}), " samples\n";
```

Audio methods do not decode Morse. Input supports seekable mono/stereo PCM
8/16/24-bit WAV. Stereo selection is `left`, `right` or default `mix`; mixing
opposite-phase signals can cancel them. Output is mono. Unsupported formats
include float/compressed/extensible WAV and placeholder streaming lengths.
Trailing bytes outside RIFF produce a metadata warning. Collecting readers
return a full sample array; block readers call your callback and return metadata.

`Audio->writer($handle, sample_count => ...)` returns a writer with `feed`,
`result`, `state` and `finish`. It requires the exact total count for the WAV
header. A failed writer has no reset: discard it and its partial output.
`Audio->reader($handle)` returns a hash with a `next` code reference for manual
pull reading. Keep caller-owned handles open while iterating and close them
yourself. Reading rewinds seekable input to zero. Output handles need not seek.

Path methods own and close handles. Callback exceptions also close owned
handles before propagating. Direct handle methods leave them open even on
failure. Opening output with `>:raw` truncates existing content immediately;
use path methods when existing-file protection is needed.

## Binary data and structured failures

```perl
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new;
my $wav = $cw->wav_bytes('SOS');
my $result = $cw->decode_wav_bytes($wav, wpm => 20);
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
my $all_fields = $result->as_hash;
my $midi = $cw->midi_bytes('SOS');

my $ok = eval { $cw->encode('CQ!'); 1 };
if (!$ok) {
    my $error = $@;
    if (ref($error) && $error->isa('Ham::CW::Error')) {
        warn $error->code . ': ' . $error->message . "\n";
    }
    else { die $error; }
}
```

Byte methods collect complete binary files in memory; file/block methods are
preferable for large data. Capture `$@` immediately after `eval`. Library error
codes identify invalid arguments/symbols/timing, WAV format/truncation, I/O,
resource limits and lifecycle errors; [Error POD](../lib/Ham/CW/Error.pm) and
[main POD](../lib/Ham/CW.pm) describe them and optional context.

Results are cumulative snapshots. `has_text` only tests nonempty text, including
replacement characters; `complete` only marks finalization. Neither certifies
accuracy. Inspect warnings even if text exists. Accessor arrays/hashes are copies;
diagnostic fields can be absent. [Result POD](../lib/Ham/CW/Result.pm) lists all
fields, warning codes and suggested checks. No confidence probability is supplied.

## Option routing and next steps

The constructor stores encoding/generation defaults only. Per-call WAV generation
also accepts `bits`, `max_bytes` and `block_size`; MIDI export accepts its separate
note/program/tempo options. `overwrite` belongs only to path-writing helpers.
Decoder options belong on event/text decoding; detector options belong on audio
reception. WAV reception adds `stereo`, `max_bytes` and `block_samples`, taking
its sample rate from the header. Unknown or duplicate option names are errors.

`block_size` means generated samples per block; `block_samples` means reader
frames per block. Rates and frequencies are Hz; attack/release values are
milliseconds. Numeric ranges/defaults and method signatures are specified in
the module POD, rather than repeated in a second option reference here.

`backend => 'perl'` needs only core Perl. `pdl` requires PDL 2.081 or later;
`auto` chooses PDL by availability, not speed. Small blocks can favor Perl.
See [verification](verification.md) for evidence boundaries and
[architecture](architecture.md) for processing/lifecycle design.

Run `perl -Ilib examples/workflows.pl` for the executable tour. Command-line
sender, receiver and MIDI examples accept `--help`; quote prosigns in shell
arguments and use `--overwrite` explicitly for repeated output. The receiver
exits 0 for nonempty text and 1 for empty text; argument/I/O errors may exit
with another nonzero status. `--json` includes warnings alongside text.

## Simultaneous stations

For distinct tones in a WAV recording, request all accepted channels:

```sh
ham-cw receive --all-stations --json received.wav
ham-cw receive --all-stations --wpm 20 --filter-bandwidth 80 received.wav
```

JSON is an array of up to eight full Results; plain output labels each line
with its candidate frequency. An empty array means no accepted station and
exit status 1. Ordinary `receive --json` instead returns one Result, including
rejection diagnostics. `--strict` returns 1 if any accepted station has warnings.
A WPM hint applies to every channel. Omit it when senders use different speeds;
a frequency hint selects one channel. `--min-snr-db` adjusts the raw tone/guard
power threshold (default 12 dB); it is not a calibrated receiver SNR control.

The library provides `read_wav_channels($path, %options)`,
`decode_wav_channels($seekable_handle, %options)` and
`decode_samples_channels($samples, %options)`. They return an array reference
of independent complete Results ordered by accumulated channel energy. The
incremental `Detector->channels` provides provisional or final snapshots.
These methods share the ordinary receive limits and options; see the
[complete Detector POD](../lib/Ham/CW/Detector.pm) for spacing, bandwidth,
latency and margin-suppression behavior. Co-channel stations cannot be
separated. Close tones, fading and noise can still cause false or missing
stations, even when text is present and no warning is emitted.

## Complete runnable scenarios

See the [executable example catalog](../examples/README.md) for the full public
API index and self-contained paths for PCM, streaming, station reception,
results, errors and CLI processes. Run a selected scenario with
`perl -Ilib examples/run-all.pl --only pcm-streams --backend auto`.

## Requirements and installation

You need Perl 5.20 or later and ExtUtils::MakeMaker 7.22 or later. The newer
MakeMaker avoids an older build-tool search-path issue and supports
installation paths containing spaces; CPAN clients install it as a configure
prerequisite, while a manual build with an older bundled MakeMaker needs
`cpanm ExtUtils::MakeMaker` first. From an extracted distribution or
repository root:

```sh
perl Makefile.PL
make
make test
make install
```

Use the make program supplied with your Perl installation (`gmake` on some
Windows installations). The final command needs write permission to Perl's
library directory. For a user-owned destination, configure with
`perl Makefile.PL INSTALL_BASE=/your/install/directory` and include its
`lib/perl5` directory in `PERL5LIB` when running applications.

To use a checkout without installing, run scripts from the repository root
with `perl -Ilib script.pl`. The CPAN distribution name is `Ham-CW`, the Perl
package is `Ham::CW`, and this repository is named `ham-cw`.


## Save and receive files

```perl
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20, frequency => 700);
$cw->write_wav('CQ TEST', 'cw-demo.wav');
$cw->write_midi('CQ TEST', 'cw-demo.mid');
my $result = $cw->read_wav('cw-demo.wav', frequency => 700, wpm => 20);
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
```

The path methods open and close their files. Parent directories must exist.
Existing output files are protected: rerunning this example raises `CW_E_IO`.
To replace these files deliberately, add `overwrite => 1` to each writing
call. Replacement is prepared in a temporary sibling and renamed only after
successful generation and close. Existing regular-file permission bits are
preserved; detected symbolic-link destinations are rejected during preparation.
Inspection and rename are separate operations, so this is not an atomic
no-symlink guarantee against concurrent directory changes. Replacement creates a
new file identity. A processing failure preserves the old
contents and attempts temporary-file cleanup.

`write_wav` returns a statistics hash containing `state` and `samples`;
`write_midi` returns its byte count. `read_wav` returns a `Ham::CW::Result`.
MIDI stores notes and timing; a separate player/synthesizer determines sound.


## Symbol policy

The repertoire is strictly [ITU-R M.1677-1](https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en),
Annex 1, Part I, sections 1.1.1–1.1.3: its letters, digits, written signs and
named operational signals.
No amateur-radio or extended Morse alphabet is enabled. `!`, `&`, `;`, `_`
and `$` are rejected. The accepted operational tokens are `<AR>`, `<AS>`,
`<BT>`, `<CT>`, `<HH>`, `<SK>` and `<SN>`; these are library mnemonics for the
ITU signals. `<BK>`, `<KN>`, `<KA>`, `<VE>` and `<SOS>` are not accepted.
`SOS` remains valid as three letters. `×` is encoded as X and decodes as X.
See [Encoder POD](../lib/Ham/CW/Encoder.pm) for the complete table and rules.


## Speed, spacing and reception

WPM means words per minute on a 50-unit reference scale. A dot lasts `1.2 / wpm`
seconds; actual message duration depends on its characters. Farnsworth practice
uses faster characters and longer gaps, for example `wpm => 20,
effective_wpm => 12`.

Constructor speed, spacing and tone configure **generation**. Supply known
`frequency`, `wpm` and Farnsworth `effective_wpm` on receiving calls separately.
WAV input supplies its own sample rate; raw sample input requires the actual
rate. Audio reception accepts explicit 1–60 WPM and estimates within 5–60 WPM.
The encoder and event decoder accept explicit speeds up to 200 WPM.

A nonempty `text` value can still be wrong, partial or contain replacement
characters. `has_text` checks presence only; `complete` means finalization.
Inspect `warnings` even when both are true. Argument, file, state and resource
failures throw `Ham::CW::Error`; uncertain reception produces Result warnings.
The [Result reference](../lib/Ham/CW/Result.pm) explains every warning and diagnostic.


## Choose an interface

| Task | Interface | Reference |
| --- | --- | --- |
| Ordinary text, samples and files | `Ham::CW` convenience methods | [POD](../lib/Ham/CW.pm) |
| Text symbols and Farnsworth events | `Ham::CW::Encoder` | [POD](../lib/Ham/CW/Encoder.pm) |
| Strict notation or incremental events | `Ham::CW::Decoder` | [POD](../lib/Ham/CW/Decoder.pm) |
| Event validation and unit conversion | `Ham::CW::Events` | [POD](../lib/Ham/CW/Events.pm) |
| Tone generation from custom events | `Ham::CW::Generator` | [POD](../lib/Ham/CW/Generator.pm) |
| Incremental sample reception | `Ham::CW::Detector` | [POD](../lib/Ham/CW/Detector.pm) |
| Raw PCM WAV without Morse decoding | `Ham::CW::Audio` | [POD](../lib/Ham/CW/Audio.pm) |
| MIDI export from custom events | `Ham::CW::MIDI` | [POD](../lib/Ham/CW/MIDI.pm) |
| Snapshots and exceptions | `Ham::CW::Result`, `Ham::CW::Error` | [Results](../lib/Ham/CW/Result.pm), [errors](../lib/Ham/CW/Error.pm) |

The API reference is POD, Perl's documentation format, embedded in each public
module and installed with it. Read it using `perldoc Ham::CW` after installation,
or `perldoc lib/Ham/CW.pm` from the checkout. Use the corresponding module name
or file path for other references. Each public method has its own section.


## Optional PDL backend

Install PDL 2.081 or later into the Perl environment running your application,
then select `backend => 'pdl'` in the constructor or supported operation.
`backend => 'perl'` is the default. `backend => 'auto'` selects PDL when loadable,
otherwise Perl; it does not benchmark the workload. PDL needs a compatible
native build. Its benefit depends on the operation: the local measurements
show faster generation and slower reception with automatic tone search;
a known tone changes the reception comparison.
See [measured timings](benchmarks.md) before selecting a backend.

Both backends use the same public arrays and file/event formats. Floating-point
values can differ slightly, including one PCM unit near a rounding boundary.
Use `perl maint/benchmark.pl --help` and `perl maint/benchmark-platforms.pl --help`
for workload measurements. [Verification](verification.md) states which checks were rerun and archives
earlier measurements.


## Practical limits

WAV input supports mono/stereo PCM 8/16/24-bit; output is mono. Stereo `mix`
averages channels and may cancel opposite-phase audio; `left` or `right` selects
one. Compressed, float, extensible WAV and unknown-length streaming headers
are unsupported. MIDI output is standard file type 0.

Generation defaults to 10,000,000 total samples. Audio detection defaults to
24,000 retained frames, approximately 120 seconds including silence; event
decoding defaults to 100,000 retained runs. Increase the corresponding
`max_samples`, `max_frames` or `max_segments` explicitly when appropriate.
Streaming reduces block-buffer size but does not remove these history limits.
Every option's range and applicable method are specified in the POD.

Reception uses independent cascaded biquad band-pass channels, Hann windows,
and a Goertzel bank (equivalent projections with PDL). A raw spectral guard
rejects weakly distinguished noise before envelope timing. Distinct overlapping
CW tones can be decoded separately: `read_wav_channels`, `decode_wav_channels`
and `decode_samples_channels` return up to eight Results, each with frequency,
text and warnings. The ordinary methods return the strongest accepted channel.
From the command line:

```sh
ham-cw receive --all-stations --json received.wav
```

A WPM hint applies to every station; omit it for independent estimates. A
frequency hint selects only that tone. The tests recover two simultaneous
messages at 150 Hz separation with 20 WPM hints and at 250 Hz separation with
independent 20/25 WPM estimates, with unequal levels and added noise. A stronger
continuous carrier is also tested. This does not establish arbitrary field
accuracy: co-channel stations cannot be separated; fading, interference, short
messages and unknown spacing can still produce wrong, partial or empty text.
Review each Result's warnings. The [verification record](verification.md)
reports the measured corpus revision, hinted and unassisted CER, and scope.
Run `perl maint/reception-corpus.pl` to repeat the measurements. The four
short beacon clips do not establish accuracy on human-keyed QSOs.

The default candidate spacing is 50 Hz. Synthetic reception tests allow tone
error within one configured grid step, an empirical tolerance rather than a
universal accuracy bound. Analysis uses approximately 20 ms Hann windows with
5 ms hops, preceded by two biquads per candidate. The window alone has about
70 Hz full half-power width. `filter_bandwidth` sets each biquad's width;
`min_snr_db` sets an acquisition tone/guard threshold, not calibrated radio SNR.
Candidate spacing, filter width and station resolving ability are distinct.
See the [Detector POD](../lib/Ham/CW/Detector.pm) for defaults, latency, memory,
station selection, margin suppression and preview limitations.
