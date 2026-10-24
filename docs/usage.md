# Ham::CW by task

Start with `use Ham::CW; my $cw = Ham::CW->new;`. File paths are strings,
text is a Perl character string, WAV/MIDI bytes are binary scalars, samples
are mono array references of numbers in [-1, 1], and events describe keyed
ON/OFF durations. No method plays sound, records a microphone, controls a
radio or sends MIDI to a device.

## Choose the operation

| You have | You want | Method | Returns |
| --- | --- | --- | --- |
| Text | Morse notation | `encode($text, %timing)` | String |
| Morse notation | Text | `decode($morse, %decoding)` | String |
| Text | Microsecond events | `events($text, %timing)` | Event hash |
| Text | Sample-count events | `sampled_events($text, %options)` | Event hash |
| Events | Text and diagnostics | `decode_events($events, %decoding)` | Result |
| Text | Audio samples in memory | `samples($text, %generation)` | Array reference |
| Text | Audio samples in blocks | `stream_samples($text, %generation)` | Iterator |
| Audio samples | Text and diagnostics | `decode_samples($samples, %reception)` | Result |
| Text | New WAV file | `write_wav($text, $path, %generation)` | Writer statistics |
| Text | New MIDI file | `write_midi($text, $path, %midi)` | Byte count |
| WAV path | Text and diagnostics | `read_wav($path, %reception)` | Result |
| Text | WAV bytes | `wav_bytes($text, %generation)` | Binary scalar |
| WAV bytes | Text and diagnostics | `decode_wav_bytes($bytes, %reception)` | Result |
| Text | MIDI bytes | `midi_bytes($text, %midi)` | Binary scalar |
| Text | WAV/MIDI on your handle | `generate_wav` / `generate_midi` | Statistics / byte count |
| WAV handle | Text and diagnostics | `decode_wav($handle, %reception)` | Result |

`new` stores generation defaults. Per-call generation options override those
defaults for that call only. Reception estimates tone and timing independently;
pass known `frequency`, `wpm` and `effective_wpm` on the receiving call.
Raw samples have no rate metadata: `decode_samples` and `detector` use the
object's sample rate unless overridden. WAV reception gets the rate from the
file. Backend preference is shared and can be overridden per call.

## Text, punctuation and prosigns

```perl
my $morse = $cw->encode('CQ <AR>');
my $text = $cw->decode('... --- ... / - . ... -');  # SOS TEST
my $operational = $cw->decode('.-.-.', prefer_prosigns => 1);  # <AR>
my $filtered = $cw->encode('CQ!', unknown => 'skip');
```

Spaces separate Morse letters; `/` separates words. `<AR>` is one prosign,
whereas `AR` is two letters. Shared punctuation/prosign waveforms lose their
original spelling; `prefer_prosigns` chooses the operational interpretation.
ASCII case is normalized. Accented E is supported; other unsupported symbols
and Unicode whitespace are rejected by default. `unknown => 'skip'` explicitly
omits unsupported tokens. Errors include the symbol and its one-based
character position; no implicit transliteration is performed.

## Speed and Farnsworth spacing

```perl
my $practice = Ham::CW->new(wpm => 20, effective_wpm => 12);
$practice->write_wav('CQ TEST', 'practice.wav');
my $received = $practice->read_wav('practice.wav', wpm => 20, effective_wpm => 12);
my $faster = $cw->samples('SOS', wpm => 30);
```

`wpm` controls character speed. `effective_wpm` slows spacing and cannot
exceed character speed. Generation defaults to 20 WPM; absent effective speed
uses character speed. An explicitly configured effective speed remains in
force when overriding WPM, so override both when necessary. Generation/event
decoding accepts configured speeds up to 200 WPM; audio reception up to 60.
Automatic timing estimation covers 5..60 WPM and can be ambiguous on short
messages. Give hints when you know them.

## Files and bytes

```perl
$cw->write_wav('CQ TEST', 'cq.wav', bits => 24, frequency => 650);
$cw->write_midi('CQ TEST', 'cq.mid', note => 77, program => 80);
my $wav = $cw->wav_bytes('SOS', sample_rate => 8000);
my $result = $cw->decode_wav_bytes($wav);
my $midi = $cw->midi_bytes('SOS', note => 60);
```

Path methods own and close their handles. By default output paths must be new; existing
files are preserved and cause `CW_E_IO`. Pass `overwrite => 1` explicitly to
replace a file. Replacement is generated in a temporary sibling file and
renamed after successful generation and closure; failed generation preserves
the previous contents. On a processing error, a newly created
output is closed and removal is attempted. Byte methods collect output in
memory; prefer file methods for large messages. MIDI export is type 0 and
includes note events, not rendered sound. MIDI notes/programs are separate
from audio frequency; programs are zero-based, channels are 1..16. WPM sets
Morse timing; BPM/PPQN set MIDI tick representation. Playback timbre depends
on the synthesizer.

For handles you own:

```perl
open my $out, '>:raw', 'handle.wav' or die $!;
$cw->generate_wav('SOS', $out);
close $out or die $!;
open my $in, '<:raw', 'handle.wav' or die $!;
my $result = $cw->decode_wav($in);
close $in or die $!;
```

These methods leave caller-owned handles open. WAV reading needs a complete,
seekable file. Output handles need not seek because the sample count is known.

## Audio arrays and bounded generation

```perl
my $samples = $cw->samples('SOS', sample_rate => 8000, amplitude => 0.5);
my $result = $cw->decode_samples($samples, sample_rate => 8000, wpm => 20);
my $next = $cw->stream_samples('CQ TEST', block_size => 1024);
while (my $block = $next->()) {
    # Pass this normalized mono block to your application's audio sink.
}
```

The iterator returns array references, then `undef` at EOF. Each call to
`stream_samples` owns an independent generator, so starting another stream
does not reset the first. Blocks preserve the same waveform as collecting
`samples`. `block_size` controls samples per output block; `max_samples`
limits the entire message even when streaming. Attack/release ramps default
to 5 ms and prevent abrupt keyed edges. Collected Perl arrays consume more
memory than packed PCM bytes.

## Incremental reception and event decoding

```perl
my $detector = $cw->detector(sample_rate => 8000, wpm => 20);
# Repeat as blocks arrive from your own audio source:
$detector->feed($samples);
my $preview = $detector->result;
my $final = $detector->finish;
$detector->reset;

my $decoder = $cw->decoder(wpm => 20);
$decoder->feed($cw->events('SOS'));
my $decoded = $decoder->finish;
```

Factories return fresh public objects. `encoder` and `generator` inherit
generation defaults; `decoder` receives explicit decoding options; `detector`
inherits sample rate/backend, with tone and timing still estimated unless
specified. `feed` takes arrays for the detector and canonical event hashes
for the decoder. Split canonical events at any boundary; adjacent equal
states across feeds are merged. Do not split text/prosign tokens arbitrarily.

`result` is a cumulative snapshot, not a delta to append. Previews can change
with more evidence; even fixed-WPM event decoding waits for closed gaps.
`finish` confirms the final group and is idempotent. Feed after finish is an
error. `reset` allows reuse; earlier snapshots remain independent. Invalid
input preserves incremental state. Sample/event histories are bounded;
streaming is not unlimited-duration radio reception.

## Read or write raw WAV samples

```perl
use Ham::CW::Audio;
my $audio = Ham::CW::Audio->new(stereo => 'left', block_samples => 1024);
my $recording = $audio->read_file('input.wav');
my $samples = $recording->{samples};
my $rate = $recording->{sample_rate};
$audio->write_file('copy.wav', $samples, sample_rate => $rate, bits => 16);

$audio->read_blocks('input.wav', sub {
    my ($block, $metadata) = @_;
    # Process $block here. $metadata includes sample_rate and warnings.
});
```

`read_file` collects normalized mono samples and metadata without decoding
Morse. `read_blocks` holds one block at a time, closes the input after the
callback loop and returns metadata. A callback exception stops reading and
closes the file. Metadata passed to callbacks is copied. The reader supports
PCM 8/16/24-bit, mono/stereo; choose `left`, `right`, or default `mix`. Mixing
can cancel opposite-phase stereo signals. Output is mono. File-level warnings,
including ignored trailing bytes, are available in metadata.

For bounded output from an iterator, declare the exact sample count for the
WAV header:

```perl
my $events = $cw->sampled_events('SOS', sample_rate => 8000);
my $count = 0;
$count += $_->{samples} for @{$events->{segments}};
my $next = $cw->stream_samples('SOS', sample_rate => 8000, block_size => 1024);
$audio->write_blocks('stream.wav', $next, sample_rate => 8000, sample_count => $count);
```

The source returns sample arrays and then `undef`. Raw `write_file`,
`write_blocks`, and MIDI `write_file` also accept `overwrite => 1`. Too few/many samples are
errors; failed output is closed and removal attempted. `Audio->reader($fh)`
provides manual pull iteration through `$reader->{next}->()` if you need
control over when blocks are read. `Audio->writer($fh, sample_count => ...)`
provides `feed`, `result`, `state` and `finish` for manual writing; keep and
close the handle yourself. After an I/O failure, replace the writer and output;
a failed writer cannot reset.

## Custom ON/OFF sequences and conversion

```perl
use Ham::CW::Events qw(to_samples to_timed validate_events);
my $timed = $cw->events('SOS');
my $sampled = to_samples($timed, 8000);
my $again = to_timed($sampled);
validate_events($again);
my $result = $cw->decode_events($sampled, wpm => 20);
my $generator = $cw->generator(sample_rate => 8000);
my $samples = $generator->generate($sampled);
```

Timed events contain `{unit => 'us', segments => [...]}`; sampled events
contain `{sample_rate => 8000, segments => [...]}`. Segments alternate
`state => 'on'|'off'` with positive integer `duration` or `samples`.
Empty events and leading/trailing OFF are legal. Conversions return copies
and round cumulative boundaries to prevent accumulated drift. Too coarse a
sample resolution can produce a zero-length segment and is rejected. Use a
higher rate in that case. Sampled events must match the generator's rate.

The manual generator offers `stream($events, $block_size)`, `result`, `state`
and `reset`. Reset invalidates an older iterator. The facade's `stream_samples`
handles ownership automatically for ordinary text generation.

Custom events can also be exported directly:

```perl
use Ham::CW::MIDI;
my $midi = Ham::CW::MIDI->new(note => 77);
$midi->write_file('custom.mid', $timed);
my $bytes = $midi->encode($timed);
```

## Results and failures

```perl
my $result = $cw->read_wav('input.wav');
print $result->text if $result->has_text;
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
my $details = $result->as_hash;

my $ok = eval { $cw->encode('CQ!'); 1 };
if (!$ok) {
    my $error = $@;
    if (ref($error) && $error->isa('Ham::CW::Error')) {
        warn $error->code . ': ' . $error->message;
        my $context = $error->context;
    }
    else { die $error; }
}
```

Result accessors include `text`, `morse`, `events`, `frequency`, `wpm`,
`warnings`, `diagnostics` and `complete`. Arrays/hashes are copies; treat
object internals as private. `has_text` means nonempty text, `has_warnings`
means warnings exist, and `complete` means finalized. None is a confidence
probability. Rejected or ambiguous audio can return empty text and warnings;
argument, file, lifecycle and resource failures throw structured exceptions.
Noise and overlapping stations are not guaranteed to decode. Inspect warnings
before accepting a message.

| Error | What to check |
| --- | --- |
| `CW_E_ARGUMENT` | Parameter name/type/range, rate, declared sample count |
| `CW_E_SYMBOL` | Unsupported character/prosign or invalid Morse grouping |
| `CW_E_TIMING` | Event alternation or sample/MIDI resolution |
| `CW_E_WAV_FORMAT` / `CW_E_WAV_TRUNCATED` | Supported PCM format and complete file |
| `CW_E_IO` | Path, permissions, existing output, readable/seekable handle |
| `CW_E_RESOURCE` | Configured ceiling or message/recording length |
| `CW_E_STATE` | Feed after finish, reset iterator or failed writer |
| `CW_E_INTERNAL` | Unexpected internal failure; preserve reproduction details |

## Options and units

| Operation | Options |
| --- | --- |
| Text encoding/events | `wpm`, `effective_wpm`, `unknown` |
| Sampled events | Encoding options plus `sample_rate` |
| Samples/streaming/WAV generation | Encoding options plus `sample_rate`, `frequency`, `amplitude`, `attack_ms`, `release_ms`, `backend`, `max_samples` |
| Sample streaming | Also `block_size` (4096 default) |
| WAV generation | Also `bits` (16), `max_bytes` (64000000), `block_size` (4096) |
| MIDI export | Encoding options plus `note`, `velocity`, `channel`, `program`, `bpm`, `ppqn`, `max_bytes` |
| Event/Morse decoder | `wpm`, `effective_wpm`, `prefer_prosigns`, `max_segments` |
| Sample reception/detector | `sample_rate`, `frequency`, `wpm`, `effective_wpm`, `min_frequency`, `max_frequency`, `frequency_step`, `min_contrast`, `min_purity`, `max_frames`, `backend` |
| WAV reception | Detector options except `sample_rate`; also `stereo`, `max_bytes`, `block_samples` |
| Raw Audio constructor | `stereo`, `max_bytes`, `block_samples`, `backend` |
| Raw Audio writing | `sample_rate`, `bits`; streaming writer also requires `sample_count` |
| All path-writing helpers | Also `overwrite` (0 or 1, default 0) |

Rates/frequencies are Hz; attack/release are milliseconds. Sample rates are
integer 1000..384000 Hz; tones must be below half the rate. `block_size` is
for generated sample blocks; `block_samples` is for WAV reader blocks.
`max_samples` limits total generation (10000000 default), `max_frames` limits
retained detector frames (24000, about 120 seconds), `max_segments` limits
decoder history (100000). Increasing these raises resource use. Frequency grid
step is candidate spacing, not filter bandwidth. Module POD lists all ranges.

`backend => 'perl'` is the default and needs no external dependency. `pdl`
requires PDL 2.081 or later; `auto` selects PDL when loadable, otherwise Perl.
It chooses by availability, not workload speed. Small blocks/known-tone
reception can favor Perl. See [verification](verification.md) and the benchmark.

## Command-line examples

```sh
perl -Ilib examples/send.pl --wpm 20 --effective-wpm 12 --frequency 650 cq.wav 'CQ <AR>'
perl -Ilib examples/receive.pl --wpm 20 --effective-wpm 12 --frequency 650 --json cq.wav
perl -Ilib examples/midi.pl --wpm 20 --note 77 --program 80 cq.mid 'CQ TEST'
```

All three support `--help`. Output paths must be new unless the sender/MIDI
command receives `--overwrite`. The receiver prints
text normally or the full result with `--json`, and exits 0 for nonempty text,
1 for empty text. JSON includes warnings; nonempty text is not certification
of reception. Quote prosigns so the shell does not interpret angle brackets.
Run `perl -Ilib examples/workflows.pl` for a self-contained tour using temporary
files. See [architecture](architecture.md) for exact event/lifecycle contracts.
