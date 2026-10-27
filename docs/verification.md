# Verification

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Measured performance](benchmarks.md)

## Scope of this record

Updated 2026-10-27 after receiver CPU/RSS optimization. The complete ordinary
suite passes 2,652 assertions across 31 files with Perl warnings fatal, including
116 independent complex-DFT assertions and all real-audio CER budgets. The
author checks pass 716 assertions across 11 files, including benchmark,
formatter/critic, licenses, metadata, documentation/site and candidate archives.
The local corpus report also retains CER 0% in all eight speed-mode decodes
across four clips, without warnings.
[Optimization results](optimization-results.json) pin the exact changed sources,
36 final measurements and the comparison with the earlier same-day baseline.
The optimized receiver uses complex Goertzel acquisition, packed PDL windows,
inner products and a batch budget based on window size and channel count.
Local PDL sample reception with tone search uses 36% less wall time and 54% less
peak RSS at 8 kHz, and 41% less time and 51% less peak RSS at 16 kHz. See the
[protocol](benchmarks.md#optimized-reception-2026-10-27). No new remote platform,
coverage or security run is implied by these local checks.

Earlier on 2026-10-27, baseline CPU/wall and peak-RSS measurements used library
source `f9a1dac329164cd1a5857ac1fa845e77a3e2e667`, using the new benchmark
instrumentation in the working tree. All 36 operation/backend/workload rows
and exact source/input hashes are in [resource results](resource-results.json).
Three sequential workloads cover 8 kHz searched/known tone and 16 kHz searched
tone, with three timed calls per isolated worker. Only macOS ARM64 was measured.
The benchmark/formatter/critic checks pass: 260 assertions in three files.
Documentation recipes, POD and site rendering/local links also pass: 202
assertions in three files. `make distcheck` reports a complete inventory, and
the 36 resource rows match their recorded source hashes and RSS units.
These runs do not refresh reception accuracy, production coverage, remote CI,
installation or security results below.

The earlier shared-process timing run measures source
`c635a8ad588558a2d12bb0557d863cd571b61349`; see
[performance results](performance-results.json) and the [timing protocol](benchmarks.md).
Historical interface and CI results below come from the
[earlier record](current-results.json) on `85eb8f3`. The corpus table has also
been rechecked locally as recorded above; remote CI and installed-package
verification retain their earlier dates.

## Checks and provenance

Local environment: macOS ARM64, Perl 5.44.0 and PDL 2.106.

| Check | Result and scope |
| --- | --- |
| Optimized receiver, 2026-10-27 | PASS: 2,652 ordinary-suite assertions; 36 CPU/RSS rows; [exact source hashes and measurements](optimization-results.json) |
| Author checks, 2026-10-27 | PASS: 716 assertions in 11 files; metadata, licenses, style, documentation/site, RSS tooling and candidate archives |
| CPU/wall and peak RSS, 2026-10-27 | 36 measured rows on macOS; independent worker per operation/backend; [protocol and results](benchmarks.md#local-cpu-wall-time-and-peak-rss-2026-10-27) |
| Ordinary and author suite | PASS: 3,034 assertions across 39 files, with all Perl warnings fatal, after the interface refinements |
| Timing | Three sequential, three-iteration workloads on `c635a8a`: 8 kHz searched/known tone and 16 kHz searched tone; [protocol](benchmarks.md) |
| Corpus reception, 2026-10-27 | Eight local report decodes across four clips; CER 0% and no warnings in either mode; [raw results](optimization-results.json) |
| Documentation links | Checked during the timing refresh; count in [performance results](performance-results.json) |
| Production coverage | CI on `85eb8f3`: statements 99.03% (2,245/2,267), branches 96.28% (751/780) |
| Local distribution | Recorded PASS in the earlier interface review; not rerun in this timing refresh |
| Isolated installation | PASS in CI on `85eb8f3`, including installed CLI and examples |
| Other Perl/platform combinations | All twelve CI test jobs pass on `85eb8f3` |
| Security CI | FAIL on `85eb8f3`: installed and declared dependency advisory checks; other scanner jobs pass |

The coverage requirements remain 95% statements and 90% branches, with every
production module included. These gates pass in the cited CI coverage run.
Coverage was not recollected locally for the interface update. Condition
instrumentation was used to collect branch counts. See
[contributing](../CONTRIBUTING.md) for collection instructions.

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

The corpus covers automated beacons, not human-keyed QSOs. Synthetic tests
cover two messages at 150 Hz separation with explicit 20 WPM, independent
20/25 WPM at 250 Hz separation, unequal levels and added noise, a stronger
continuous carrier and independently varied mark/gap lengths. These are
specific cases; field error rates and general resolving power remain unmeasured.

Run `perl maint/reception-corpus.pl` to repeat the corpus measurement.
For resource bounds, see [practical limits](usage.md#practical-limits) and
the [Detector reference](../lib/Ham/CW/Detector.pm).

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
aggregate security gate failed. The later interface working tree passed the
local suite above; no separate remote run is recorded for that update.

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
local dependency, secret or workflow scan was repeated for this record, and
advisory applicability remains unresolved. See
[security CI](security-ci.md#remote-results-2026-10-25).

## Historical records

[Verification history](verification-history.md) retains earlier suite counts,
coverage percentages, packaging results, CI runs and security observations.
[Benchmark history](benchmark-history.md) retains older timings. Those records
are dated and tied to their source revisions.
