# Verification

Current working tree, checked locally on 2026-10-24.

| Check | Result |
| --- | --- |
| Ordinary suite, macOS ARM64, Perl 5.44 with PDL 2.106 | 1,549 assertions across 21 files; PASS |
| Ordinary suite with all Perl warnings fatal | 1,549 assertions; PASS |
| System Perl 5.34 without PDL | 1,396 assertions; PASS |
| Author checks | 179 assertions across 5 files; PASS |
| Perl::Tidy 20260826 and Perl::Critic 1.156 | PASS |
| POD, metadata and local kwalitee | PASS |
| Production coverage | 99.11% statements, 97.48% branches; PASS |
| Distribution build/test, archive checks and isolated install | PASS |

The tests use fixed Morse vectors, independently generated audio, a recorded
synthetic fixture, PCM and MIDI byte checks, and injected I/O failures.
The reception matrix compares both backends and different block sizes.
Regression cases include sparse messages in 62 seconds of noise, 5 ms tone
and broadband impulses before weak messages, partial text recovery, Farnsworth
spacing, recording margins, equal fractional speeds and a 125-second WAV.
File tests cover default existing-file protection and explicit replacement,
including preservation of the destination after generation failure.

The default Perl backend needs only core modules. PDL is optional; waveform
comparisons use an absolute tolerance of 1e-10. Tests compare decoded text,
events and diagnostics between backends. Floating-point calculations near
PCM rounding boundaries can differ outside the tested vectors.

The current reception tests are synthetic. Off-air accuracy, overlapping
stations and unlimited-duration reception remain outside these results.
The current working tree has not been checked by the remote CI platform
matrix. Only PDL 2.106 was tested locally; 2.081 remains the declared minimum.

[Benchmark observations](benchmark-results.json) were collected before the
latest reception corrections and are retained as historical measurements.
Use `perl maint/benchmark.pl` to measure the current code on a chosen workload.

## Complete workflow ergonomics (2026-10-24)

The facade now covers per-call text/timing overrides, timed/sampled events,
collecting and streaming samples, incremental component factories, sample/event
reception, in-memory WAV/MIDI and WAV byte decoding. Raw Audio helpers cover
collecting file I/O and bounded callbacks/iterator output; custom MIDI events
have managed file output. All path-writing helpers preserve existing outputs
by default and accept explicit replacement. These additions retain the older
handle/component interfaces.

The complete ordinary/author run passed 1,728 assertions across 26 files on
Perl 5.44.0 with PDL; system Perl 5.34.1 without PDL passed 1,396 assertions
across 21 ordinary files. These totals include regression checks for
impulse rejection, fractional speeds, ambiguous spacing and file replacement. The task guide maps every supported
operation to its input/output types, options, units and lifecycle. It is not
a claim that all users have found the API intuitive in a usability study.

The self-contained workflow tour executed under both interpreters. CLI smoke
checks exercised all help pages, named timing/tone/PCM/MIDI options, JSON
reception, default output preservation and explicit WAV/MIDI replacement.
The release installation checker and platform CI examples now run the tour.

The complete workflow coverage run passed all 1,549 ordinary assertions:
statements 99.11% (1444/1457), branches 97.48% (464/476). Both gates pass.
The 60 workflow-specific checks also pass with all Perl warnings fatal.
The final archive passed manifest checks, all 33 local archive indicators,
isolated build/test/install and the installed workflow tour plus CLI examples.
