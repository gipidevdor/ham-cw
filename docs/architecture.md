# Architecture

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Contributing](../CONTRIBUTING.md)

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
Preparation rejects detected symbolic-link destinations, including dangling
links. Inspection and rename are separate filesystem operations: a destination
changed concurrently after inspection can still be replaced. This helper does
not provide an atomic no-symlink guarantee; use a directory whose entries are
not being changed by other writers. A new path
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

Samples advance on a fixed approximately 5 ms hop grid. Every candidate
frequency has two persistent constant-peak biquad band-pass sections in
transposed direct form II. Original code implements the mathematical BPF
coefficients in the [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/).
With `alpha = tan(pi * width / rate)`, `width` is the digital single-section
full half-power bandwidth; cascading narrows the combined response. The
nominal centre-frequency group delay of the cascade is `2 / alpha` samples.
The default width is `max(40, 4 * WPM)` Hz with a WPM hint, otherwise 180 Hz.
It balances rejection and keying transients; it is not a guarantee of separation.

Four filtered hops form a DC-removed Hann window, approximately 20 ms. Goertzel
measures each channel's tone power; a channel that fails acquisition keeps
its windowed energy but skips the recurrence. Acquisition separately examines
eight raw hops (40 ms): each hop supplies one Fourier projection per candidate
and guard frequency, and the eight projections are combined under a hop-wise
Hann taper with the window mean removed. The candidate power is compared
against the lower median of up to six neighboring guard powers, scaled by 1.3.
Guards are at offsets
±1, ±2 and ±3 times `max(100, 2 * frequency_step)` Hz, omitting frequencies
outside the sampled band. The default 12 dB power-ratio threshold gates the
filtered features. This is spectral contrast, not calibrated SNR. Guard geometry
and strong interference can still defeat it.

Accumulated channel energies rank local spectral maxima. Contrast, filtered
purity, keyed marks and timing determine acceptance. `channels()` exposes up
to eight Results, strongest accumulated energy first, separated by at least
`max(100, filter_bandwidth)` Hz to avoid duplicate adjacent-bin reports.
The primary API returns the first accepted Result, or a rejection Result.
A supplied frequency limits the bank to one channel. Different keyed tones
can be recovered simultaneously; co-channel sources cannot be unmixed.

Median smoothing, sustained-support peak caps, adaptive OFF noise and keyed
peak tracking with one-second decay and hysteresis reduce impulsive errors.
In an ON run whose power exceeds twice the seeded peak, hops below 22% of
its own top but still above that clamp are dropped, so a burst smeared by
the analysis window cannot pass as a mark while a genuine mark underneath
the burst stays keyed. Carrier intervals and sub-tolerance short marks are
excluded.
Valid multi-mark
Morse groups anchor margin cleanup; adjacent valid short letters and one
neighboring damaged multi-mark group are retained. Unsupported activity beyond
those margins is suppressed with a warning. Damaged interior groups remain
replacement characters. This generic timing heuristic can discard badly damaged
real edge characters and does not establish that decoded text is meaningful.

The symbolic decoder samples distinct mark widths with at most 128 timing
candidates, or uses supplied WPM. Both mark classes permit a dot estimate
that allows a common shaping/quantization offset. Without both classes,
automatic timing can remain ambiguous and text is suppressed.

Filter states and short raw/filtered histories persist across feeds. Finalization
adds bounded zero padding, shifts feature columns by rounded nominal window/
filter delay, then drops padding features. Actual input length and resource
accounting remain unchanged. Preview features are causal and uncompensated;
final event boundaries may change. The operation does not retain the full raw
recording. Feature storage is O(KN), bounded by candidate and frame limits.
Fresh analysis costs O(KN log N), with per-channel O(N) working memory;
unchanged snapshots are cached. Throttle previews, for example once a second.
Unlimited-duration reception is outside this version's contract.

## Detector power heuristics

The private lexical settings near the top of `lib/Ham/CW/Detector.pm` name the
acquisition and envelope-tracker settings. These module-private bindings are
initialized once and are not per-detector options. They operate on **power**,
not waveform amplitude. They are engineering heuristics, not values derived from
ITU Morse timing or a calibrated statistical noise model. The repository does
not provide a parameter-sweep study establishing that these values are optimal.
The rationale below explains their role and tradeoffs, not a mathematical
calibration. Naming them preserves the existing values and arithmetic.

| Named setting | Value | Role and tuning tradeoff |
| --- | ---: | --- |
| `GUARD_NOISE_MARGIN` | 1.3 | Multiplies the lower-median guard power before acquisition. Adds a conservative margin (about 1.14 dB) to that estimate; increasing it rejects more candidates, including weak genuine tones. It is not a proven bias correction for the guard median. |
| `ENVELOPE_NOISE_GATE_RATIO` | 12 | Keeps the switching threshold at least twelve times the **initial** channel noise floor, preventing the decaying tracker from admitting low-level activity. Increasing it can lose faint marks. This is a linear power ratio, about 10.8 dB, not the separate 12 dB `min_snr_db` default. |
| `TRACKED_PEAK_FLOOR_FRACTION` | 0.05 | Seeds and bounds the tracked peak at `floor + 0.05 * (seeded_peak - floor)`. Prevents peak decay from collapsing the relative threshold toward the noise floor; increasing it makes faded marks harder to retain. It is not a 5% amplitude cutoff or the final switching threshold. |
| `KEY_ON_FRACTION` / `KEY_HOLD_FRACTION` | 0.22 / 0.12 | Enter ON above 22% of the tracked peak-to-noise range, but retain ON down to 12%, subject to the initial-floor gate. This hysteresis reduces chatter and split marks. A higher entry fraction can miss weak attacks; a higher hold fraction can shorten tails or split fading marks. |
| `TRACKED_PEAK_CLAMP_RATIO` | 2 | Limits each observation used by the peak tracker to twice the seeded peak. The same boundary identifies an unusually strong run for burst trimming. Raising it lets impulses pull the tracker farther above message power. |
| `NOISE_UPDATE_THRESHOLD_FRACTION` | 0.25 | Allows noise updates only while OFF and below one quarter of the switching threshold. Keeps fading attacks and filter tails out of the noise estimate. Raising it admits more signal residue; lowering it leaves fewer background observations. |
| `NOISE_UPDATE_RATE` | 0.02 | Moves the noise estimate 2% toward each eligible OFF-hop observation. At nominal 5 ms hops, about 50 eligible observations give one e-fold of adaptation (about 0.25 seconds only if every hop qualifies). Faster adaptation also follows contamination faster. |
| `BURST_TRIM_FRACTION` | 0.22 | In an ON run whose maximum exceeds the peak clamp, suppresses hops below 22% of that run's maximum **only when they remain above the clamp**. This narrows a smeared strong burst while leaving message-level hops eligible. Raising it trims more of the burst and can remove genuine strong activity. |

The two 22% settings have separate meanings: one enters the ordinary keyed
state using a tracked peak and noise estimate; the other trims an exceptional
burst using that run's own maximum. Their equal numeric value does not make
them one parameter. Likewise, other 25% checks in purity/peak support are not
the OFF-noise-update rule.

For clarity, the switching rule is
`max(initial_floor * ENVELOPE_NOISE_GATE_RATIO,
tracked_noise + fraction * (tracked_peak - tracked_noise))`, where `fraction`
is the hold or entry fraction according to the preceding state. This gate is
separate from acquisition (`min_snr_db`) and subsequent sample-weighted mark
admission (`mark_snr_db`); both public options convert dB to power ratios with
`10 ** (dB / 10)`.

When tuning, run `t/27-mark-snr.t` for local-noise boundaries, partial-hop
weighting and weak/strong burst admission; `t/26-channel-reception.t` for
channel separation, interference and chunk/backend equivalence; and
`t/17-reception-matrix.t` for independent synthetic timing, fading and noise.
Check the real clips with `perl maint/reception-corpus.pl` as well. These are
regression evidence, not proof of optimal thresholds or general field accuracy.
Record any changed values with the competing signal/noise cases and compare
text, event boundaries and warnings across both backends and feed sizes.

## Optional PDL backend

The internal backend resolver accepts `perl`, `pdl`, and `auto`. Only the PDL backend
loads PDL; explicit selection fails early if unavailable. Facade construction
propagates selection to generation and PCM I/O, and reception inherits it
unless overridden. Symbolic encoding, events, decoding and MIDI remain shared.
The vector implementation uses double precision and public Perl arrays.
Detection uses squared sinusoidal projections, mathematically equivalent to
Goertzel power, with cached kernels per frame length and batches of at most
128 frames. Partial final hops enter the same fixed history/window and are flushed once.
Acquisition and biquad states are shared with the scalar pipeline; PDL batches
only the equivalent filtered projections.
Existing validation precedes processing and retained history stays bounded.
