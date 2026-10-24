# Ham::CW

Morse text, timing, audio and MIDI tools in pure Perl.

`Ham::CW` keeps text decoding inside the distribution. It needs no audio
programs, native extensions, network connection or non-core runtime modules.
The distribution name is **Ham-CW**; the GitHub repository is **ham-cw**.

This is an initial development version. The symbolic codec and file formats
have explicit contracts and independent tests. Audio reception is experimental;
read the diagnostics before accepting a decoded message.

## Start here

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

The same operations are available through the Perl API:

```perl
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20);

print $cw->encode('CQ TEST'), "\n";
print $cw->decode('... --- ...'), "\n";  # SOS

$cw->write_wav('CQ TEST', 'cq.wav');
$cw->write_midi('CQ TEST', 'cq.mid');

my $result = $cw->read_wav('cq.wav');
print $result->text, "\n";
if ($result->has_warnings) {
    warn "$_->{code}: $_->{message}\n" for @{$result->warnings};
}
```

File methods open and close files for you. By default, an
existing output file raises `CW_E_IO` and is preserved. They do not play audio.
`write_wav` returns writer statistics; `write_midi` returns its byte count;
`read_wav` returns a `Ham::CW::Result`.

Use `overwrite => 1` with `write_wav` or `write_midi` to replace an existing
file. The examples accept `--overwrite`; failed generation preserves the old file.

## Common tasks

| Task | Call |
| --- | --- |
| Text to Morse | `$cw->encode('CQ TEST')` |
| Morse to text | `$cw->decode('... --- ...')` |
| Save audio | `$cw->write_wav('CQ TEST', 'cq.wav')` |
| Save MIDI | `$cw->write_midi('CQ TEST', 'cq.mid')` |
| Read audio | `$cw->read_wav('input.wav')` |
| Help reception with a known tone/speed | `$cw->read_wav('input.wav', frequency => 650, wpm => 20)` |
| Farnsworth practice | `Ham::CW->new(wpm => 20, effective_wpm => 12)` |

Constructor timing and tone configure **generation**. Reception estimates them
unless you supply hints to `read_wav`; a recording may come from another
sender. The backend preference applies to both operations. For Farnsworth
reception, also supply `effective_wpm` explicitly.

Use `$result->has_text` to check whether any text was decoded, and
`$result->has_warnings` to decide whether to inspect its warnings. Text can be
partial, and `complete` only means processing finished; neither certifies
correct reception. File/argument errors throw `Ham::CW::Error`, while uncertain
reception is described in result warnings. Unsupported text errors identify
the symbol and its one-based character position. `unknown => 'skip'` is an
explicit option for omitting unsupported symbols; the default rejects them.

For caller-managed handles and in-memory files, keep using `generate_wav`,
`generate_midi`, and `decode_wav`. The file methods accept the same operation
options and per-call generation overrides: for example `bits => 24` for WAV or `note => 77` for MIDI.

## Every workflow

The [task guide](docs/usage.md) covers all supported uses with examples:
text and prosigns, Farnsworth practice, events and conversions, sample arrays,
streaming, incremental reception, raw WAV processing, MIDI, binary data,
caller-owned handles, backends, resource limits, results and errors.

```perl
my $samples = $cw->samples('SOS', sample_rate => 8000);
my $decoded = $cw->decode_samples($samples, sample_rate => 8000, wpm => 20);
my $next = $cw->stream_samples('CQ TEST', block_size => 1024);
my $wav = $cw->wav_bytes('SOS');
my $result = $cw->decode_wav_bytes($wav);
my $events = $cw->sampled_events('SOS', sample_rate => 8000);
my $detector = $cw->detector(sample_rate => 8000);  # feed/result/finish/reset
```

Generation options can be overridden per call without changing the object.
Run `perl -Ilib examples/workflows.pl` for a complete tour with temporary files.
Sender, receiver and MIDI examples all support `--help` and named options.

## Install and test

Perl 5.20 or later is declared. See [verification](docs/verification.md) for
actual interpreter and platform results.

Building requires ExtUtils::MakeMaker 7.00 or later, which supports installation
paths containing spaces. CPAN clients install this configure prerequisite.
For a manual build with an older bundled MakeMaker, first run
`cpanm ExtUtils::MakeMaker`.

```sh
perl Makefile.PL
make
make test
make install
```

For a source checkout, `prove -lr t` runs the ordinary tests without installing.
`perl -Ilib examples/send.pl cq.wav CQ DE TESTCALL` writes a recording;
`perl -Ilib examples/receive.pl cq.wav` attempts automatic reception.

## Optional Perl Data Language backend

Install PDL (`cpanm PDL`), then select the backend once:

```perl
my $cw = Ham::CW->new(backend => 'pdl', wpm => 20, frequency => 700);
$cw->generate_wav('CQ DE TESTCALL', $wav_handle);
my $result = $cw->decode_wav($input_handle);
```

`backend => 'perl'` remains the default, with no non-core dependencies.
`'pdl'` requires PDL 2.081 or later and fails with `CW_E_ARGUMENT` when
unavailable. `'auto'` selects PDL when loadable and otherwise uses Perl.
Generator, Detector and Audio accept the same option independently;
`decode_wav` also accepts an override. Text, timing and MIDI share the existing
implementation. Public samples remain ordinary Perl array references.

PDL vectorizes the oscillator, ramps, PCM normalization and quantization.
Detection batches at most 128 frames and computes the equivalent spectral
power using cached sine/cosine projections in double precision. Fixed frame
grid, streaming limits, partial frames, lifecycle and diagnostics are retained.
Floating-point results can differ slightly; PCM samples extremely close to a
rounding boundary may differ by one integer unit. Benchmark your workload with
`perl maint/benchmark.pl`: short blocks and single-frequency reception can
spend more time converting arrays than they save in vector operations.

The PDL CI jobs test Linux, macOS ARM/Intel and Windows with Strawberry
Perl. A legacy Linux job checks Perl 5.20 with PDL 2.081. PDL itself
contains native code; installation requires a compatible PDL build or a C
build toolchain. No operating-system-specific audio or external DSP command
is used. Platform results must be confirmed by CI before claiming validation.

The benchmark also measures complete WAV generation/reception and cached
snapshot reads. Use `--rate`, `--block`, `--repeat`, `--iterations`,
`--known-frequency`, and `--json` to compare workloads; without PDL it measures
the Perl backend alone. For example:

```sh
perl maint/benchmark.pl --iterations 10 --json
perl maint/benchmark.pl --block 137 --known-frequency
perl -Ilib examples/receive.pl --frequency 650 --wpm 20 --json input.wav
```

The receiver example accepts `--effective-wpm`, `--stereo`, `--backend`, and
`--max-frames` too. JSON contains the complete result, including warnings;
exit status is 0 for nonempty decoded text and 1 for empty text.

The platform benchmark separately measures streaming reception and PCM WAV
reading/writing at 8, 16 and 24 bits. CI saves its environment and timing
results as artifacts:

```sh
perl maint/benchmark-platforms.pl --seconds 1 --json benchmark.json
```

Ratios below 1 identify slower PDL cases; compatibility tests do not impose
a speed threshold. See [verification](docs/verification.md) for dated results.

## Interfaces

| Module | Responsibility |
| --- | --- |
| `Ham::CW` | Text, event, WAV and MIDI convenience methods |
| `Ham::CW::Encoder` | International symbols, explicit prosigns, WPM and Farnsworth |
| `Ham::CW::Decoder` | Public text and incremental event decoder |
| `Ham::CW::Events` | Validated microsecond/sample conversion |
| `Ham::CW::Generator` | Deterministic sine oscillator and bounded sample iterator |
| `Ham::CW::Detector` | Incremental Goertzel analysis and reception diagnostics |
| `Ham::CW::Audio` | Bounded RIFF PCM reader and writer |
| `Ham::CW::MIDI` | Standard MIDI file type 0 export |
| `Ham::CW::Result` | Cumulative decoding snapshots with copied fields |
| `Ham::CW::Error` | Exceptions with stable machine-readable codes |

Run `perldoc Ham::CW` after installing, or `perldoc lib/Ham/CW.pm` in the
checkout. Each public module documents its options, limits and lifecycle.

Morse text uses spaces between characters and ` / ` between words. Operational
tokens use angle brackets: `AR` is two letters; `<AR>` is one signal. Some
signals share a waveform with punctuation, so reception cannot recover the
sender's original token choice. ASCII case is normalized; there is no implicit
Unicode transliteration. The symbol set follows ITU-R M.1677-1, with accented E
supported explicitly.

WAV input accepts unsigned 8-bit and signed 16/24-bit PCM, mono or stereo.
Stereo selection is explicit (`left`, `right`, or the default `mix`). Output
is mono. MIDI carries keyed notes and timing, not rendered sound; instrument
choice and envelopes depend on the synthesizer.

## Limits that matter

Reception targets one reasonably stable CW signal. It does not separate
simultaneous stations. The initial detector uses percentile-seeded adaptive
thresholds, a frequency grid and a fixed frame size. It is not yet a validated
receiver for arbitrary off-air recordings. Short or ambiguous signals produce
warnings or empty text.

Generation and I/O stream samples in bounded blocks. The detector retains
bounded frame statistics, and the event decoder retains bounded event history.
They reject streams that exceed their configured limits rather than grow
without a bound. This release does not claim unlimited-duration reception.

## Development

[Contributing](CONTRIBUTING.md) explains the quality checks.
[Architecture](docs/architecture.md) specifies event and streaming contracts.
[Dependency audit](docs/dependency-audit.md) records the reuse decisions.
[Release procedure](docs/releasing.md) lists the publication gates.
[Verification](docs/verification.md) records measured results and outstanding
checks. No CPAN Testers or coverage badge is claimed without evidence.

Copyright © 2026 Giacomo Picchiarelli. Licensed under the
[Artistic License 2.0](LICENSE).
