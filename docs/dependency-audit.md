# Dependency and namespace audit

Checked on 2026-10-24. Exact release metadata and declared dependencies for the initial text/audio
candidates are preserved in [cpan-audit.json](cpan-audit.json). The metadata comes from the
[MetaCPAN API](https://fastapi.metacpan.org/). Release age alone is not evidence
of a defect. Third-party test suites were inspected where listed in the JSON,
but were not executed; their coverage and platform results are not independently
certified here.

| Candidate | Observed release | License / minimum Perl | Decision |
| --- | --- | --- | --- |
| [Text::Morse](https://metacpan.org/pod/Text::Morse) | 0.07, 2015-06-10 | Artistic 2.0; 5.6.1 | No runtime dependency. Its text mapping is useful prior art, but canonical events, strict symbol policy, explicit prosigns and incremental decoding require a different contract. The small internal codec is tested against independent vectors. |
| [Audio::Wav](https://metacpan.org/pod/Audio::Wav) | 0.14, 2014-04-27 | License/minimum Perl not declared in release metadata | No runtime dependency. It provides broader WAV handling and optional accelerated paths. The current bounded PCM subset needs strict RIFF accounting, structured errors and validation before allocation. Reuse would still require auditing those contracts. |
| [Audio::Data](https://metacpan.org/pod/Audio::Data) | Audio 1.029, 2004-06-02 | Metadata license/minimum unknown | Not selected. Its sample storage uses XS, and related playback builds inspect native audio systems. It conflicts with a pure-Perl reference implementation. |
| [PDL](https://metacpan.org/pod/PDL) | 2.106, 2026-08-18 | Perl terms; 5.16 | Optional acceleration backend, selected explicitly with `backend => pdl` or via `auto`. The default Perl backend needs no native dependencies. See `maint/benchmark.pl` for local measurements. |
| [Math::FFT](https://metacpan.org/pod/Math::FFT) | 1.36, 2020-10-17 | Perl terms; 5.8 | Not selected. FFT/XS is unnecessary for the initial narrow-band candidate bank. No speed advantage is claimed without measurement. |
| [MIDI](https://metacpan.org/pod/MIDI) | MIDI-Perl 0.84, 2023-10-17 | Perl terms in POD; release metadata license/minimum Perl/dependencies not specified | No runtime dependency. This release only exports a bounded type-0 track with tempo, program and note events; the small encoder preserves the project event-rounding/error contracts. General MIDI editing, import and device I/O remain outside its scope. Candidate tests, transitive dependencies and portability were not independently verified. |

Text::Morse declares Test::Simple/Test::More as runtime requirements. Audio::Wav
has no declared non-core runtime dependency in the queried release metadata;
this does not prove the absence of undeclared ones. Audio's sparse metadata is
insufficient to resolve its dependency tree. Math::FFT declares DynaLoader
and core modules; its distribution includes native code. PDL's declared tree
includes File::Map and supporting parsing/configuration modules; optional
Inline/Inline::C and device/scientific facilities are not Ham-CW requirements.
The JSON lists direct relationships by phase. Full transitive installations,
license audits and platform builds of these candidates were not performed.

Portability assessment is limited to these build/dependency observations.
None of the rejected candidates is represented as broken or unmaintained on
the strength of its release date. No third-party implementation source was
copied into Ham-CW. The standard Artistic 2.0 license text is reproduced
verbatim, as permitted by that license.

## Names

The public CPAN package index `02packages.details.txt.gz` and public PAUSE
permissions snapshot `06perms.txt.gz` contained no `Ham::CW` or `Ham::CW::*`
entries at the time of the check. `https://fastapi.metacpan.org/v1/module/Ham::CW`
returned 404. The GitHub endpoint for `gipidevdor/ham-cw` returned 404 before
repository creation. GitHub names are owner-scoped, not globally reserved.

These checks are a dated snapshot, not a reservation or a PAUSE upload test.
Recheck index and permissions immediately before the first CPAN upload.
The additional exporter uses `Ham::CW::MIDI` within the same checked prefix.

## Runtime footprint

Only core modules are required: Carp, Exporter, Hash::Util, Scalar::Util and
Storable, plus strict/warnings and Perl itself. Test::More and
JSON::PP are test requirements. ExtUtils::MakeMaker builds the distribution.
Perl::Critic, Perl::Tidy, Devel::Cover and metadata/POD checkers are author-only.
The default backend requires no Text::Morse, MIDI, Audio::Wav, PDL, compiler
or external player. The optional FAST backend requires PDL 2.081 or later,
which is declared as a runtime recommendation in the CPAN metadata. PDL 2.106
and its required dependencies were built locally for the FAST verification;
this does not extend the audit to PDL's optional scientific or device modules.
