# Ham::CW

Morse text, keying events, WAV audio and MIDI files for Perl.

Ham::CW generates Morse and decodes notation, event timing and suitable audio.
The default backend uses only core Perl modules. An optional PDL backend
accelerates numerical work. The library creates data and files; it does not
play audio, record a microphone, operate a radio or send MIDI to a device.
Audio reception is experimental and targets one reasonably stable CW tone.

## Installed command

Installing the distribution also installs the `ham-cw` command on Linux,
macOS and Windows (including a Windows `.bat` launcher):

```sh
ham-cw encode "CQ TEST"
ham-cw decode "... --- ..."
ham-cw events --sample-rate 8000 "SOS"
ham-cw wav --wpm 20 --output cq.wav "CQ TEST"
ham-cw midi --output cq.mid "CQ TEST"
ham-cw receive --json cq.wav
ham-cw help receive
```

`--input FILE` reads UTF-8 text from a file; omitting text reads stdin.
`--output FILE` writes a file and protects existing contents. Use `--overwrite`
for explicit replacement. Binary stdout requires `--output -`; diagnostics
use stderr. For Windows shell portability, prefer named binary output files.
`--strict` makes reception warnings return a nonzero status even with text.
Run `ham-cw --help` or `perldoc ham-cw` for options, limits and exit statuses.
From an uninstalled checkout, use `perl -Ilib bin/ham-cw` instead of `ham-cw`.

## Requirements and installation

You need Perl 5.20 or later. From an extracted distribution or repository root:

Building requires ExtUtils::MakeMaker 7.22 or later, which avoids the older
build-tool search-path issue and supports installation paths containing spaces.
CPAN clients install this configure prerequisite.
For a manual build with an older bundled MakeMaker, first run
`cpanm ExtUtils::MakeMaker`.

```sh
perl Makefile.PL
make
make test
make install
```

Use the make program supplied with your Perl installation (`gmake` on some
Windows installations). The final command needs write permission to Perl's
library directory. For a user-owned destination, configure with
`perl Makefile.PL INSTALL_BASE=/your/install/directory` and include its
`lib/perl5` directory in `PERL5LIB` when running applications.

To use a checkout without installing, run scripts from the repository root
with `perl -Ilib script.pl`. The CPAN distribution name is `Ham-CW`, the Perl
package is `Ham::CW`, and this repository is named `ham-cw`.

## First example

Save this as `demo.pl`. Run `perl -Ilib demo.pl` from the checkout root,
or `perl demo.pl` after installation. It creates no files.

```perl
use 5.020;
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20, frequency => 700);
print $cw->encode('SOS'), "\n";             # ... --- ...
print $cw->decode('... --- ...'), "\n";      # SOS

my $bytes = $cw->wav_bytes('SOS');
my $result = $cw->decode_wav_bytes($bytes, frequency => 700, wpm => 20);
print $result->text, "\n";                  # SOS
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
```

Text is a Perl character string. Morse notation uses dots/dashes, spaces
between letters and `/` between words. WAV/MIDI bytes are binary scalars;
sample arrays are normalized mono numbers from -1 to 1. An event sequence
instead describes alternating ON/OFF durations. The [task guide](docs/usage.md)
explains these representations with complete examples.

## Save and receive files

```perl
use strict;
use warnings;
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20, frequency => 700);
$cw->write_wav('CQ TEST', 'cw-demo.wav');
$cw->write_midi('CQ TEST', 'cw-demo.mid');
my $result = $cw->read_wav('cw-demo.wav', frequency => 700, wpm => 20);
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
```

The path methods open and close their files. Parent directories must exist.
Existing output files are protected: rerunning this example raises `CW_E_IO`.
To replace these files deliberately, add `overwrite => 1` to each writing
call. Replacement is prepared in a temporary sibling and renamed only after
successful generation and close. Existing regular-file permission bits are
preserved; detected symbolic-link destinations are rejected during preparation.
Inspection and rename are separate operations, so this is not an atomic
no-symlink guarantee against concurrent directory changes. Replacement creates a
new file identity. A processing failure preserves the old
contents and attempts temporary-file cleanup.

`write_wav` returns a statistics hash containing `state` and `samples`;
`write_midi` returns its byte count. `read_wav` returns a `Ham::CW::Result`.
MIDI stores notes and timing; a separate player/synthesizer determines sound.

## Symbol policy

The repertoire is strictly [ITU-R M.1677-1](https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en),
Annex 1, Part I, sections 1.1.1–1.1.3: its letters, digits, written signs and
named operational signals.
No amateur-radio or extended Morse alphabet is enabled. `!`, `&`, `;`, `_`
and `$` are rejected. The accepted operational tokens are `<AR>`, `<AS>`,
`<BT>`, `<CT>`, `<HH>`, `<SK>` and `<SN>`; these are library mnemonics for the
ITU signals. `<BK>`, `<KN>`, `<KA>`, `<VE>` and `<SOS>` are not accepted.
`SOS` remains valid as three letters. `×` is encoded as X and decodes as X.
See [Encoder POD](lib/Ham/CW/Encoder.pm) for the complete table and rules.

## Speed, spacing and reception

WPM means words per minute on a 50-unit reference scale. A dot lasts `1.2 / wpm`
seconds; actual message duration depends on its characters. Farnsworth practice
uses faster characters and longer gaps, for example `wpm => 20,
effective_wpm => 12`.

Constructor speed, spacing and tone configure **generation**. Supply known
`frequency`, `wpm` and Farnsworth `effective_wpm` on receiving calls separately.
WAV input supplies its own sample rate; raw sample input requires the actual
rate. Audio reception accepts explicit 1–60 WPM and estimates within 5–60 WPM.
The encoder and event decoder accept explicit speeds up to 200 WPM.

A nonempty `text` value can still be wrong, partial or contain replacement
characters. `has_text` checks presence only; `complete` means finalization.
Inspect `warnings` even when both are true. Argument, file, state and resource
failures throw `Ham::CW::Error`; uncertain reception produces Result warnings.
The [Result reference](lib/Ham/CW/Result.pm) explains every warning and diagnostic.

## Choose an interface

| Task | Interface | Reference |
| --- | --- | --- |
| Ordinary text, samples and files | `Ham::CW` convenience methods | [POD](lib/Ham/CW.pm) |
| Text symbols and Farnsworth events | `Ham::CW::Encoder` | [POD](lib/Ham/CW/Encoder.pm) |
| Strict notation or incremental events | `Ham::CW::Decoder` | [POD](lib/Ham/CW/Decoder.pm) |
| Event validation and unit conversion | `Ham::CW::Events` | [POD](lib/Ham/CW/Events.pm) |
| Tone generation from custom events | `Ham::CW::Generator` | [POD](lib/Ham/CW/Generator.pm) |
| Incremental sample reception | `Ham::CW::Detector` | [POD](lib/Ham/CW/Detector.pm) |
| Raw PCM WAV without Morse decoding | `Ham::CW::Audio` | [POD](lib/Ham/CW/Audio.pm) |
| MIDI export from custom events | `Ham::CW::MIDI` | [POD](lib/Ham/CW/MIDI.pm) |
| Snapshots and exceptions | `Ham::CW::Result`, `Ham::CW::Error` | [Results](lib/Ham/CW/Result.pm), [errors](lib/Ham/CW/Error.pm) |

The API reference is POD, Perl's documentation format, embedded in each public
module and installed with it. Read it using `perldoc Ham::CW` after installation,
or `perldoc lib/Ham/CW.pm` from the checkout. Use the corresponding module name
or file path for other references. Each public method has its own section.

## Command-line examples

Run these from the checkout root. The sender creates `cw-example.wav`; the
receiver reads that same file. `--overwrite` explicitly permits repeated runs.

```sh
perl -Ilib examples/send.pl --overwrite --wpm 20 --frequency 650 cw-example.wav 'CQ TEST'
perl -Ilib examples/receive.pl --frequency 650 --wpm 20 --json cw-example.wav
perl -Ilib examples/midi.pl --overwrite cw-example.mid 'CQ TEST'
perl -Ilib examples/workflows.pl
```

Sender, receiver and MIDI scripts support `--help`. Quote prosigns such as
`'CQ <AR>'` so the shell does not interpret angle brackets. The receiver exits
0 for nonempty text and 1 for empty text; errors can terminate with another
nonzero status. Its JSON includes the full Result and warnings. The workflow
tour uses temporary files and removes them automatically.

## Optional PDL backend

Install PDL 2.081 or later into the Perl environment running your application,
then select `backend => 'pdl'` in the constructor or supported operation.
`backend => 'perl'` is the default. `backend => 'auto'` selects PDL when loadable,
otherwise Perl; it does not benchmark the workload. PDL needs a compatible
native build and can be slower for small blocks or a single known tone.

Both backends use the same public arrays and file/event formats. Floating-point
values can differ slightly, including one PCM unit near a rounding boundary.
Use `perl maint/benchmark.pl --help` and `perl maint/benchmark-platforms.pl --help`
for workload measurements. [Verification](docs/verification.md) separates
current local and platform checks from historical benchmark observations.

## Practical limits

WAV input supports mono/stereo PCM 8/16/24-bit; output is mono. Stereo `mix`
averages channels and may cancel opposite-phase audio; `left` or `right` selects
one. Compressed, float, extensible WAV and unknown-length streaming headers
are unsupported. MIDI output is standard file type 0.

Generation defaults to 10,000,000 total samples. Audio detection defaults to
24,000 retained frames, approximately 120 seconds including silence; event
decoding defaults to 100,000 retained runs. Increase the corresponding
`max_samples`, `max_frames` or `max_segments` explicitly when appropriate.
Streaming reduces block-buffer size but does not remove these history limits.
Every option's range and applicable method are specified in the POD.

Reception uses independent cascaded biquad band-pass channels, Hann windows,
and a Goertzel bank (equivalent projections with PDL). A raw spectral guard
rejects weakly distinguished noise before envelope timing. Distinct overlapping
CW tones can be decoded separately: `read_wav_channels`, `decode_wav_channels`
and `decode_samples_channels` return up to eight Results, each with frequency,
text and warnings. The ordinary methods return the strongest accepted channel.
From the command line:

```sh
ham-cw receive --all-stations --json received.wav
```

A WPM hint applies to every station; omit it for independent estimates. A
frequency hint selects only that tone. The tests recover two simultaneous
messages at 150 Hz separation with 20 WPM hints and at 250 Hz separation with
independent 20/25 WPM estimates, with unequal levels and added noise. A stronger
continuous carrier is also tested. This does not establish arbitrary field
accuracy: co-channel stations cannot be separated; fading, interference, short
messages and unknown spacing can still produce wrong, partial or empty text.
Review each Result's warnings. For current hinted and unassisted CER, run
`perl maint/reception-corpus.pl`; the historical figures in
[verification](docs/verification.md) predate the corrected corpus crops.

The default candidate spacing is 50 Hz. Synthetic reception tests allow tone
error within one configured grid step, an empirical tolerance rather than a
universal accuracy bound. Analysis uses approximately 20 ms Hann windows with
5 ms hops, preceded by two biquads per candidate. The window alone has about
70 Hz full half-power width. `filter_bandwidth` sets each biquad's width;
`min_snr_db` sets an acquisition tone/guard threshold, not calibrated radio SNR.
Candidate spacing, filter width and station resolving ability are distinct.
See the [Detector POD](lib/Ham/CW/Detector.pm) for defaults, latency, memory,
station selection, margin suppression and preview limitations.

## Development and license

See [contributing](CONTRIBUTING.md), [architecture](docs/architecture.md),
[dependency decisions](docs/dependency-audit.md), [reference corpus](corpus/README.md)
and [release procedure](docs/releasing.md) and [security reporting](SECURITY.md).

Project code and original material: copyright © 2026 Giacomo Picchiarelli,
[Artistic License 2.0](LICENSE). Third-party audio retains its CC0 or CC BY-SA
3.0 terms; see [NOTICE](NOTICE) and [recording licenses](corpus/real/LICENSES.md).
