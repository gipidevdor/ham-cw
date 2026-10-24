"""Rebuild the independent, synthetic reference WAV using Python's standard library."""
from pathlib import Path
import math
import struct
import wave

root = Path(__file__).resolve().parents[1]
rate = 8000
unit = 480
runs = [(False, 3), (True, 1), (False, 1), (True, 1), (False, 1),
        (True, 1), (False, 3), (True, 3), (False, 1), (True, 3),
        (False, 1), (True, 3), (False, 3), (True, 1), (False, 1),
        (True, 1), (False, 1), (True, 1), (False, 3)]
samples = []
for keyed, units in runs:
    for _ in range(units * unit):
        index = len(samples)
        value = 0.6 * math.sin(2 * math.pi * 650 * index / rate) if keyed else 0.0
        samples.append(round(value * 32767))
with wave.open(str(root / 'corpus' / 'sos-650hz-20wpm.wav'), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
