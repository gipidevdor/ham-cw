# Ham::CW

Morse, from text to signal and back.

Encode text, shape its timing, create WAV or MIDI files, and read recorded CW.
Use the `ham-cw` command or the Perl library. Perl 5.20 or later is required;
the default backend uses only core modules. PDL is optional; its performance
depends on the operation and workload.

[Documentation](docs/README.md) · [Examples](examples/README.md) ·
[API reference](lib/Ham/CW.pm) · [Contributing](CONTRIBUTING.md)

## Start here

From the repository root, try a conversion. No installation is needed:

```sh
perl -Ilib bin/ham-cw encode "CQ TEST"
perl -Ilib bin/ham-cw decode -- "-.-. --.- / - . ... -"
```

The first command prints `-.-. --.- / - . ... -`; the second prints `CQ TEST`.
Spaces separate letters. A `/` separates words. Use `--` before Morse that
starts with a dash.

To install from a checkout or extracted distribution:

```sh
perl Makefile.PL
make
make test
make install
```

Use the make program supplied with your Perl. Manual builds need
ExtUtils::MakeMaker 7.22 or later. For upgrades and a user-owned installation,
see [installation options](docs/installing.md).
After installation, use `ham-cw` directly.

## Make a practice recording

```sh
ham-cw wav --wpm 20 --effective-wpm 12 --output practice.wav "CQ TEST"
ham-cw receive --frequency 700 --wpm 20 --effective-wpm 12 practice.wav
```

Characters run at 20 words per minute, with gaps extended for 12 WPM practice.
The receiver uses the same tone and timing as explicit hints. Existing files
are protected; add `--overwrite` when you intend to replace one.

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

For a single task, use `ham-cw help COMMAND`: options are grouped by purpose,
with units and defaults beside each control. Start with tone and speed hints
before adjusting detection thresholds. The [recovery guide](docs/usage.md#when-you-need-help)
connects common errors and reception warnings to the next useful action.

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

The [task guide](docs/usage.md#library-recipes) covers files, samples, streaming,
custom events and error recovery. The [example catalog](examples/README.md)
provides runnable scenarios for every public method. For installed API help,
run `perldoc Ham::CW`; from a checkout, use `perldoc lib/Ham/CW.pm`.

## Know what to expect

The symbol repertoire follows ITU-R M.1677-1. Operational signals use explicit
tokens such as `<AR>`; quote them in the shell. See the
[symbol policy](docs/usage.md#symbol-policy) for accepted characters and tokens.

Audio reception is experimental. It can recover separate, frequency-spaced
CW tones, but interference, fading and uncertain timing can produce partial
or incorrect text. Always inspect warnings, even when text is present.
`--strict` returns a nonzero status for reception warnings while preserving
recovered text. See [reception limits](docs/usage.md#practical-limits) and the
[current verification record](docs/verification.md).

Ham::CW creates data and files. Playback, microphone recording and radio or
MIDI device control belong to the application using it.

## Explore the project

The [documentation index](docs/README.md) connects installation, recipes,
architecture, measurements and reference material by task.

For development, start with [contributing](CONTRIBUTING.md). For publication,
follow the [release procedure](docs/releasing.md). Report vulnerabilities through
[the private reporting process](SECURITY.md).

Security CI currently flags upstream Perl/File::Temp advisories and historical dependency ranges; applicability to Ham::CW remains under review ([details](docs/security-ci.md)).

Copyright © 2026 Giacomo Picchiarelli. Project code and original material use
[Artistic License 2.0](LICENSE). Third-party audio retains its CC0 or CC BY-SA
3.0 terms; see [NOTICE](NOTICE) and [recording licenses](corpus/real/LICENSES.md).
