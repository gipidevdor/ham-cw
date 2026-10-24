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

Coverage was collected from the full 1,144-assertion suite. All production
source files in that measurement match the candidate source. Tests and author
tools are excluded from the coverage denominator. No uncovered path was marked exempt to improve the percentage.
The remaining uncovered branches are defensive checks for failed decoder/
detector states, zero broadband energy after accepted spectral evidence, and
a defensive index clamp in impulse merging. The 95% statement and 90% branch
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
