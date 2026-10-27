# Measured performance

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Verification](verification.md)

## Optimized reception, 2026-10-27

The receiver now uses complex Goertzel acquisition, packed PDL windows,
in-place window operations and inner products. A 16,384-element batch budget
adapts to channel count and sample rate, with a one-hop floor and 128-hop cap.
The [architecture guide](architecture.md#optional-pdl-backend) describes the
buffer policy and numerical path.

These changes improve CPU time and peak RSS on the measured workloads.
[Optimization results](optimization-results.json) preserve the before/after
comparison, all 36 final rows, exploratory batch sweeps, source hashes and
commands. The baseline is [resource-results.json](resource-results.json).
Both records use fresh processes, three timed calls per operation/backend,
9.18 seconds of audio and the same source input hashes. Timed workloads ran
sequentially without tests or coverage in parallel. Production files changed
only in `Detector.pm` and `_Internal/PDL.pm`; the base revision is
`f9a1dac329164cd1a5857ac1fa845e77a3e2e667`.

### Sample reception before and after

| Workload / backend | Wall time/call, before → after | Peak RSS, before → after |
| --- | ---: | ---: |
| 8 kHz, searched tone / perl | 2.904 → 2.796 s | 25.25 → 25.03 MiB |
| 8 kHz, searched tone / pdl | 2.797 → 1.780 s | 68.22 → 31.58 MiB |
| 8 kHz, known 650 Hz tone / perl | 0.302 → 0.271 s | 20.08 → 19.92 MiB |
| 8 kHz, known 650 Hz tone / pdl | 0.250 → 0.208 s | 28.27 → 27.23 MiB |
| 16 kHz, searched tone / perl | 5.298 → 4.963 s | 28.17 → 27.94 MiB |
| 16 kHz, searched tone / pdl | 5.404 → 3.204 s | 71.08 → 34.78 MiB |

### Complete WAV decoding before and after

| Workload / backend | Wall time/call, before → after | Peak RSS, before → after |
| --- | ---: | ---: |
| 8 kHz, searched tone / perl | 2.912 → 2.727 s | 23.28 → 23.17 MiB |
| 8 kHz, searched tone / pdl | 2.810 → 1.750 s | 66.38 → 29.88 MiB |
| 8 kHz, known 650 Hz tone / perl | 0.304 → 0.271 s | 18.30 → 18.08 MiB |
| 8 kHz, known 650 Hz tone / pdl | 0.257 → 0.238 s | 26.31 → 25.22 MiB |
| 16 kHz, searched tone / perl | 5.303 → 4.931 s | 24.14 → 23.94 MiB |
| 16 kHz, searched tone / pdl | 5.351 → 3.002 s | 67.19 → 30.50 MiB |

For PDL with tone search, sample-reception wall time falls by **36% at 8 kHz**
and **41% at 16 kHz**; process peaks fall by **54% and 51%**. At 16 kHz,
complete WAV decoding falls from 5.351 to 3.002 seconds and from 67.19 to
30.50 MiB. The full suite passes **2,652 assertions across 31 files**, including
independent complex-DFT checks, arbitrary feed sizes, backend equivalence,
simultaneous stations, noise/fading cases and the licensed real recordings.
All **716 author assertions in 11 files** also pass, including documentation,
site links, metadata, licenses and candidate archives. The separate corpus
report retains CER 0% and no warnings in all eight speed-mode decodes.

The batch sweep compared 1, 4, 16, 64 and 128 hops at 8/16 kHz, plus a
three-call check of two hops at 16 kHz. Larger batches saved little time in
the exploratory screen and increased RSS. The selected budget favours small
working buffers while retaining most throughput. The single-call screen does
not establish timing variance or a universal mathematical optimum.

These results are local to macOS ARM64, Perl 5.44.0 and PDL 2.106. PDL remains
faster for these reception workloads; Perl has the lower process RSS. Windows,
Linux, the minimum PDL version and long recordings were not rerun here.
The existing `--rss` commands below repeat the optimized implementation;
the unmodified baseline remains in its dated raw record.

## Local CPU, wall time and peak RSS, 2026-10-27

This section records the **baseline before the receiver optimizations above**.

Measured library source: `f9a1dac329164cd1a5857ac1fa845e77a3e2e667`, with the new benchmark
instrumentation in the working tree. Production modules are unchanged.
Environment: macOS ARM64, Perl 5.44.0, PDL 2.106.
[Raw resource results](resource-results.json) retain all 36 rows, commands,
CPU/wall totals, process peaks, environment and SHA-256 values for the measured
sources and inputs.

The message is `CQ CQ DE TESTCALL`, 20 WPM, 650 Hz, **9.18 seconds of audio**.
Sample reception uses 4,096-sample blocks; tone searches examine 25 candidates
from 300 to 1500 Hz at 50 Hz spacing. Known-tone runs supply only the tone,
with speed still estimated. Each row contains three timed calls in a fresh
Perl worker for that operation/backend. Workers and workloads ran sequentially,
without concurrent tests or coverage collection.

### Sample reception

| Workload | Perl wall/call | Perl peak RSS | PDL wall/call | PDL peak RSS |
| --- | ---: | ---: | ---: | ---: |
| 8 kHz, searched tone | 2.904 s | 25.25 MiB | 2.797 s | 68.22 MiB |
| 8 kHz, known 650 Hz tone | 0.302 s | 20.08 MiB | 0.250 s | 28.27 MiB |
| 16 kHz, searched tone | 5.298 s | 28.17 MiB | 5.404 s | 71.08 MiB |

### Complete WAV decoding

Includes WAV reading, PCM conversion, detector construction, reception and close.

| Workload | Perl wall/call | Perl peak RSS | PDL wall/call | PDL peak RSS |
| --- | ---: | ---: | ---: | ---: |
| 8 kHz, searched tone | 2.912 s | 23.28 MiB | 2.810 s | 66.38 MiB |
| 8 kHz, known 650 Hz tone | 0.304 s | 18.30 MiB | 0.257 s | 26.31 MiB |
| 16 kHz, searched tone | 5.303 s | 24.14 MiB | 5.351 s | 67.19 MiB |

### Generation

WAV generation streams the output into an in-memory handle and includes PCM
conversion. The sample-generation operation collects the complete sample array.
These rows use the searched-tone workload records; tone selection does not
affect generation.

| Rate / operation | Perl wall/call | Perl peak RSS | PDL wall/call | PDL peak RSS |
| --- | ---: | ---: | ---: | ---: |
| 8 kHz / samples | 0.041 s | 17.95 MiB | 0.010 s | 25.84 MiB |
| 8 kHz / WAV | 0.075 s | 16.22 MiB | 0.026 s | 25.03 MiB |
| 16 kHz / samples | 0.082 s | 20.41 MiB | 0.015 s | 29.08 MiB |
| 16 kHz / WAV | 0.150 s | 16.39 MiB | 0.049 s | 25.86 MiB |

The largest measured receiver peak is **71.08 MiB for PDL at 16 kHz with
tone search**. At 8 kHz, supplying the tone lowers sample-reception peaks from
25.25 to 20.08 MiB for Perl and from 68.22 to 28.27 MiB for PDL. These process
totals describe these fixed workloads; they do not establish constant-memory
streaming or a general memory ceiling.

### How RSS is measured

`--rss` executes every operation/backend in a separate Perl process under
`/usr/bin/time`: macOS `-l` supplies bytes; GNU/Linux `-v` supplies KiB,
which the report multiplies by 1024. MiB means bytes divided by 1,048,576.
RSS is the OS maximum resident set size over the whole worker, including
startup, loaded modules, necessary input preparation and all iterations. It
is neither an allocation delta nor an average per call. Snapshot peaks also
include the prepared detector and retained input. Perl-only workers skip the
PDL availability probe, keeping PDL out of their measurements.

CPU/wall timers cover the operation calls and exclude startup, module loading
and input preparation. There is no operation warmup, except preparing the
detector and cached result needed by the snapshot cases. The raw record includes
analyzer rebuilds and batches of 100 cached snapshot reads. Very short CPU
deltas are limited by timer precision.

There is one RSS peak per case; memory variance and long recordings have not
been measured. Only macOS was measured here. Linux uses a separate native
parser; Windows retains timing-only benchmarks. The isolated-worker timings
and the older shared-process timings below are different protocols, so their
differences are not evidence of a library optimization.

### Repeat times and RSS

Run from the repository root:

```sh
perl maint/benchmark.pl --rss --json --iterations 3
perl maint/benchmark.pl --rss --json --iterations 3 --known-frequency
perl maint/benchmark.pl --rss --json --iterations 3 --rate 16000
perl maint/benchmark.pl --rss --backend perl --operation detect --known-frequency
```

Omit `--json` for a readable report with CPU seconds/call, wall seconds/call
and peak MiB. `--backend` accepts `all`, `perl` or `pdl`; `--operation`
accepts the six names listed by `--help`. Explicit PDL selection fails if PDL
is unavailable. Unsupported RSS platforms or failed workers fail explicitly,
without reporting a zero or substituting another memory metric.

## Earlier shared-process local measurements, 2026-10-25

Measured source: `c635a8ad588558a2d12bb0557d863cd571b61349`.
Environment: macOS ARM64, Perl 5.44.0, PDL 2.106.
[Raw results](performance-results.json) include commands, sample counts,
CPU/wall totals, ratios and source hashes. These runs use the shipped implementation.

All cases generate `CQ CQ DE TESTCALL` at 20 WPM and 650 Hz: **9.18 seconds
of audio**, fed in 4,096-sample blocks. Searches cover 300–1500 Hz at 50 Hz
spacing, or 25 candidates. The known-tone case supplies 650 Hz but no speed
hint to reception. Times are the mean of three calls. Workloads ran sequentially,
without concurrent tests or coverage collection.

### Sample reception

`R` is processing seconds divided by audio seconds. Lower is better; `R < 1`
means this in-memory recording was processed faster than playback duration.
Its inverse, `1/R`, is audio seconds processed per wall second. Live capture
latency is excluded.

| Workload | Perl time | PDL time | Perl R | PDL R |
| --- | ---: | ---: | ---: | ---: |
| 8 kHz, tone search (25 candidates) | 2.885 s | 3.127 s | 0.314 | 0.341 |
| 8 kHz, known 650 Hz tone (1 candidate) | 0.299 s | 0.251 s | 0.033 | 0.027 |
| 16 kHz, tone search (25 candidates) | 5.284 s | 6.039 s | 0.576 | 0.658 |

At 8 kHz, the measured sample receiver processes approximately **3.18× audio
speed with Perl and 2.94× with PDL** during tone search. With the tone supplied,
the figures are **30.70× and 36.55×**. At 16 kHz with search they fall to
**1.74× and 1.52×**, below the 5× target at 16 kHz. These measurements are for
macOS; Linux and Raspberry Pi throughput were not measured in this run.

### Complete WAV decoding

These calls also include in-memory WAV reading, PCM conversion and close:

| Workload | Perl time | PDL time |
| --- | ---: | ---: |
| 8 kHz, tone search | 2.906 s | 3.607 s |
| 8 kHz, known tone | 0.307 s | 0.264 s |
| 16 kHz, tone search | 5.376 s | 6.939 s |

### Generation

WAV generation includes PCM conversion.

| Sample rate | Samples, Perl | Samples, PDL | WAV, Perl | WAV, PDL |
| --- | ---: | ---: | ---: | ---: |
| 8 kHz | 0.042 s | 0.012 s | 0.076 s | 0.029 s |
| 16 kHz | 0.084 s | 0.021 s | 0.152 s | 0.056 s |

PDL accelerates generation in these cases. Its current tone-search reception
is slower than Perl in both sample-rate cases; known-tone reception is faster.
`perl` remains the default. `auto` selects PDL by availability and does not
benchmark or choose a backend by workload.

## Why PDL is only partly accelerated

In the 2026-10-25 implementation measured above, PDL handled tone synthesis,
PCM operations and filtered spectral projections. Acquisition projections,
guard/ring processing and biquad recurrences ran in Perl. Each receiver batch
copied filtered history windows into Perl arrays, built a PDL tensor and
exported powers/energies back to arrays.

That revision used a fixed **128-hop cap**. A separate 16-hop experiment was
excluded from those results. The optimized implementation described at the
top of this page now uses packed windows, inner products and a batch budget
based on window size and channel count. Compiled PDL::PP filters and persistent
PDL feature storage remain outside the implementation.

## What the timers include

Sample generation includes generator construction and synthesis. Sample
reception includes detector construction, block feeds and finalization. WAV
operations include in-memory handles, library construction, conversion and
close. The WAV reader uses its default block size; `--block` controls direct
sample reception. Event preparation and preparation of the source audio are
outside the operation timers. Disk I/O, devices, Perl startup and module loading
are excluded. That run did not measure memory use, 128-candidate searches or
sustained long-recording throughput.

Operations and backends run in a fixed order within one process, with a
prepared detector retained for snapshot measurements. Allocation history can
affect the timings. Raw output also includes analyzer rebuilds and batches of
100 cached snapshot reads; tiny or negative CPU deltas reflect timer precision.
Three calls are insufficient to estimate variance or percentile latency.

## Repeat the measurements

Run from the repository root in the same Perl environment:

```sh
perl maint/benchmark.pl --json --iterations 3
perl maint/benchmark.pl --json --iterations 3 --known-frequency
perl maint/benchmark.pl --json --iterations 3 --rate 16000
```

Preserve raw totals and record revision, environment, commands and input hashes.
Use wall time for the ratios above and state how averages are derived. Keep
timing runs separate from tests. `perl maint/benchmark.pl --help` describes
workload controls. `perl maint/benchmark-platforms.pl --help` describes the
separate CI rate protocol; its rates and these call means are not interchangeable.
Use `perl maint/reception-corpus.pl` to measure accuracy separately from speed.

## Earlier CI platform measurements, 2026-10-25

[Test run 40187441836](https://github.com/gipidevdor/ham-cw/actions/runs/40187441836)
measured source `85eb8f3fce614d30cb53eaeb0da6b978dbc3dacc` on five configurations.
These are earlier measurements, not a fresh platform run of `c635a8a`. The
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

PDL improves generation in these runs. Reception and PCM conversion vary by
platform and feed pattern. Compare absolute rates in the raw record and measure
your own workload before choosing a backend.

## Historical evidence

[Benchmark history](benchmark-history.md) retains earlier local observations.
[Earlier local raw results](benchmark-results.json),
[the 85eb8f3 timing and verification record](current-results.json) and
[earlier platform raw results](platform-history-results.json) belong to their
original sources. The earlier shared-process record is [performance-results.json](performance-results.json).
The earlier CI table above remains explicitly tied to `85eb8f3`.
The latest local CPU/wall and peak-RSS record is [optimization-results.json](optimization-results.json).
