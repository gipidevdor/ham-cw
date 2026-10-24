# Verification

The complete product was checked locally on 2026-10-24, including the installed
command and optional PDL backend. The runtime source is commit
`da8c80d4c6b4a28e9972d89e689761eafd8a70ee`; the final packaging changes only
consolidate POD and record verification evidence. Historical message timings
are kept separately below.

## Current local checks

| Check | Result |
| --- | --- |
| Ordinary suite, macOS ARM64, Perl 5.44.0 with PDL 2.106 | 2,005 assertions across 25 files; PASS |
| Ordinary suite with all Perl warnings fatal | 2,005 assertions; PASS |
| System Perl 5.34.1 without PDL | 1,832 assertions across 25 files; PASS |
| Author checks | 347 assertions across 7 files; PASS |
| Perl::Tidy 20260826 and Perl::Critic 1.156 | PASS |
| Public POD headings, local links and executable documentation examples | PASS |
| Production statement coverage | 99.39% (1,795/1,806); PASS |
| Production branch coverage | 97.18% (620/638); PASS |
| Distribution build/test, archive checks and isolated installation | PASS |

Coverage checks require all 19 production modules, including the CLI, PDL
implementation and internal snapshot builder. Missing or duplicate production
paths fail the gate before percentages are considered. No path was exempted to meet the
95% statement and 90% branch thresholds.

## Regression evidence

Timing tests reproduce the discontinuity at 32 repeated shortest marks and
cover a broad set of distinct mark widths. Independent 25 and 50 WPM SOS
schedules run for approximately 62 and 31 seconds, with hard keying and 5 ms
raised-cosine ramps. Both backends recover the text, estimate speed within
five percent and avoid false spacing warnings. Additional generated-message
probes at 20, 25, 40, 50 and 60 WPM returned the configured speeds.

File tests check permission preservation, new-file umask, ordinary and
dangling symbolic-link rejection, existing-byte preservation on generation
failure and temporary-file cleanup. POSIX permission assertions and symlink
tests are skipped on systems that cannot represent those features.

Snapshot tests check cache invalidation, preservation of previous snapshots
when marks are coalesced, independent public accessors and rejection of
unsafe caller metadata before state changes. New cumulative snapshots still
process retained history; frequent snapshots after tiny feeds have a
cumulative cost. The optimization removes repeated internal deep validation
and copying, while keeping public Result construction fully validated.
Block-callback tests also mutate warning lists and warning hashes to verify
metadata isolation between callbacks.

The full suite additionally covers fixed Morse vectors, independent synthetic
signals, PCM/MIDI byte checks, malformed files, real closed-pipe writes,
resource limits and path/stream workflows. The corpus is synthetic: off-air
accuracy, overlapping transmitters and unlimited reception are not established.

## CI and release checks

The workflow contains twelve checks: six ordinary Perl combinations, five
PDL configurations and one author/distribution job. PDL covers Linux, macOS
ARM/Intel and Windows with Strawberry Perl; the minimum Perl 5.20 / PDL 2.081
combination uses Ubuntu 22.04's compatible compiler.

PDL and the pinned formatter use the setup action's dependency cache.
Successful dependency builds use normal installer output rather than verbose
compiler output, avoiding unrelated optional-module diagnostics being matched
as project failures. Cached installations remain subject to the complete test
suite. All twelve checks passed on the runtime commit above in
[run 40094023069](https://github.com/gipidevdor/ham-cw/actions/runs/40094023069),
including production coverage, archive analysis and isolated installation.
See [CI runs](https://github.com/gipidevdor/ham-cw/actions/workflows/test.yml)
for subsequent candidates. These checks are not CPAN Testers certification
or a PAUSE upload.

## Current platform measurements

These measurements come from the successful twelve-job run above, on the
runtime source named at the top of this record. The checked-in
[raw platform results](platform-results.json) retain the original rates,
iteration counts, elapsed times and environment metadata from all five
benchmark artifacts.

The workload was the literal message `CQ CQ DE TESTCALL` at 8000 Hz. PCM
cases read or write one second of mono WAV in memory, including validation,
headers and public array conversion, excluding disk I/O. Reception uses
either one complete feed or 4096-sample feeds. Each case warms up once and
then runs for at least one wall-clock second.
`maint/benchmark-platforms.pl` reproduces that protocol.

Each ratio is PDL calls/second divided by Perl calls/second on the same
runner. Values above 1 favour PDL; values below 1 favour Perl. These short,
single-run observations on shared hosted machines do not establish stable
backend rankings.

| Operation | Linux | macOS ARM64 | macOS Intel | Windows | Linux minimum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Audio generation | 4.87x | 5.31x | 5.08x | 2.90x | 4.22x |
| Detection, complete array | 5.59x | 6.22x | 7.14x | 4.26x | 5.14x |
| Detection, 4096-sample feeds | 5.29x | 5.08x | 6.12x | 3.65x | 4.76x |
| PCM WAV read, 8-bit | 1.02x | 1.06x | 1.15x | 0.71x | 0.98x |
| PCM WAV read, 16-bit | 1.14x | 0.99x | 1.20x | 0.86x | 1.05x |
| PCM WAV read, 24-bit | 1.05x | 0.88x | 1.27x | 0.93x | 0.98x |
| PCM WAV write, 8-bit | 1.47x | 1.23x | 2.59x | 1.27x | 1.43x |
| PCM WAV write, 16-bit | 1.52x | 1.09x | 1.64x | 1.29x | 1.48x |
| PCM WAV write, 24-bit | 1.38x | 1.21x | 1.33x | 1.10x | 1.36x |

PDL accelerates synthesis and detection substantially in these cases. PCM
conversion has a smaller, workload-dependent benefit; some cases are slower
with PDL. The automatic selector chooses by availability, not measured speed.

## Dependency advisory review

The installed environment was audited with
`cpan-audit installed --perl --no-color --json`, CPAN::Audit 20261013.002
and advisory database 20261018.001. It reported three advisories, no scanner
errors and a nonzero exit status. The dependency audit is **not clean**.
Static review of these three matches found no confirmed product vulnerability,
but two environment-dependent questions remain:

- [Pod::Text margin handling](https://github.com/rra/podlators/commit/70510174f69eb54aa6d617bde4e1402cd9b7c61f.patch):
  podlators v6.0.2 is affected; update documentation tools to >=6.1.1.
  Ham::CW does not accept or render POD input, and CLI help is literal text.
- [File::Temp directory checks](https://github.com/Perl-Toolchain-Gang/File-Temp/issues/14):
  the audit lists every version with no fixed release. Ham::CW creates
  exclusive temporary files and does not rely on `_is_safe` as an input
  validator. Directory ownership/permissions still require review for hosts
  shared with hostile local users. Output paths are selected by the caller.
- [Perl regex cache overflow](https://github.com/Perl/perl5/commit/54cf3d44cbbedd17d774e9a37921963e8fd5d0cb.patch):
  the local Perl build source contains the upstream overflow guard, while
  the scanner matches the unchanged Perl version number. Binary provenance
  and consumer-provided runtimes remain deployment questions. CLI text is
  capped at 1 MiB, below the very large subject needed by this advisory;
  this does not certify every library consumer. Use a vendor-patched Perl.

The separate declared-constraints audit used a `cpanfile` generated from
`MYMETA.json` by CPAN::Meta/Module::CPANfile, preserving phases, relations and
optional PDL. `cpan-audit deps DIRECTORY --perl --no-color --json` reported
67 advisory matches, no scanner errors and a nonzero exit status. Broad
supported-version constraints include historical releases, so this is a
different result from the three installed-version matches, not 67 confirmed
vulnerabilities in the installed environment. Those additional constraint
matches have not received an individual applicability review.

Running `cpan-audit deps .` directly on this MakeMaker project did not audit
the declared prerequisites correctly; the generated manifest is the supported
input. See [security CI](security-ci.md) for the conversion and separate
installed/declared gates. No advisory was suppressed and no nonexistent fixed
version was substituted. This is a static review of the three installed
matches, not an exhaustive security audit or an exploit-validation result.

## Archived measurements

Earlier platform observations came from commit
`4e0a7e79a8e5d5fa76040d89d8c852c603667d67` in
[run 40086118418](https://github.com/gipidevdor/ham-cw/actions/runs/40086118418).
The earlier [local benchmark data](benchmark-results.json) also predates the
current corrections. Those measurements do not describe the corrected
estimator or snapshot path.

### Archived message-length timings (2026-10-24)

These earlier measurements, also preceding the current corrections, use the literal message `CQ DE TESTCALL`, repeated
one, two, four, eight or twelve times with one separating space. Message
length is the actual character count including spaces, and audio duration
comes from the generated events. No reference-word equivalence is used.
These measurements replace the previous message-length example.

The sample rate was the default 16000 Hz at 20 WPM, on macOS ARM64 with
Perl 5.44.0 and PDL 2.106. Each processing time is the median of three
new runs, in seconds.

| Repeated messages | Characters, including spaces | Audio duration | Generate, Perl | Generate, PDL | Analyze, Perl | Analyze, PDL |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 14 | 7.14 | 0.076 | 0.011 | 0.381 | 0.056 |
| 2 | 29 | 14.70 | 0.154 | 0.024 | 0.782 | 0.112 |
| 4 | 59 | 29.82 | 0.310 | 0.050 | 1.580 | 0.230 |
| 8 | 119 | 60.06 | 0.619 | 0.104 | 3.186 | 0.471 |
| 12 | 179 | 90.30 | 0.935 | 0.158 | 4.781 | 0.706 |

Generation measures sample synthesis, including generator construction.
Analysis measures 4096-sample feeds and finalization with the default
frequency search grid; detector construction is outside that timer.
The audio is already available in memory. PCM conversion, file I/O and
live reception time are excluded. These are measured cases, not estimates
extrapolated from the short CI benchmark.

Default reception retains at most 24000 frames, approximately 120 seconds
including silence. Longer recordings require a larger explicit `max_frames`
and more retained memory. The time needed to transmit or receive the audio
in real time remains its full audio duration.

## CLI integration

The installed `ham-cw` command shares the library's encoding, file and
reception paths. The integrated tests include subprocess UTF-8/CRLF input,
text and binary outputs, option validation, exit codes, bounded WAV stdin,
strict warnings, protected output replacement and closed pipes. The installer
checks all six commands and the Windows launcher in a path containing spaces.
The coverage numbers at the top include the CLI implementation; all 19
production modules must be present before the coverage gate can pass.

## Security audit corrections after packaging

The subsequent correction updates vulnerable build/author prerequisites and
uses a tested discovery adapter while retaining each original scanner report.
Installed-version matches fall from three to two; correctly scoped declared
matches fall from the original 67 to 38. Both gates remain nonzero. See
[security CI](security-ci.md#corrective-local-results-2026-10-24) for versions,
remaining components and the distinction between compatibility and security.
Runtime implementation and its earlier coverage measurements are unchanged.
