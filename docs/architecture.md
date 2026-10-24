# Architecture

The text path is `Encoder → Morse`, or `Decoder → text`. Neither path needs
DSP or third-party Morse modules. The timing path is `Encoder → TimedEvents →
SampledEvents → Generator`. The reception path is `Audio reader → Detector →
SampledEvents → Decoder → Result`. The MIDI exporter consumes either event
representation and writes SMF type 0.

## File convenience boundary

The facade offers `write_wav(text, path)`, `write_midi(text, path)` and
`read_wav(path)`. They delegate to the existing handle methods, owning only
the handles they open. New output files use exclusive creation, so existing
files and symlinks are protected by default. Explicit `overwrite => 1` writes
a temporary sibling and renames it after successful generation and close.
Replacement creates a new file and does not preserve old permissions or
symlink identity. Callback failure closes the handle,
attempts to unlink a newly created output and rethrows the original error;
close failures become structured I/O errors. Caller-managed handle methods
retain their original ownership contract. Constructor generation timing and
tone are never implicit reception hints. `has_text` and `has_warnings` expose
result presence checks without claiming confidence.

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

The 50-unit reference-word timing uses 31 mark/element-gap units and 19
spacing units, including its terminal word gap. LIGHT is one word with that
unit count. For character rate `w` and effective rate
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

Generator, Decoder, Detector and the returned WAV writer start READY, become
ACTIVE when processing starts, and become FINISHED at EOF/finish. The Audio
helper and reader hash do not expose this state interface. Feed after finish is rejected. Resettable objects
return to READY; resetting a generator invalidates its existing iterator.
Finishing twice does not duplicate data. An I/O error makes a WAV writer
FAILED; replace it and its output rather than continuing a corrupt file.
Text/MIDI operations do not have an incremental lifecycle. Validation errors
preserve object state. Caller-owned handles are never closed by the library.

Decoder snapshots with configured WPM contain only characters whose following
gap has closed. Finish confirms the final mark group. Auto-timing and detector
snapshots remain provisional: more evidence can revise timing, thresholds and
text. Unchanged provisional snapshots and finalized results are cached.
Successful feeds invalidate provisional caches; rejected feeds preserve them.
Reset clears all cached results. Reference-valued fields are copied by their
accessors. Snapshots are not new-character deltas to append repeatedly.

## Reception assumptions

Each 5 ms frame is DC-removed and Hann-windowed. A Goertzel bank measures
candidate frequencies. Analysis uses accumulated candidate energy, spectral
purity, envelope contrast, adaptive peak/noise tracking and hysteresis; short interior impulses are merged. A five-frame median supplies the peak
seed so isolated impulses do not set the recording scale.
The symbolic decoder fits 1:3 mark durations or uses the supplied WPM.
Warnings record ambiguous timing and rejected groups. Unknown or implausible
mark groups do not become guessed words.

Global recording statistics identify the candidate tone and seed the noise
floor. Segmentation adapts its keyed-signal peak and OFF noise estimates with
hysteresis, while limiting the influence of impulse peaks. The one-second
peak decay operates on a fixed sample grid, independently of feed boundaries.
Fixed history limits bound memory; unlimited-duration reception is not part
of this version's contract.

## Optional PDL backend

The internal backend resolver accepts `perl`, `pdl`, and `auto`. Only the PDL backend
loads PDL; explicit selection fails early if unavailable. Facade construction
propagates selection to generation and PCM I/O, and reception inherits it
unless overridden. Symbolic encoding, events, decoding and MIDI remain shared.
The vector implementation uses double precision and public Perl arrays.
Detection uses squared sinusoidal projections, mathematically equivalent to
Goertzel power, with cached kernels per frame length and batches of at most
128 frames. Partial frames use the prefix of the original Hann window.
Existing validation precedes processing and retained history stays bounded.
