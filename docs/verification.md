# Verification

Documentation and ordinary tests were checked locally on 2026-10-24 using
macOS ARM64 and Perl 5.44 with PDL 2.106. This is a source-checkout verification;
publication and remote platform results are separate.

| Current local check | Result |
| --- | --- |
| Ordinary suite | 1,674 assertions across 22 files; PASS |
| Author suite | 326 assertions across 7 files; PASS |
| POD syntax and per-method headings | PASS for all 10 public modules |
| Module synopses and README/task-guide Perl recipes | All 18 execute independently in temporary directories with warnings fatal |
| POD module/section references | All local targets resolve |
| Perl::Tidy 20260826 / Perl::Critic 1.156 | PASS |
| Perl documentation generation | All 10 public manual pages generated; PASS |

The documentation revision changes no executable prefix of the 10 public
modules. The API examples exercise text, events, samples, streaming, PCM/MIDI
files, in-memory bytes, result handling and exception handling. The author
suite keeps those examples executable and checks a dedicated heading for each
public method/function. This validates code examples, not every possible input
or clarity for every reader.

## Existing functional evidence

The preceding reviewed-code record reported 1,674 ordinary assertions with PDL
and 1,513 without PDL under system Perl 5.34. The PDL suite also passed
with warnings fatal. Production coverage was 99.15% statements (1,514/1,527)
and 97.47% branches (501/514). Archive checks and isolated installation passed.
Those measurements are retained as a dated baseline; this documentation-only
revision does not present them as newly repeated coverage/platform checks.

Coverage checks require all expected production modules, including PDL, and
reject missing, unexpected or duplicate module paths. Tests include independent
Morse vectors, synthetic audio, WAV/MIDI byte checks, injected I/O failures,
resource limits and incremental lifecycles. The corpus contains no off-air
recordings; its provenance and expected values are in
[corpus documentation](../corpus/README.md).

## Platform evidence

[Run 40086118418](https://github.com/gipidevdor/ham-cw/actions/runs/40086118418)
recorded successful platform/author checks for commit
`4e0a7e79a8e5d5fa76040d89d8c852c603667d67`, before later integration changes.
It covered Linux/macOS ARM/macOS Intel/Windows with PDL 2.106 and a Linux
Perl 5.20/PDL 2.081 combination. This historical result does not establish
that the current candidate passed the same matrix. Review checks on the
actual release commit using the [current CI workflow](../.github/workflows/test.yml).

The local current PDL version is 2.106; 2.081 remains the declared minimum.
Waveform comparisons allow an absolute tolerance of 1e-10. Floating-point
values near PCM rounding boundaries can differ outside the tested vectors.
Synthetic reception does not establish off-air accuracy, overlapping-station
separation or unlimited-duration reception.

## Performance and publication

[Benchmark observations](benchmarks.md) preserve dated platform ratios and
message-length timings, including exact workloads and limits. They are
measurements, not backend speed guarantees. Use the benchmark tools on the
current source and target machine before drawing performance conclusions.
Local archive indicators are distinct from remote CPANTS/CPAN Testers.
The [release procedure](releasing.md) covers publication checks separately.
