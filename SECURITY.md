# Reporting a security issue

For a suspected vulnerability involving untrusted WAV/MIDI/event input,
use the repository's private vulnerability reporting form:

https://github.com/gpicchiarelli/ham-cw/security/advisories/new

Include the affected version, a minimal input or reproduction and the
observed impact. Avoid attaching private radio traffic or credentials.
Use public issues for ordinary correctness and DSP limitations.

The library processes local input and has no runtime networking. File-size,
frame and event limits are part of its defensive boundary. Only the current
development version receives fixes; no response-time guarantee is offered.
