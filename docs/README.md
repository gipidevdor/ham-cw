# Documentation

[Project](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md)

[Read online](https://gipidevdor.github.io/ham-cw/).

| Task | Guide |
| --- | --- |
| Install or check your environment | [Installation](installing.md) |
| Convert text, make files or receive CW | [Task guide](usage.md#command-line-use) |
| Resolve an error or warning | [Recovery guide](usage.md#when-you-need-help) |
| Use the library in an application | [Library recipes](usage.md#library-recipes) |
| Run an API example | [Example catalog](../examples/README.md#choose-a-path) |
| Choose an API or representation | [Interfaces](usage.md#choose-an-interface) and [data representations](usage.md#choose-the-data-representation) |
| Understand timing, state and filtering | [Architecture](architecture.md) |
| Understand detector thresholds | [Power heuristics](architecture.md#detector-power-heuristics) |
| Compare backend speed and peak resident memory | [Measured performance](benchmarks.md) |
| Review tests and recordings | [Verification](verification.md) and [reference corpus](../corpus/README.md) |
| Change or release the project | [Contributing](../CONTRIBUTING.md) and [release procedure](releasing.md) |
| Review dependencies or security | [Dependency decisions](dependency-audit.md), [security CI](security-ci.md) and [reporting](../SECURITY.md) |

## Installed reference

Use `perldoc Ham::CW` for the library and `perldoc ham-cw` for the command.
From a checkout, use `perldoc lib/Ham/CW.pm` or `perldoc bin/ham-cw`.

## Current development edition

Version **0.001**, implementation
[`2168dbc`](https://github.com/gipidevdor/ham-cw/commit/2168dbc6256066d9975bf511f296fea7a269e010),
verified **2026-11-07**. The [verification guide](verification.md) records all
12 required CI jobs passing, 2,886 ordinary assertions and 99.01%/96.22%
statement/branch coverage. The [current raw record](current-results.json)
retains the exact runs and all production-source hashes.

## Reading measurements

[Current five-platform CI measurements](benchmarks.md#ci-platform-measurements-2026-11-07)
cover synthesis, complete/streamed reception and PCM conversion; their
[raw platform record](platform-results.json) retains the current results.
The [local generation review](benchmarks.md#generation-review-2026-11-07)
compares the implementation against its pre-optimization baseline; its
[raw paired record](review-results.json) includes 72 sample/WAV fingerprints.

Peak-RSS measurements belong to the
[2026-10-27 receiver record](benchmarks.md#optimized-reception-2026-10-27),
with [dated raw results](optimization-results.json). They have not been
relabelled as measurements of this edition.
[Benchmark history](benchmark-history.md), [verification history](verification-history.md),
[archived 2026-10-25 verification](verification-20261025-results.json) and
[archived platform results](platform-20261025-results.json) preserve earlier evidence.

The [current security status](security-ci.md#remote-results-2026-11-07) remains
red for pre-existing dependency/interpreter matches; source and workflow
checks pass. The current records distinguish these outcomes.

Project code uses [Artistic License 2.0](../LICENSE). Recording-specific terms,
attribution and transformations are listed in [NOTICE](../NOTICE) and
[recording licenses](../corpus/real/LICENSES.md).
