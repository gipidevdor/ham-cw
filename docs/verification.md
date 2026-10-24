# Verification record

Initial development candidate 0.001, checked on 2026-10-24.

## Local results

| Check | Result |
| --- | --- |
| Ordinary suite, Perl 5.44.0, macOS | 1,144 assertions across 14 files; PASS |
| Ordinary suite with all Perl warnings fatal | 1,144 assertions; PASS |
| System Perl 5.34.1, macOS | 1,144 assertions; PASS |
| Author suite | 151 assertions across 5 files; PASS |
| Perl::Critic 1.156, severity 3 | PASS for production modules, examples, maintainer scripts and Makefile.PL |
| Perl::Tidy 20260826 | Formatting unchanged under the checked-in configuration |
| Test::Pod | All public POD checked; PASS |
| Local Test::Kwalitee 1.28 | Applicable local checks PASS; not a remote CPANTS report |
| Full archive analysis, Module::CPANTS::Analyse 1.03 | All 33 available indicators PASS; no archive diagnostics |
| Devel::Cover 1.52, production modules only | 99.81% statements (1061/1063); 98.87% branches (350/354) |
| WAV format verification | Independent header, sample and reference-fixture assertions PASS |
| Examples | WAV send, automatic receive and MIDI export executed successfully |
| Distribution extraction/build/test | make disttest and make distcheck PASS; isolated installation and all three installed examples PASS |
| GitHub platform matrix | All seven jobs PASS for the production implementation in [run 40082998845](https://github.com/gipidevdor/ham-cw/actions/runs/40082998845): Linux Perl 5.20/5.34/5.40/5.44, macOS 5.40, Windows 5.40 and author gates |

Coverage was collected from the full 1,144-assertion suite. That measurement describes the initial candidate before the corrections below. Tests and author
tools are excluded from the coverage denominator. No uncovered path was marked exempt to improve the percentage.
Unreachable decoder/detector FAILED checks have since been removed. The 95% statement and 90% branch
gates are enforced by `maint/coverage.pl` in CI.

## Independent evidence

Symbol tests use fixed reference vectors rather than the implementation's
lookup table. Oscillator tests check analytic sample values, zero crossings,
amplitude bounds and exact sample counts. DSP tests generate keyed signals
without using the project encoder/generator. The on-disk WAV fixture is built
separately by a standalone Perl writer. MIDI tests parse bytes with a
separate test reader and verify cumulative ticks and note-on/off events.

Negative tests cover every truncation of a small WAV, malformed chunk ordering
and sizes, duplicate chunks, unknown padded chunks, 300 deterministic header
mutations, non-finite samples, resource ceilings, lifecycle misuse and injected
read/seek/write failures. Streaming tests use blocks of 1, 7 and larger sizes.

## Limits of this record

The corpus is synthetic. Field performance on off-air recordings, separation
of overlapping stations and an indefinitely adaptive radio receiver have not
been established. Full transitive audits/builds of rejected CPAN candidates
were not performed; see the dependency audit. No PAUSE upload, remote CPANTS
score or CPAN Testers result is claimed. A CPAN upload requires the maintainer's
explicit authorization and a fresh namespace/permissions check.

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

The benchmark in `maint/benchmark.pl` compares complete generator and detector
calls, including conversion to and from public Perl arrays. The input was
`CQ CQ DE TESTCALL`, sampled at 8000 Hz. Detection used the default frequency
search grid and received the complete sample array in one feed call. Each
case ran for a target of two CPU seconds using Perl's Benchmark module.

| Operation | Perl backend | PDL backend | Observed speedup |
| --- | --- | --- | --- |
| Audio generation | 20.2 calls/second | 94.0 calls/second | About 4.7 times |
| Tone detection and decoding | 3.35 calls/second | 13.0 calls/second | About 3.9 times |

These measurements describe this machine and workload. They are not minimum
performance guarantees or end-to-end WAV throughput measurements. Small feed
blocks and a single candidate frequency can reduce the benefit. Run
`perl maint/benchmark.pl` to repeat the comparison on another system.

### Platform status

The CI configuration includes PDL jobs for Linux, macOS and Windows. Those
FAST jobs have not been executed during this local verification, so their
results remain pending. PDL 2.081 is the declared minimum; only PDL 2.106 was
exercised here. PDL needs a compatible native installation on each platform.

## Review corrections (2026-10-24)

The corrected working tree passes 1,274 assertions across 16 test files and
166 author checks. Regression cases cover sparse SOS surrounded by 62 seconds
of noise at three levels, damaged marks, Farnsworth audio, a 125-second WAV,
low-rate defaults, Unicode separators and structured bit-depth errors. The
receiver now accepts explicit speeds up to 60 WPM. Spectral purity and envelope
contrast have separate controls; frequency grid spacing is not bandwidth.
Earlier coverage and platform results above are historical measurements.
