# Verification

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Measured performance](benchmarks.md)

## Scope of this record

Updated 2026-10-25. Timing and corpus measurements identify source revision
`85eb8f3fce614d30cb53eaeb0da6b978dbc3dacc` in the
[raw results](current-results.json). The documentation update on top of that
revision preserves the numerical generation and reception implementation.
Command help, example discovery and usage diagnostics have since been refined. Each check below states its own
scope; earlier PASS results are not carried forward as current measurements.

## Checks and provenance

Local environment: macOS ARM64, Perl 5.44.0 and PDL 2.106.

| Check | Result and scope |
| --- | --- |
| Ordinary and author suite | PASS: 3,034 assertions across 39 files, with all Perl warnings fatal, after the interface refinements |
| Timing | Two sequential, three-iteration local workloads; [results and protocol](benchmarks.md) |
| Corpus reception | Eight decodes across four clips; CER 0% and no warnings in either mode |
| Documentation links | PASS: local targets and heading anchors checked; count in raw record |
| Production coverage | CI on measured revision: statements 99.03% (2,245/2,267), branches 96.28% (751/780) |
| Local distribution | Manifest inventory, archive build and archive indicators pass on this update |
| Isolated installation | PASS in CI on measured revision, including installed CLI and examples |
| Other Perl/platform combinations | All twelve CI test jobs pass on measured revision |
| Security CI | FAIL on measured revision: installed and declared dependency advisory checks; other scanner jobs pass |

The coverage requirements remain 95% statements and 90% branches, with every
production module included. These gates pass in the cited CI coverage run.
Coverage was not recollected
locally for the interface update; the numerical receiver has not changed.
Condition instrumentation supports complete branch counts; no condition
coverage percentage is claimed. See [contributing](../CONTRIBUTING.md) for
collection instructions.

## Reception evidence

The measured corpus contains four short clips from three automated-beacon
recordings. References, source licenses, transformations and fixture hashes are
tracked in the [corpus](../corpus/README.md) and
[recording licenses](../corpus/real/LICENSES.md).

| Clip | CER with speed hint | CER with estimated speed | Warnings, either mode |
| --- | ---: | ---: | --- |
| 4U1UN identification | 0% | 0% | None |
| OH2B identification | 0% | 0% | None |
| CS3B identification | 0% | 0% | None |
| SK6RUD identification | 0% | 0% | None |

Only speed is supplied in the hinted run; tone is searched in both modes.
CER counts character edits, including spaces and replacement characters,
divided by reference length; it can exceed 100%. The quality target is at most
25% CER per clip and mode. The current regression budgets are stricter: 0%
for all eight decodes. Both measures pass for this fixed corpus.

These clips do not establish general accuracy, human-keyed QSO performance,
co-channel separation, fading tolerance or a field error rate. Synthetic tests
cover two messages at 150 Hz separation with explicit 20 WPM, independent
20/25 WPM at 250 Hz separation, unequal levels and added noise, a stronger
continuous carrier and independently varied mark/gap lengths. These are
specific test cases, not universal resolving-power or signal-to-noise bounds.

Run `perl maint/reception-corpus.pl` to repeat the corpus measurement.
Generation defaults to 10,000,000 samples; reception retains at most 24,000
frames by default, approximately 120 seconds including silence. Streaming
reduces block buffers but does not remove these retained-history limits.
See [practical limits](usage.md#practical-limits) and the
[Detector reference](../lib/Ham/CW/Detector.pm) for full contracts.

## Remote CI

[Tests run 40187441836](https://github.com/gipidevdor/ham-cw/actions/runs/40187441836)
completed successfully on `85eb8f3`: six ordinary Perl combinations, five PDL
configurations and one author/distribution job. The latter measured coverage,
validated the archive and ran isolated installation, the installed CLI and
examples. See the [raw verification summary](current-results.json) for job
names, outcomes and coverage counts.

[Security run 40187441825](https://github.com/gipidevdor/ham-cw/actions/runs/40187441825)
completed with failure on that same revision. Secret-history scanning, unsafe
Perl construct checks and workflow checks passed; the dependency audit and
aggregate security gate failed. The latest interface working tree passes the local suite above. It has no
independent remote CI result of its own. A source
revision must match the cited run before using its outcome.

## Security status

The 2026-10-25 remote audit used CPAN::Audit 20261013.002 and CPANSA::DB
20261018.001. It reported two installed-environment matches (File::Temp and
Perl) and 38 declared-constraint matches, with no scanner errors. Both gates
exited nonzero. These are scanner matches, not counts of confirmed Ham::CW
vulnerabilities. The declared audit covers compatibility constraints, including
historical releases; it is distinct from auditing installed versions.

The [raw verification summary](current-results.json) retains advisory IDs by
distribution, scope metadata, artifact hashes and job outcomes. The linked
Security run supplies the original CI artifacts subject to retention. No
current local dependency/secret/workflow scan or applicability reassessment
is claimed. See [security CI](security-ci.md#remote-results-2026-10-25) for
scope and unresolved issues. Ordinary parser/error tests and audit-adapter
regression tests do not substitute for these scans.

## Historical records

[Verification history](verification-history.md) retains earlier suite counts,
coverage percentages, packaging results, CI runs and security observations.
[Benchmark history](benchmark-history.md) retains older timings. Those records
belong to their original dates and revisions; they do not certify this source.
