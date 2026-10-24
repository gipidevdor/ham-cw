# Architecture

The text path is `Encoder → Morse`, or `Decoder → text`. Neither path needs
DSP or third-party Morse modules. The timing path is `Encoder → TimedEvents →
SampledEvents → Generator`. The reception path is `Audio reader → Detector →
SampledEvents → Decoder → Result`. The MIDI exporter consumes either event
representation and writes SMF type 0.

## Event boundaries

TimedEvents is `{ unit => 'us', segments => [...] }`. A segment contains
`state => 'on'|'off'` and positive integer `duration` in microseconds.
SampledEvents instead has `sample_rate` and positive integer `samples` per
segment. Empty sequences and leading/trailing OFF are legal; adjacent states
must alternate. Total duration cannot exceed 2**52 units. Sample rates are
integer Hz in 1000..384000. No input is modified.

Conversions round cumulative boundaries to nearest integer, halves upward.
They reject a conversion that would create a zero-length segment. Rounding
per segment would accumulate drift; rounding cumulative boundaries does not.
MIDI uses the same boundary rule at the encoded tempo and tick resolution.

The PARIS word contains 31 mark/element-gap units and 19 spacing units when
its terminal word gap is included. For character rate `w` and effective rate
`e`, dot duration is `1,200,000/w` microseconds, and extended spacing unit is
`(60,000,000/e - 31*dot)/19`. Generated events omit the terminal word gap.

## Incremental objects

| Component | Input | Output | Retained data |
| --- | --- | --- | --- |
| Generator | Complete event sequence | Pull iterator of sample arrays | Event copy, position |
| Audio reader | Seekable WAV handle | Pull iterator of mono sample arrays | Chunk metadata and one block |
| Audio writer | Declared count, sample blocks | PCM bytes to caller handle | Counters, one block |
| Decoder | Canonical event blocks | Cumulative Result | Bounded canonical events |
| Detector | Mono sample blocks | Provisional/final Result | One partial frame and bounded frame powers |
| MIDI | Complete event sequence | Binary SMF or file write | Bounded track bytes |

An object starts READY, becomes ACTIVE when processing starts, and becomes
FINISHED at EOF/finish. Feed after finish is rejected. Resettable objects
return to READY; resetting a generator invalidates its existing iterator.
Finishing twice does not duplicate data. An I/O error makes a WAV writer
FAILED; replace it and its output rather than continuing a corrupt file.
Atomic text/MIDI operations have no incremental lifecycle. Validation errors
preserve object state. Caller-owned handles are never closed by the library.

Decoder snapshots with configured WPM contain only characters whose following
gap has closed. Finish confirms the final mark group. Auto-timing and detector
snapshots remain provisional: more evidence can revise timing, thresholds and
text. Snapshot fields are copied. They are not a stream of new characters to
append repeatedly.

## Reception assumptions

Each 5 ms frame is DC-removed and Hann-windowed. A Goertzel bank measures
candidate frequencies. Analysis uses accumulated candidate energy, spectral
purity, envelope contrast and hysteresis; short interior impulses are merged.
The symbolic decoder fits 1:3 mark durations or uses the supplied WPM.
Warnings record ambiguous timing and rejected groups. Unknown or implausible
mark groups do not become guessed words.

The thresholds currently use statistics across the retained recording. A
rolling, continuously adaptive noise model and an indefinitely running
receiver are future work, not hidden behind the streaming API. Fixed limits
bound memory but do not establish constant-memory, unlimited-duration decoding.
