# Real radio recordings: sources, licenses and preparation

These recordings are separate third-party corpus material. Their audio licenses
below apply to the WAV derivatives; the library's Artistic License does not
replace those terms. Sources and licenses were checked on 2026-10-24 using each
Commons file's own metadata, not the site's general page license.

| Derivative | Author | Source | Audio license |
| --- | --- | --- | --- |
| `4u1un.wav` | Cqdx | [4U1UN beacon](https://commons.wikimedia.org/wiki/File:4U1UN_beacon.ogg) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `oh2b.wav` | Cqdx | [NCDXF beacons](https://commons.wikimedia.org/wiki/File:NCDXF_beacons.ogg) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `cs3b.wav` | Cqdx | [NCDXF beacons](https://commons.wikimedia.org/wiki/File:NCDXF_beacons.ogg) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `sk6rud.wav` | HBD20 | [SK6RUD](https://commons.wikimedia.org/wiki/File:SK6RUD.ogg) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |

SK6RUD's derivative remains CC BY-SA 3.0: retain attribution, the license link
and the indication of changes when redistributing it; adaptations of that audio
are subject to the same license. All authors are credited above even where CC0
does not require attribution. The source descriptions identify received beacon
signals; these are not recordings of this project's oscillator.

The original uploader credits each source as their own work. The checked
source-page revisions and exact license metadata are retained in
[license-evidence.json](license-evidence.json). Original media SHA-1 values
were compared with the downloaded source files; derivative SHA-256 values
are checked in the suite. The source pages do not list additional restrictions.

Full legal texts are included as [CC0-1.0.txt](CC0-1.0.txt) and
[CC-BY-SA-3.0.txt](CC-BY-SA-3.0.txt). Keep this attribution notice, the per-file
metadata, source links, change descriptions and applicable audio license when
redistributing the corpus. [NOTICE](../../NOTICE) identifies the exceptions
to the project's code license.

Preparation decoded Ogg/Vorbis, averaged channels, resampled to 8000 Hz with
`scipy.signal.resample_poly`, cropped the stated intervals, and stored signed
16-bit mono PCM. No denoising or gain adjustment was applied. Python soundfile
and SciPy were preparation tools only; running the tests needs neither.
`../real.json` records the source URLs, source/derivative SHA-256 hashes,
intervals, transformations and transcript references.

The 4U1UN crop contains its identification before the calibration carriers.
NCDXF is split into the first and second 10-second beacon intervals, preserving
noise and long calibration carriers. Their text references are OH2B and CS3B,
in source-description order. SK6RUD retains the first seven seconds. References
identify the keyed callsigns, excluding continuous calibration tones; their
source is the recording descriptions, not output from Ham::CW. This corpus is
small, uses automated beacon keying and does not establish manual-keying or
conversational-QSO accuracy.

All evaluations currently use an explicit 20 WPM decoding hint. That parameter
is a fixed evaluation setting, not a claim that all recordings were transmitted
at exactly 20 WPM. Tone selection remains automatic. CER is Levenshtein edit
distance divided by reference character count, with insertions, deletions,
substitutions and emitted spaces/replacement characters counted. It may exceed
100% when many extra characters are emitted. There is no transcript normalization.

`max_regression_cer` preserves the observed error budget; it is not a quality
target. `quality_target_cer` is separately set to 0.25. The initial observations
are 0% (4U1UN), 300% (OH2B), 125% (CS3B) and 83.3% (SK6RUD): three cases fail
that quality target. Passing the regression suite does not make these results
acceptable reception. Use `perl maint/reception-corpus.pl` for current JSON
measurements and warnings. These known failures expose the receiver's limits
rather than certifying it for off-air use.
