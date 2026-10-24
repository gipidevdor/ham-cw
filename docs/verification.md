# Verification

The current review candidate was checked locally on 2026-10-24. Results below
refer to the reviewed source snapshot, including the optional PDL backend and
workflow APIs. They do not certify unreviewed changes in another checkout.

| Check | Result |
| --- | --- |
| Ordinary suite, macOS ARM64, Perl 5.44 with PDL 2.106 | 1,674 assertions across 22 files; PASS |
| Ordinary suite with all Perl warnings fatal | 1,674 assertions; PASS |
| System Perl 5.34 without PDL | 1,513 assertions across 22 files; PASS |
| Author checks | 203 assertions across 6 files; PASS |
| Perl::Tidy 20260826 and Perl::Critic 1.156 | PASS |
| POD, metadata and local kwalitee | PASS |
| Production statement coverage | 99.15% (1,514/1,527); PASS |
| Production branch coverage | 97.47% (501/514); PASS |
| Distribution build/test, archive checks and isolated install | PASS |

Coverage requires all 17 production modules, including the optional PDL
implementation. Missing, unexpected or duplicated production paths fail the
gate before percentages are considered. Author regressions verify that a
100% summary for an incomplete module subset cannot pass. An incomplete
MANIFEST also prevents release archive construction.

Tests use fixed Morse vectors, independently generated audio, a synthetic
WAV fixture, independent PCM/MIDI byte checks and injected I/O failures.
Regression cases cover sparse messages in 62 seconds of noise, 5 ms impulses
before CW at amplitudes 0.01 and 0.02, block/backend equivalence, fractional
speeds, ambiguous spacing and a 125-second WAV. The drift fixture integrates
instantaneous frequency; measured zero crossings verify its stated bounds.

A separate Perl process checks real closed-pipe writes: WAV and MIDI errors
remain catchable, the WAV writer becomes FAILED and the caller's signal
handler is restored. Additional tests cover canonical segment limits across
feeds, invalid/cyclic result and exception payloads, sampled MIDI half-tick
boundaries and valid tone defaults at 1,400, 1,401 and 1,402 Hz sample rates.
File tests verify existing-file protection, explicit replacement and retention
of the destination after generation failure.

The workflow tour and installed command-line examples are checked during
isolated installation. Production code has no mandatory non-core dependency.
PDL is optional; waveform comparisons use an absolute tolerance of 1e-10.
Only PDL 2.106 was tested locally; 2.081 remains the declared minimum.
Floating-point calculations near PCM rounding boundaries can differ outside
the tested vectors.

All twelve platform/author jobs must pass on the candidate commit before merge:
six ordinary Perl configurations, five PDL configurations and the author/release
job. Main requires these checks, an up-to-date branch and a pull request.
See the [CI runs](https://github.com/gipidevdor/ham-cw/actions/workflows/test.yml)
for remote results; a configured matrix is not evidence of execution.

The reception tests are synthetic. Off-air accuracy, overlapping stations
and unlimited-duration reception remain outside these results. The
[benchmark observations](benchmark-results.json) predate the latest reception
corrections and remain historical measurements. Run `perl maint/benchmark.pl`
to measure the current code on a chosen workload.

## Historical FAST measurements

The following measurements and completed platform run apply to the explicit
commits listed below, before the subsequent quality-review integration.
The platform benchmark is now retained as `maint/benchmark-platforms.pl`;
`maint/benchmark.pl` additionally measures configurable workflows and snapshots.
Current integrated-code results must be checked on the integration pull request.

## FAST backend verification (2026-10-24)

The optional PDL backend was checked on macOS ARM64 with Perl 5.44.0 and
PDL 2.106. The previous platform matrix above applies to the original Perl
implementation; it does not establish portability of the new backend.

The FAST tests compare generated samples at 1000, 8000, 16000 and 44100 Hz
with the reference Perl implementation, using different block sizes. The
waveforms agree within an absolute tolerance of 1e-10. Reception tests use
independently generated signals and the existing WAV fixture, and compare
text, tone selection, event timings and rejection warnings. PCM tests cover
8-, 16- and 24-bit samples, signed rounding at half steps, clipping and all
three stereo policies. The tested PCM output is byte-for-byte identical.
Short marks, empty input, resource limits, reset and finalization are also
checked. General floating-point equivalence does not promise identical PCM
bytes for every possible sample near a rounding boundary.

The latest combined run of `prove -lr t xt` passed all 1,440 assertions
across 21 test files with PDL installed. The author checks passed,
including POD, distribution metadata, formatting and Perl::Critic. The source
archive also passed extraction/build/tests, all 33 available local CPANTS
indicators, and an isolated installation with the supplied examples. These
are local checks, not a CPAN Testers report or a PAUSE upload.

A separate run with macOS system Perl 5.34.1 passed without PDL. Automatic
selection fell back to Perl, and an explicit request for the unavailable
PDL backend produced the documented structured error.

### Measured performance

The initial benchmark compared complete generator and detector
calls, including conversion to and from public Perl arrays. The input was
`CQ CQ DE TESTCALL`, sampled at 8000 Hz. Detection used the default frequency
search grid and received the complete sample array in one feed call. Each
case ran for a target of two CPU seconds using Perl's Benchmark module.
The expanded cross-platform benchmark below uses wall-clock time instead.

| Operation | Perl backend | PDL backend | Observed speedup |
| --- | --- | --- | --- |
| Audio generation | 20.2 calls/second | 94.0 calls/second | About 4.7 times |
| Tone detection and decoding | 3.35 calls/second | 13.0 calls/second | About 3.9 times |

These measurements describe this machine and workload. They are not minimum
performance guarantees or end-to-end WAV throughput measurements. Small feed
blocks and a single candidate frequency can reduce the benefit. Run
`perl maint/benchmark.pl` to repeat the comparison on another system.

### Platform status

This initial local verification exercised PDL 2.106. The subsequent CI
execution, including the declared PDL 2.081 minimum and the Windows native
build, is recorded in the expanded verification below.

## Review corrections (2026-10-24)

The corrected working tree passes 1,274 assertions across 16 test files and
166 author checks. Regression cases cover sparse SOS surrounded by 62 seconds
of noise at three levels, damaged marks, Farnsworth audio, a 125-second WAV,
low-rate defaults, Unicode separators and structured bit-depth errors. The
receiver now accepts explicit speeds up to 60 WPM. Spectral purity and envelope
contrast have separate controls; frequency grid spacing is not bandwidth.
Earlier coverage and platform results above are historical measurements.

## Expanded FAST platform and PCM verification

The expanded CI checks the current CW integration on an isolated branch.
It includes the declared minimum Perl/PDL combination, the current PDL
release on Linux and macOS ARM/Intel, and Strawberry Perl on Windows. Pure
Perl compatibility and the author/distribution gates run alongside FAST.

The benchmark now measures generation, reception from a complete array,
reception in 4096-sample blocks, and in-memory WAV reading and writing at
8, 16 and 24 bits. WAV cases use one second of mono PCM at 8000 Hz and include
header processing, validation, packing/unpacking and public array conversion.
They exclude physical disk I/O. Reception and synthesis use the same
`CQ CQ DE TESTCALL` message at 8000 Hz. Each case warms up once, then runs
for at least one wall-clock second. A call already in progress is completed
before timing stops.

Each FAST job saves its actual Perl/PDL versions, architecture, iteration
counts, elapsed times and rates as a downloadable JSON artifact. Timing is
observational: hosted runners vary, and a speedup below 1 means PDL was slower
for that case. There is no speed threshold in the compatibility tests.

The first minimum-version build failed before Ham-CW tests: PDL 2.081's
legacy C declarations were rejected by the latest Linux compiler. The legacy
combination therefore uses Ubuntu 22.04; current PDL remains tested on the
latest Linux runner. This is a dependency build constraint, not evidence of
successful tests on the failed runner.

The author job in the expanded run passed the ordinary suite (1,274 assertions
across 16 files), all five author test files, distribution extraction/tests,
archive analysis and an isolated installation with the examples. Production
coverage was 1,239/1,248 statements (99.28%) and 414/420 branches (98.57%).
No uncovered path was exempted to meet the gates.

### Completed CI run (2026-10-24)

All 12 jobs passed in [run 40086118418](https://github.com/gipidevdor/ham-cw/actions/runs/40086118418), testing
commit `4e0a7e79a8e5d5fa76040d89d8c852c603667d67` on `codex/fast-platform-ci`.
This is a successful GitHub Actions run, not a CPAN Testers certification.

| FAST environment | Actual Perl | Actual PDL | Result |
| --- | --- | --- | --- |
| Linux | v5.40.5 | 2.106 | PASS |
| macOS ARM64 | v5.40.5 | 2.106 | PASS |
| macOS Intel | v5.40.5 | 2.106 | PASS |
| Windows / Strawberry | v5.40.4 | 2.106 | PASS |
| Linux / minimum versions | v5.20.3 | 2.081 | PASS |

The other seven successful jobs comprise six Pure Perl combinations and the
author/distribution checks. The Pure Perl matrix covers Linux Perl 5.20,
5.34, 5.40 and 5.44, plus macOS and Windows with Perl 5.40.

The Windows FAST build used Strawberry Perl, as recommended by the
[PDL installation guide](https://metacpan.org/pod/PDL::InstallGuide).
The earlier default Windows toolchain failed to build PDL; this successful
result applies to the Strawberry configuration.

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

## Message length and elapsed time (local, 2026-10-24)

The measurements below use the literal message `CQ DE TESTCALL`, repeated
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
