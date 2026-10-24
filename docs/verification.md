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

All ten platform/author jobs must pass on the candidate commit before merge:
six ordinary Perl configurations, three PDL platforms and the author/release
job. Main requires these checks, an up-to-date branch and a pull request.
See the [CI runs](https://github.com/gipidevdor/ham-cw/actions/workflows/test.yml)
for remote results; a configured matrix is not evidence of execution.

The reception tests are synthetic. Off-air accuracy, overlapping stations
and unlimited-duration reception remain outside these results. The
[benchmark observations](benchmark-results.json) predate the latest reception
corrections and remain historical measurements. Run `perl maint/benchmark.pl`
to measure the current code on a chosen workload.
