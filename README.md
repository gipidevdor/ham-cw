# Ham::CW

Morse text, timing, audio and MIDI tools in pure Perl.

`Ham::CW` keeps text decoding inside the distribution. It needs no audio
programs, native extensions, network connection or non-core runtime modules.
The distribution name is **Ham-CW**; the GitHub repository is **ham-cw**.

This is an initial development version. The symbolic codec and file formats
have explicit contracts and independent tests. Audio reception is experimental;
read the diagnostics before accepting a decoded message.

## A short example

```perl
use Ham::CW;

my $cw = Ham::CW->new(wpm => 20, frequency => 700);
print $cw->encode('CQ DE TESTCALL'), "\n";
print $cw->decode('... --- ...'), "\n";  # SOS

open my $wav, '>:raw', 'cq.wav' or die $!;
$cw->generate_wav('CQ DE TESTCALL', $wav);
close $wav or die $!;

open my $midi, '>:raw', 'cq.mid' or die $!;
$cw->generate_midi('CQ DE TESTCALL', $midi, note => 77, program => 80);
close $midi or die $!;

open my $input, '<:raw', 'cq.wav' or die $!;
my $result = $cw->decode_wav($input, frequency => 700, wpm => 20);
close $input or die $!;
print $result->text, "\n";
```

## Install and test

Perl 5.20 or later is declared. See [verification](docs/verification.md) for
actual interpreter and platform results.

```sh
perl Makefile.PL
make
make test
make install
```

For a source checkout, `prove -lr t` runs the ordinary tests without installing.
`perl -Ilib examples/send.pl cq.wav CQ DE TESTCALL` writes a recording;
`perl -Ilib examples/receive.pl cq.wav` attempts automatic reception.

## FAST with Perl Data Language

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

The FAST CI jobs install PDL and test Linux, macOS ARM/Intel and Windows
with Strawberry Perl. A legacy Linux job checks Perl 5.20 with PDL 2.081. PDL itself
contains native code; installation requires a compatible PDL build or a C
build toolchain. No operating-system-specific audio or external DSP command
is used. See [verification](docs/verification.md) for the actual run and platform results.

The expanded benchmark also compares reception in 4096-sample blocks and
in-memory PCM WAV reading/writing separately at 8, 16 and 24 bits:

```sh
perl maint/benchmark.pl --seconds 1 --json benchmark.json
```

The JSON records versions, architecture, timings and iteration counts. Every
FAST CI job saves it as an artifact. Ratios below 1 identify slower PDL cases;
benchmarks are observations and do not gate the compatibility tests.

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
