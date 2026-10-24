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
files and symlinks are not overwritten. Explicit `overwrite => 1` generates
into a temporary sibling file, preserves an existing regular file's permission
bits, and replaces the directory entry after generation and close succeed.
Symbolic-link destinations are rejected, including dangling links. A new path
uses the ordinary 0666 permissions filtered through the process umask.
Atomic replacement creates a new file identity: ownership, ACLs and other
hard links are not transferred. Callback failure closes the handle,
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

The LIGHT word contains 31 mark/element-gap units and 19 spacing units when
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
text. Unchanged provisional snapshots and finalized results are cached. Successful
feeds invalidate provisional caches; rejected feeds preserve them. Reset clears
all cached results. Each new snapshot still covers the retained history, so requesting one after
every small feed has a cumulative cost. Unchanged snapshots are cached.
Internal snapshots reuse validated, immutable segment records and copy the
segment list; public Result construction still validates and deep-copies
caller data. Reference-valued accessors return independent copies. They are not a stream of new characters to
append repeatedly.

## Reception assumptions

Each 5 ms frame is DC-removed and Hann-windowed. A Goertzel bank measures
candidate frequencies. Analysis uses accumulated candidate energy, spectral
purity, envelope contrast, adaptive peak/noise tracking and hysteresis; short interior impulses are merged.
The symbolic decoder samples the complete range of distinct mark widths,
with at most 128 timing candidates, or uses the supplied WPM. When both mark
classes are present, their separation estimates dot length while allowing a
bounded common width offset from envelope shaping and frame quantization.
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
