# Documentation

[Project](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md)

Choose the guide for what you want to do.

| You want to… | Start here |
| --- | --- |
| Install or check your environment | [Installation](installing.md) |
| Convert text, make files or receive CW | [Task guide](usage.md#command-line-use) |
| Resolve an error or warning | [Recovery guide](usage.md#when-you-need-help) |
| Use the library in an application | [Library recipes](usage.md#library-recipes) |
| Find a runnable API example | [Example catalog](../examples/README.md#choose-a-path) |
| Choose an API or representation | [Interfaces](usage.md#choose-an-interface) and [data representations](usage.md#choose-the-data-representation) |
| Understand timing, state and filtering | [Architecture](architecture.md) |
| Understand detector thresholds | [Power heuristics](architecture.md#detector-power-heuristics) |
| Compare backend speed | [Measured performance](benchmarks.md) |
| Assess the evidence and its limits | [Verification](verification.md) and [reference corpus](../corpus/README.md) |
| Change or release the project | [Contributing](../CONTRIBUTING.md) and [release procedure](releasing.md) |
| Review dependencies or security | [Dependency decisions](dependency-audit.md), [security CI](security-ci.md) and [reporting](../SECURITY.md) |

## Installed reference

The API reference is POD embedded in each public module. After installation,
use `perldoc Ham::CW` for the library and `perldoc ham-cw` for the command.
From a checkout, use `perldoc lib/Ham/CW.pm` or `perldoc bin/ham-cw`.
Each module documents its own options, units, ranges, return values and errors.

## Reading measurements

Performance and verification records identify the measured source and date.
[Benchmark history](benchmark-history.md) and
[verification history](verification-history.md) retain older observations.
Use their stated revisions when interpreting results.

Project code uses [Artistic License 2.0](../LICENSE). Recording-specific terms,
attribution and transformations are listed in [NOTICE](../NOTICE) and
[recording licenses](../corpus/real/LICENSES.md).
