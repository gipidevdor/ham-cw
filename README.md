# Ham::CW

Ham::CW converts text to Morse, generates WAV and MIDI files, and decodes
recorded CW. Use it through the Perl API or the `ham-cw` command.

Requires Perl 5.20 or later. The default backend uses core modules; PDL is
optional. Audio reception is experimental.

[Online documentation](https://gipidevdor.github.io/ham-cw/) ·
[Guides](docs/README.md) · [Examples](examples/README.md) ·
[API reference](lib/Ham/CW.pm) · [Contributing](CONTRIBUTING.md)

## Current development edition

Version **0.001**, verified on **2026-11-07**, with implementation
[`2168dbc`](https://github.com/gipidevdor/ham-cw/commit/2168dbc6256066d9975bf511f296fea7a269e010).
All **12 required CI jobs pass**, including Linux Perl 5.20, 5.34, 5.40 and 5.44,
macOS/Windows, PDL 2.081 and PDL 2.106. The ordinary suite has **2,886
assertions in 33 files**. CI production coverage is **99.01% statements**
and **96.22% branches** across all 20 modules. Archive, isolated installation,
installed command and example checks pass.

The [dependency audit](docs/security-ci.md#remote-results-2026-11-07) remains
red for pre-existing matches; no new advisory IDs were found relative to the
previous main revision. See the [current verification record](docs/verification.md)
for scope, exact runs and source hashes.

## Start here

Run from a checkout without installing:

```sh
perl -Ilib bin/ham-cw encode "CQ TEST"
perl -Ilib bin/ham-cw decode -- "-.-. --.- / - . ... -"
```

These commands convert `CQ TEST` to Morse and back. Spaces separate letters;
`/` separates words. Use `--` before Morse that starts with a dash.

To install from a checkout or extracted distribution:

```sh
perl Makefile.PL
make
make test
make install
```

Builds require ExtUtils::MakeMaker 7.22 or later, core ExtUtils::Manifest and
your Perl's make program. Installation includes only manifest-listed modules.
See [installation](docs/installing.md) for user-owned paths and upgrades.
Once installed, run `ham-cw` directly.

## Make a practice recording

```sh
ham-cw wav --wpm 20 --effective-wpm 12 --output practice.wav "CQ TEST"
ham-cw receive --frequency 700 --wpm 20 --effective-wpm 12 practice.wav
```

This creates a 20 WPM recording with 12 WPM Farnsworth spacing, then reads it
with matching tone and speed hints. Add `--overwrite` to replace an existing file.

| You want to… | Command |
| --- | --- |
| Convert text | `ham-cw encode "CQ TEST"` |
| Read Morse | `ham-cw decode -- "... --- ..."` |
| Inspect timing | `ham-cw events "SOS"` |
| Export MIDI | `ham-cw midi --output practice.mid "CQ TEST"` |
| Inspect a recording and its warnings | `ham-cw receive --json recording.wav` |
| Find options for one task | `ham-cw help receive` |

Text commands accept `--input FILE` or stdin. Use `--output FILE` to save
text or JSON. WAV and MIDI require an explicit output; `--output -` selects
binary stdout. Prefer named binary files in Windows shells.

Use `ham-cw help COMMAND` for options and examples, or the
[recovery guide](docs/usage.md#when-you-need-help) for errors and reception warnings.

## Use it in Perl

Save as `demo.pl` and run `perl -Ilib demo.pl` from this checkout,
or `perl demo.pl` after installation:

```perl
use 5.020;
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20, frequency => 700);
print $cw->encode('SOS'), "\n";
print $cw->decode('... --- ...'), "\n";

my $result = $cw->decode_wav_bytes(
    $cw->wav_bytes('SOS'), frequency => 700, wpm => 20);
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
```

More recipes: [task guide](docs/usage.md#library-recipes) and
[examples](examples/README.md). Read the API with `perldoc Ham::CW`, or
`perldoc lib/Ham/CW.pm` from a checkout.

## Know what to expect

Morse symbols follow ITU-R M.1677-1. Write prosigns as tokens such as `<AR>`
and quote them in the shell. The [symbol table](docs/usage.md#symbol-policy)
lists the accepted characters and tokens.

The receiver can separate CW signals on distinct tones. Interference, fading
and uncertain timing can still produce partial or incorrect text. Check its
warnings; `--strict` returns a nonzero status when warnings occur. See
[reception limits](docs/usage.md#practical-limits) and [test results](docs/verification.md).

Playback, microphone capture and radio or MIDI device control are left to the
calling application.

## Measured performance

The [2026-11-07 generation review](docs/benchmarks.md#generation-review-2026-11-07)
measured 56–63% less Perl sample-generation time and 26–36% less complete
WAV-generation time at 8, 16 and 44.1 kHz, with 72 unchanged sample/WAV
fingerprints. These local paired measurements use macOS ARM64, Perl 5.44.0
and PDL 2.106; the linked raw record includes source hashes and both backends.

The [current five-platform CI measurements](docs/benchmarks.md#ci-platform-measurements-2026-11-07)
also cover synthesis, streamed/complete reception and PCM conversion. For this
fixed 8 kHz workload, PDL sample synthesis runs at 1.14–2.11 times the Perl
rate and streamed reception at 1.49–1.67 times the Perl rate across the five
measured configurations. These are individual hosted-run observations.

All eight hinted/estimated-speed decodes of the four licensed corpus clips
retain **CER 0% and no warnings**. The [verification guide](docs/verification.md)
describes their limited scope. Earlier receiver CPU/RSS measurements remain
explicitly dated in the [performance guide](docs/benchmarks.md#optimized-reception-2026-10-27).

## Explore the project

[Documentation](docs/README.md) · [Contributing](CONTRIBUTING.md) ·
[Release procedure](docs/releasing.md) · [Security reports](SECURITY.md)

[Security audit](docs/security-ci.md): two installed-environment matches and
39 declared-range matches remain under review; these are scanner matches,
not counts of confirmed Ham::CW vulnerabilities.

Copyright © 2026 Giacomo Picchiarelli. Project code and original material use
[Artistic License 2.0](LICENSE). Third-party audio retains its CC0 or CC BY-SA
3.0 terms; see [NOTICE](NOTICE) and [recording licenses](corpus/real/LICENSES.md).
