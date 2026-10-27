# Ham::CW

Ham::CW converts text to Morse, generates WAV and MIDI files, and decodes
recorded CW. Use it through the Perl API or the `ham-cw` command.

Requires Perl 5.20 or later. The default backend uses core modules; PDL is
optional. Audio reception is experimental.

[Online documentation](https://gipidevdor.github.io/ham-cw/) ·
[Guides](docs/README.md) · [Examples](examples/README.md) ·
[API reference](lib/Ham/CW.pm) · [Contributing](CONTRIBUTING.md)

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

Builds require ExtUtils::MakeMaker 7.22 or later and your Perl's make program.
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

## Measured reception

Local measurements on 2026-10-27: macOS ARM64, Perl 5.44.0 and PDL 2.106.
Each case receives 9.18 seconds of audio at 20 WPM. Times are the mean of
three calls; peak RSS covers a fresh worker process, including its inputs
and loaded modules.

| Case | Perl: time / peak RSS | PDL: time / peak RSS |
| --- | ---: | ---: |
| 8 kHz, tone search | 2.796 s / 25.03 MiB | 1.780 s / 31.58 MiB |
| 8 kHz, known tone | 0.271 s / 19.92 MiB | 0.208 s / 27.23 MiB |
| 16 kHz, tone search | 4.963 s / 27.94 MiB | 3.204 s / 34.78 MiB |

The optimized PDL receiver uses 36–41% less wall time and 51–54% less peak RSS
than the recorded baseline in the tone-search cases. PDL is faster in these
cases; Perl uses less resident memory. Repeat with
`perl maint/benchmark.pl --rss --json`.
See the [protocol and before/after results](docs/benchmarks.md) and
[raw measurements](docs/optimization-results.json). The
[verification record](docs/verification.md) lists reception and test coverage.

## Explore the project

[Documentation](docs/README.md) · [Contributing](CONTRIBUTING.md) ·
[Release procedure](docs/releasing.md) · [Security reports](SECURITY.md)

[Security audit](docs/security-ci.md): Perl/File::Temp advisories and older dependency versions remain under review.

Copyright © 2026 Giacomo Picchiarelli. Project code and original material use
[Artistic License 2.0](LICENSE). Third-party audio retains its CC0 or CC BY-SA
3.0 terms; see [NOTICE](NOTICE) and [recording licenses](corpus/real/LICENSES.md).
