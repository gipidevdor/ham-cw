# Verification

The corrections below were checked locally on 2026-10-24. These results apply
to this source revision; historical timings are kept separately below.

## Current local checks

| Check | Result |
| --- | --- |
| Ordinary suite, macOS ARM64, Perl 5.44.0 with PDL 2.106 | 1,720 assertions across 23 files; PASS |
| Ordinary suite with all Perl warnings fatal | 1,720 assertions; PASS |
| System Perl 5.34.1 without PDL | 1,547 assertions across 23 files; PASS |
| Author checks | 212 assertions across 6 files; PASS |
| Perl::Tidy 20260826 and Perl::Critic 1.156 | PASS |
| Production statement coverage | 99.31% (1,573/1,584); PASS |
| Production branch coverage | 97.00% (518/534); PASS |
| Distribution build/test, archive checks and isolated installation | PASS |

Coverage requires all 18 production modules, including the PDL implementation
and the internal snapshot builder. Missing or duplicate production paths fail
the gate before percentages are considered. No path was exempted to meet the
95% statement and 90% branch thresholds.

## Regression evidence

Timing tests reproduce the discontinuity at 32 repeated shortest marks and
cover a broad set of distinct mark widths. Independent 25 and 50 WPM SOS
schedules run for approximately 62 and 31 seconds, with hard keying and 5 ms
raised-cosine ramps. Both backends recover the text, estimate speed within
five percent and avoid false spacing warnings. Additional generated-message
probes at 20, 25, 40, 50 and 60 WPM returned the configured speeds.

File tests check permission preservation, new-file umask, ordinary and
dangling symbolic-link rejection, existing-byte preservation on generation
failure and temporary-file cleanup. POSIX permission assertions and symlink
tests are skipped on systems that cannot represent those features.

Snapshot tests check cache invalidation, preservation of previous snapshots
when marks are coalesced, independent public accessors and rejection of
unsafe caller metadata before state changes. New cumulative snapshots still
process retained history; frequent snapshots after tiny feeds have a
cumulative cost. The optimization removes repeated internal deep validation
and copying, while keeping public Result construction fully validated.
Block-callback tests also mutate warning lists and warning hashes to verify
metadata isolation between callbacks.

The full suite additionally covers fixed Morse vectors, independent synthetic
signals, PCM/MIDI byte checks, malformed files, real closed-pipe writes,
resource limits and path/stream workflows. The corpus is synthetic: off-air
accuracy, overlapping transmitters and unlimited reception are not established.

## CI and release checks

The workflow contains twelve checks: six ordinary Perl combinations, five
PDL configurations and one author/distribution job. PDL covers Linux, macOS
ARM/Intel and Windows with Strawberry Perl; the minimum Perl 5.20 / PDL 2.081
combination uses Ubuntu 22.04's compatible compiler.

PDL and the pinned formatter use the setup action's dependency cache.
Successful dependency builds use normal installer output rather than verbose
compiler output, avoiding unrelated optional-module diagnostics being matched
as project failures. Cached installations remain subject to the complete test
suite. These workflow changes have not yet been executed remotely for this
correction. See [CI runs](https://github.com/gipidevdor/ham-cw/actions/workflows/test.yml)
for actual execution results. Local checks are not CPAN Testers certification
or a PAUSE upload.

## Archived measurements

The following platform timings were collected before these corrections,
on commit `4e0a7e79a8e5d5fa76040d89d8c852c603667d67`, in the successful
[twelve-job platform run](https://github.com/gipidevdor/ham-cw/actions/runs/40086118418).
They are historical observations, not measurements of the corrected estimator
or snapshot path. The raw [workflow benchmark data](benchmark-results.json)
also predates these changes.

The platform workload was `CQ CQ DE TESTCALL` at 8000 Hz. PCM cases read or
write one second of mono WAV in memory, including validation, headers and
array conversion, excluding disk I/O. Reception uses either one complete feed
or 4096-sample feeds. Each case warms up once and then runs for at least one
wall-clock second. `maint/benchmark-platforms.pl` reproduces that protocol;
`maint/benchmark.pl` additionally covers configurable workflows and snapshots.

### Observed PDL/Perl speed ratios

Each cell is PDL calls/second divided by Perl calls/second on the same runner.
Values above 1 favour PDL; values below 1 favour Perl. These are short,
single-run observations on shared hosted machines. Small differences and
differences between runs should not be treated as stable backend rankings.

| Operation | Linux | macOS ARM64 | macOS Intel | Windows | Linux minimum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Audio generation | 4.71x | 3.73x | 6.00x | 3.54x | 3.60x |
| Detection, complete array | 5.10x | 6.84x | 6.39x | 4.86x | 5.97x |
| Detection, 4096-sample feeds | 5.32x | 3.96x | 6.62x | 4.29x | 5.01x |
| PCM WAV read, 8-bit | 0.96x | 1.64x | 1.11x | 0.75x | 0.95x |
| PCM WAV read, 16-bit | 1.15x | 0.93x | 1.16x | 0.88x | 1.05x |
| PCM WAV read, 24-bit | 1.16x | 0.77x | 1.21x | 1.13x | 0.99x |
| PCM WAV write, 8-bit | 1.39x | 1.05x | 1.54x | 1.35x | 1.41x |
| PCM WAV write, 16-bit | 1.46x | 1.82x | 1.60x | 1.39x | 1.48x |
| PCM WAV write, 24-bit | 1.39x | 1.22x | 1.41x | 1.25x | 1.31x |

PDL gives a substantial synthesis and detection benefit in these cases.
PCM conversion has a smaller, workload-dependent benefit; several cases
are slower with PDL. The automatic selector currently chooses according
to availability, not according to these timing results.

The five `benchmark-*` artifacts on the [run page](https://github.com/gipidevdor/ham-cw/actions/runs/40086118418)
contain absolute rates and the underlying iteration counts, elapsed times
and environment metadata. They allow the ratios to be checked without
copying console logs into the release notes.

### Archived message-length timings (2026-10-24)

These earlier measurements, also preceding the current corrections, use the literal message `CQ DE TESTCALL`, repeated
one, two, four, eight or twelve times with one separating space. Message
length is the actual character count including spaces, and audio duration
comes from the generated events. No reference-word equivalence is used.
These measurements replace the previous message-length example.

The sample rate was the default 16000 Hz at 20 WPM, on macOS ARM64 with
Perl 5.44.0 and PDL 2.106. Each processing time is the median of three
new runs, in seconds.

| Repeated messages | Characters, including spaces | Audio duration | Generate, Perl | Generate, PDL | Analyze, Perl | Analyze, PDL |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 14 | 7.14 | 0.076 | 0.011 | 0.381 | 0.056 |
| 2 | 29 | 14.70 | 0.154 | 0.024 | 0.782 | 0.112 |
| 4 | 59 | 29.82 | 0.310 | 0.050 | 1.580 | 0.230 |
| 8 | 119 | 60.06 | 0.619 | 0.104 | 3.186 | 0.471 |
| 12 | 179 | 90.30 | 0.935 | 0.158 | 4.781 | 0.706 |

Generation measures sample synthesis, including generator construction.
Analysis measures 4096-sample feeds and finalization with the default
frequency search grid; detector construction is outside that timer.
The audio is already available in memory. PCM conversion, file I/O and
live reception time are excluded. These are measured cases, not estimates
extrapolated from the short CI benchmark.

Default reception retains at most 24000 frames, approximately 120 seconds
including silence. Longer recordings require a larger explicit `max_frames`
and more retained memory. The time needed to transmit or receive the audio
in real time remains its full audio duration.
