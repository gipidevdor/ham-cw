# Executable examples

Run these commands from a source checkout or an extracted CPAN distribution:

```sh
perl -Ilib examples/run-all.pl --list
perl -Ilib examples/run-all.pl --backend perl
perl -Ilib examples/run-all.pl --backend auto
perl -Ilib examples/run-all.pl --backend pdl
perl -Ilib examples/run-all.pl --only reception-channels --backend pdl
```

PDL mode requires PDL >=2.081 installed for the same Perl. `auto` exercises
PDL when available and the Perl fallback otherwise. Explicit `pdl` selection
fails when unavailable. Numerical examples also accept a positional backend:

```sh
perl -Ilib examples/pcm-streams.pl perl
perl -Ilib examples/reception-channels.pl pdl
```

After installing Ham::CW, omit `-Ilib` to use the installed library. Keep the
examples directory and bundled corpus from the source distribution together.
The runner passes its library search paths to child processes; it does not
force a source-library path when the installed library is selected.

Each catalog example is independent, prints its result and exits nonzero if its
illustrated invariant fails. Generated files use temporary directories and
are removed automatically. Corpus examples read the bundled licensed audio;
see [recording attribution](../corpus/real/LICENSES.md). No example downloads
recordings, plays sound, opens a microphone or controls radio/MIDI hardware.

## Choose a path

| Example | Paths demonstrated | Backend argument |
| --- | --- | --- |
| [text-events.pl](text-events.pl) | ITU symbols, aliases, prosigns, Farnsworth events and incremental event decoding | None |
| [sample-streams.pl](sample-streams.pl) | Collected samples, streamed samples, progress, reset and independent iterators | perl / auto / pdl |
| [memory-files.pl](memory-files.pl) | WAV byte strings, borrowed handles, named paths and explicit replacement | perl / auto / pdl |
| [pcm-streams.pl](pcm-streams.pl) | PCM 8/16/24, callback and pull I/O, writer lifecycle and stereo selection | perl / auto / pdl |
| [reception-channels.pl](reception-channels.pl) | Known/estimated tone and speed, filtered multiple stations, silence and snapshots | perl / auto / pdl |
| [midi-paths.pl](midi-paths.pl) | Timed/sampled events to SMF bytes, handles and files, MIDI settings | None |
| [results.pl](results.pl) | Result construction, every accessor, independent copies and JSON | None |
| [failure-recovery.pl](failure-recovery.pl) | All library error families, failed replacement, recoverable validation and failed writers | perl / auto / pdl |
| [cli-paths.pl](cli-paths.pl) | All CLI commands, UTF-8 files/stdin, binary stdout, station JSON and exit codes | perl / auto / pdl |
| [corpus-reception.pl](corpus-reception.pl) | Redistributable off-air recordings, references, warnings and attribution | perl / auto / pdl |
| [workflows.pl](workflows.pl) | Existing compact tour of common end-to-end workflows | None |

The WAV examples cover byte strings, caller-owned handles and library-owned
paths; collected arrays, callback blocks and pull iterators; mono PCM
8/16/24-bit output; and left/right/mix stereo input. The stereo fixture is a
small, independently assembled 16-bit WAV because the public writer is mono.
Handle examples close their own handles and check close errors.

Reception examples distinguish a known tone/speed, automatic estimates,
explicit Farnsworth spacing, multiple frequency-separated stations, provisional
snapshots and empty/silent input. The mixed-station example deliberately uses
clean synthetic data. The corpus example prints both reference and received
text, including imperfect results and warnings; completion is not accuracy.

The failure example covers argument, symbol, timing, resource, format,
truncation, state and I/O errors, plus application-created structured errors.
A small portable sink simulates a failed PCM write, demonstrating why a FAILED
writer is discarded. Rejected validation/count operations instead allow recovery.
It also checks protection of existing output on failed replacement and shows
explicit PDL availability/selection failures.

The CLI example starts real child processes with structured argument lists,
keeps stdout/stderr separate, and uses file redirections to preserve binary
bytes without pipe-buffer deadlocks. It exercises all six commands, timed and
sampled JSON, UTF-8 input files/stdin, binary WAV/MIDI stdout, WAV stdin,
station-array JSON, help/version and exit statuses 0/1/2/3. For interactive
Windows shells, prefer named binary output files as described in
[the command manual](../bin/ham-cw).

## Public API index

[The machine-readable catalog](routes.json) maps every current public library
method and the four returned WAV-writer operations to executable scenarios.
The following table is a navigation index; the module POD remains the full
API reference for option ranges, defaults and errors.

| API | Methods/functions and example |
| --- | --- |
| Ham::CW | `new, encoder, decoder, encode, decode, events, sampled_events, decode_events` → [text-events.pl](text-events.pl); `generator, samples, stream_samples` → [sample-streams.pl](sample-streams.pl); `wav_bytes, decode_wav_bytes, generate_wav, decode_wav, write_wav, read_wav` → [memory-files.pl](memory-files.pl); `detector, decode_samples, decode_samples_channels, read_wav_channels, decode_wav_channels` → [reception-channels.pl](reception-channels.pl); `midi_bytes, generate_midi, write_midi` → [midi-paths.pl](midi-paths.pl) |
| Ham::CW::Encoder | `new, validate, encode, events` → [text-events.pl](text-events.pl) |
| Ham::CW::Decoder | `new, decode, feed, result, finish, reset, state` → [text-events.pl](text-events.pl) |
| Ham::CW::Events | `validate_events, to_samples, to_timed` → [text-events.pl](text-events.pl) |
| Ham::CW::Generator | `new, validate, generate, stream, result, state, reset` → [sample-streams.pl](sample-streams.pl) |
| Ham::CW::Audio | `new, read_file, write_file, read_blocks, write_blocks, reader, read, writer, write` → [pcm-streams.pl](pcm-streams.pl) |
| WAV writer | `feed, result, finish, state` → [pcm-streams.pl](pcm-streams.pl) |
| Ham::CW::Detector | `new, feed, result, finish, channels, state, reset` → [reception-channels.pl](reception-channels.pl) |
| Ham::CW::MIDI | `new, encode, write, write_file` → [midi-paths.pl](midi-paths.pl) |
| Ham::CW::Result | `new, text, morse, frequency, wpm, events, warnings, diagnostics, complete, has_text, has_warnings, as_hash` → [results.pl](results.pl) |
| Ham::CW::Error | `new, throw, code, message, context, as_string` → [failure-recovery.pl](failure-recovery.pl) |

Private implementation modules are reached through these supported public
interfaces. The catalog describes public workflows and representative success,
warning and failure paths; regression tests additionally exercise numerical
boundaries, malformed-file variations and platform-specific I/O behavior.

## Existing command-line tools

These tools accept user-selected output/input paths and messages:

```sh
perl -Ilib examples/send.pl --wpm 20 --frequency 650 practice.wav "CQ DE TESTCALL"
perl -Ilib examples/receive.pl --json practice.wav
perl -Ilib examples/receive.pl --all-stations --json practice.wav
perl -Ilib examples/midi.pl practice.mid "CQ DE TESTCALL"
```

Destinations must be new unless `--overwrite` is explicit. `--help` documents
these scripts. `workflows.pl` is retained as the original compact tour.

## Automated verification

`prove -lv t/27-examples.t` runs every catalog entry from a separate empty
working directory, checking both its exit status and completion output,
with warnings fatal, using `perl`, plus `pdl` and `auto` when compatible PDL
is installed. It verifies catalog completeness against
public methods and WAV-writer documentation. New public methods and unknown
catalog entries require the example index to be updated. The existing platform
CI runs this ordinary test on Linux, macOS and Windows, including minimum PDL.

The archive installation check runs the complete catalog again against the
installed library. See [contributing](../CONTRIBUTING.md) and the
[release procedure](../docs/releasing.md) for author checks, coverage, security
audits, benchmarks and corpus maintenance commands.
