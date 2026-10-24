# Task guide

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
a fixed punctuation set and explicit prosigns. Other symbols and Unicode
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
contents. Existing regular-file permission bits are preserved; symbolic-link
destinations are rejected. Replacement creates a new file identity and does
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
while (my $block = $next->()) {
    $detector->feed($block);
    my $preview = $detector->result;
    # The preview is cumulative and may change; do not append it as a delta.
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
earlier text and estimates as evidence arrives. Returned snapshots remain
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
