# Verification

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Measured performance](benchmarks.md)

## Current development edition

Version **0.001**, verified **2026-11-07**. The integrated implementation is
[`2168dbc`](https://github.com/gipidevdor/ham-cw/commit/2168dbc6256066d9975bf511f296fea7a269e010).
The tested pull-request commit was
[`89a5759`](https://github.com/gipidevdor/ham-cw/commit/89a575951778181512c082e74e42939a24878d0b);
the two commits have identical file trees. This documentation refresh changes
only guides and evidence records. The [current raw record](current-results.json)
pins all 20 production-module hashes and the exact runs supporting this edition.

The implementation reduces Perl synthesis work, preserves exact MIDI boundary
rounding for large sampled durations, rejects references in scalar string
options/states, avoids repeated shared-payload traversal and installs only
manifest-listed modules. These changes retain the documented cycle/depth,
resource and streaming contracts.

## Checks and provenance

| Check | Result and scope, 2026-11-07 |
| --- | --- |
| Required CI test jobs | **PASS: 12/12** on the [tested implementation](https://github.com/gipidevdor/ham-cw/actions/runs/42372079468) |
| Ordinary suite | **PASS: 2,886 assertions in 33 files** in the CI author/distribution job, with PDL 2.106 available |
| CI author suite | **PASS: 732 assertions in 11 files**, Linux Perl 5.40.5; documentation, style, metadata, site, licenses and release tools |
| Local combined suite | **PASS: 3,619 assertions in 44 files**, macOS ARM64, Perl 5.44.0 and PDL 2.106, warnings fatal |
| Production coverage | **PASS: 99.01% statements (2,306/2,329), 96.22% branches (764/794)**; all 20 modules including PDL, fresh database, thresholds 95%/90% |
| System Perl 5.34.1 | **PASS: 748 targeted assertions in seven files**, without the PDL backend |
| Generation equivalence | **PASS: 72 identical sample/WAV fingerprints** against the pre-optimization baseline; six rates, three block sizes and all supported PCM depths |
| Real reception corpus | **PASS: CER 0% and no warnings in all eight hinted/estimated-speed decodes** |
| Distribution and installation | **PASS:** metadata, archive indicators, complete ordinary suite from the archive, isolated installation, installed CLI and example catalog |
| Pages publication | **PASS:** [documentation workflow](https://github.com/gipidevdor/ham-cw/actions/runs/42373236730) built and deployed implementation `2168dbc`; the subsequent documentation-only refresh is published by its own workflow |
| Security workflow | **FAIL:** [dependency audit](https://github.com/gipidevdor/ham-cw/actions/runs/42372079553); two installed matches and 39 declared-range matches, no scanner errors and no new advisory IDs against the prior main revision |

The local and CI author totals retain their observed environments; they are
not one combined remote count. CI coverage matches the local production counts.
The [local review record](review-results.json) keeps the independent waveform
checks, paired generation measurements and local verification details.

## Perl and platform matrix

All jobs below passed in the same [Tests run](https://github.com/gipidevdor/ham-cw/actions/runs/42372079468):

| Job group | Configurations |
| --- | --- |
| Core Perl backend | Linux Perl 5.20, 5.34, 5.40 and 5.44; macOS and Windows Perl 5.40 |
| Minimum optional backend | Linux Perl 5.20 with PDL 2.081 |
| PDL 2.106 | Linux, macOS ARM64, macOS Intel and Windows, all with Perl 5.40 |
| Author and distribution | Linux Perl 5.40 with PDL 2.106, coverage, archive and isolated installation |

This is the required matrix. The additional scheduled portability workflow is
separate; a result for the previous main revision does not certify this edition.
The [platform measurement record](platform-results.json) stores the actual
interpreter versions, runner labels, timings and artifact hashes for all five
PDL configurations.

## Reception evidence

The corpus contains four short clips from three automated-beacon recordings.
References, source licenses, transformations and fixture hashes are tracked in
the [corpus](../corpus/README.md), [recording licenses](../corpus/real/LICENSES.md)
and [current raw results](current-results.json).

| Clip | CER with speed hint | CER with estimated speed | Warnings, either mode |
| --- | ---: | ---: | --- |
| 4U1UN identification | 0% | 0% | None |
| OH2B identification | 0% | 0% | None |
| CS3B identification | 0% | 0% | None |
| SK6RUD identification | 0% | 0% | None |

Only speed is supplied in the hinted run; tone is searched in both modes.
CER counts character edits, including spaces and replacement characters,
divided by reference length; it can exceed 100%. The quality target is at most
25% CER per clip and mode. This edition passes the stricter 0% regression
budgets in all eight decodes. Run `perl maint/reception-corpus.pl` to repeat them.

Synthetic tests also cover noise, fading, independent keying, simultaneous
stations, stronger unkeyed interference and backend/chunk equivalence. The
licensed corpus covers automated beacons; human-keyed QSO accuracy and general
field error rates remain unmeasured. See [reception limits](usage.md#practical-limits).

## Performance and security

The [current performance guide](benchmarks.md) reports paired local generation
measurements and five-platform CI timings for this implementation. Peak-RSS
results remain dated 2026-10-27 and are retained as historical evidence.

The [security record](security-ci.md#remote-results-2026-11-07) identifies the
installed Perl/File::Temp matches, the 39 declared-range matches and the
comparison with the prior main revision. Workflow checks, complete-history
secret scanning and unsafe-Perl-construct checks pass. Advisory applicability
remains unresolved; no exclusion or gate relaxation was introduced.

## Historical records

[Verification history](verification-history.md) contains the earlier suite,
coverage, packaging and reception records with their original dates. The
[2026-10-25 raw verification record](verification-20261025-results.json) and
[2026-10-25 platform record](platform-20261025-results.json) are archived without
changing their measurements. [Benchmark history](benchmark-history.md) retains
earlier performance observations. None is relabeled as a result for this edition.
