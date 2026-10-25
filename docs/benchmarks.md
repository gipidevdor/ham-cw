# Measured performance

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Verification](verification.md)

## Local measurements, 2026-10-25

Measured source: `85eb8f3fce614d30cb53eaeb0da6b978dbc3dacc`.
Environment: macOS ARM64, Perl 5.44.0, PDL 2.106. The
[raw measurement record](current-results.json) includes full environment details,
commands, CPU and wall totals, corpus results and SHA-256 hashes of measured
modules, tools and recording inputs. This update does not change the
measured numerical implementation. Command-help and example-interface
refinements do not alter these numerical paths.

The workload is `CQ CQ DE TESTCALL`, 20 WPM, 650 Hz, 8,000 samples/second:
73,440 samples, or **9.18 seconds of audio**. The sample receiver is fed in
4,096-sample blocks. Each table entry is total wall time divided by three
iterations; it is an arithmetic mean, not a median or a percentile. Workloads
were run sequentially without concurrent project tests or coverage collection.

| Operation | Perl | PDL |
| --- | ---: | ---: |
| Generate samples | 0.042 s | 0.012 s |
| Receive samples, tone search | 2.877 s | 3.166 s |
| Generate WAV | 0.076 s | 0.029 s |
| Decode WAV, tone search | 2.909 s | 3.591 s |
| Receive samples, known tone | 0.295 s | 0.252 s |
| Decode WAV, known tone | 0.303 s | 0.263 s |

In this local workload, PDL generates samples and WAV faster. With automatic
tone search it receives samples and decodes WAV slower than Perl. With the
650 Hz tone supplied, PDL is modestly faster for reception. Knowing the tone
reduces processing time substantially for both backends. These observations
are specific to this signal, environment and measurement protocol.

`perl` remains the default. `auto` selects PDL when available, regardless of
speed. Choose a backend using measurements of the operation and hints your
application actually uses. No universal backend speedup is claimed.

## What the timers include

Sample generation includes generator construction and sample synthesis. Sample
reception includes detector construction, block feeds and finalization. WAV
generation and decoding include in-memory file handles, library construction,
PCM conversion and close. The WAV reader uses its default block size; the
benchmark's `--block` controls the direct sample-reception case.

Message/event preparation and source-audio preparation happen outside the
operation timers. WAV output is held in memory. Disk I/O, device I/O, live
capture latency, startup of Perl and loading modules are excluded. Memory use
was not measured. Audio duration is not a processing time: listening to this
signal live still takes 9.18 seconds.

The raw record also contains analyzer rebuilds and batches of 100 cached
snapshot reads. Cached reads are below useful CPU-timer resolution here;
near-zero or tiny negative CPU deltas reflect clock precision. They are not
zero-cost operations and are not included in the performance comparison.
Three iterations on one machine do not establish variance, sustained throughput,
long-recording scaling or guarantees for other inputs.

## Repeat the measurements

Run from the repository root, using the same Perl environment for both backends:

```sh
perl maint/benchmark.pl --json --iterations 3
perl maint/benchmark.pl --json --iterations 3 --known-frequency
perl maint/reception-corpus.pl
```

Record source revision, environment, commands and measured-input hashes with
new output. Preserve the original totals; state whether a derived table uses
CPU or wall time and mean or median. Run timing workloads separately from tests.
`perl maint/benchmark.pl --help` describes workload controls. For the CI-style
per-operation rate protocol, use `perl maint/benchmark-platforms.pl --help`.
These protocols measure different things and their values are not interchangeable.

## CI platform measurements, 2026-10-25

[Test run 40187441836](https://github.com/gipidevdor/ham-cw/actions/runs/40187441836)
measured the same source revision on five configurations. The
[raw platform results](platform-results.json) retain absolute rates, call counts,
elapsed times, Perl/PDL versions, artifact names and hashes. All use Perl 5.40
and PDL 2.106 except the minimum configuration, Perl 5.20 and PDL 2.081.
The runner labels identify the configured macOS ARM64 and Intel jobs; the raw
Perl architecture string alone does not distinguish those CPU families.

The message is `CQ CQ DE TESTCALL` at 8,000 Hz; receiver tone is searched.
Each operation is warmed once, then measured for at least one wall-clock second
with complete calls. Slow reception cases contain only one measured call.
PCM cases read/write one second of mono audio in memory at each bit depth;
they are raw PCM conversion, distinct from complete message generation/decoding.

Each ratio is PDL calls/second divided by Perl calls/second on the same runner.
Above 1 favours PDL; below 1 favours Perl. These are single shared-runner
observations, not stable platform rankings or processor comparisons.

| Operation | Linux | macOS ARM64 | macOS Intel | Windows | Linux minimum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Generate samples | 3.57x | 3.70x | 3.37x | 2.81x | 3.56x |
| Receive, complete feed | 1.00x | 0.97x | 1.19x | 0.79x | 1.00x |
| Receive, 4,096-sample feeds | 0.91x | 0.71x | 0.99x | 0.79x | 0.83x |
| Read PCM WAV, 8-bit | 1.01x | 0.85x | 0.90x | 0.71x | 0.90x |
| Read PCM WAV, 16-bit | 1.15x | 1.07x | 1.21x | 0.81x | 1.01x |
| Read PCM WAV, 24-bit | 0.96x | 1.07x | 0.97x | 0.88x | 0.95x |
| Write PCM WAV, 8-bit | 1.41x | 1.34x | 1.39x | 1.31x | 1.34x |
| Write PCM WAV, 16-bit | 1.49x | 1.14x | 1.36x | 1.32x | 1.42x |
| Write PCM WAV, 24-bit | 1.33x | 1.32x | 1.34x | 1.20x | 1.28x |

Generation benefits from PDL in these cases. Reception and PCM conversion vary
by platform and feed pattern; the earlier blanket reception speedup claim is
not supported by this receiver. Compare absolute rates in the raw record when
planning throughput, and repeat your actual workload before choosing a backend.

## Historical evidence

[Archived benchmark observations](benchmark-history.md),
[earlier local raw results](benchmark-results.json) and
[earlier platform raw results](platform-history-results.json) describe earlier receiver
implementations. Their speed ratios and message-length tables do not describe
the measured revision above. The current CI platform comparison is reported
above; archived rates remain associated with their earlier source revisions.
