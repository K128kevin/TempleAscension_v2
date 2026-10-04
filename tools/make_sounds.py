"""Synthesises two of the ranger's sounds, written to assets/audio as 48 kHz
mono 16-bit WAV (no recordings: noise, tones and filters only).

  lightning-zap.wav   Lightning Shot striking: the snap of the discharge, the
                      stuttering buzz of the arc, and a sizzle of sparks that
                      crackles away; struck again twice as it settles.
  power-whoosh.wav    Power Shot striking: a quick, heavy rush of air that
                      swells into the blow, and a deep punch beneath it.

  python3 tools/make_sounds.py
"""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
rng = np.random.default_rng(1307)


def times(seconds):
    return np.arange(int(seconds*RATE))/RATE


def biquad(signal, kind, freq, q):
    """An RBJ biquad (low, high or band pass); `freq` may change sample by
    sample (an array), and the filter follows it."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), signal.shape)
    out = np.zeros_like(signal)
    x1 = x2 = y1 = y2 = 0.0
    coefficients = None
    for i in range(len(signal)):
        if coefficients is None or i % 16 == 0:
            w = 2*math.pi*min(freq[i], RATE*.45)/RATE
            alpha = math.sin(w)/(2*q)
            c = math.cos(w)
            if kind == 'low': b = ((1-c)/2, 1-c, (1-c)/2)
            elif kind == 'high': b = ((1+c)/2, -(1+c), (1+c)/2)
            else: b = (alpha, 0.0, -alpha)
            a0 = 1+alpha
            coefficients = (b[0]/a0, b[1]/a0, b[2]/a0, -2*c/a0, (1-alpha)/a0)
        b0, b1, b2, a1, a2 = coefficients
        x = signal[i]
        y = b0*x+b1*x1+b2*x2-a1*y1-a2*y2
        x2, x1, y2, y1 = x1, x, y1, y
        out[i] = y
    return out


def finish(signal, peak=.89):
    """Saturated a little (for weight), faded at its ends, and set to `peak`."""
    signal = np.tanh(signal*1.4)
    fade = int(.004*RATE)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade*4:] *= np.linspace(1, 0, fade*4)
    return signal/np.max(np.abs(signal))*peak


def write(name, signal):
    data = (np.clip(signal, -1, 1)*32767).astype('<i2')
    with wave.open(str(ROOT/'assets/audio'/name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print('SOUND', name, '%.2f s' % (len(signal)/RATE))


def zap():
    t = times(.8)
    n = len(t)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    # The discharge's snap, and two smaller strikes as the arc settles.
    for at, size in ((0.0, 1.0), (.065, .55), (.15, .35)):
        k = t >= at
        snap = noise*np.exp(-(t-at)/.0045)*k
        out += biquad(snap, 'high', 1800.0, .7)*2.2*size
    # The arc: a harsh, wavering buzz (square and saw near 100 Hz) that cuts
    # in and out in ragged bursts.
    wobble = 96+9*np.sin(2*math.pi*7.3*t)+rng.standard_normal(n).cumsum()*.002
    phase = 2*math.pi*np.cumsum(wobble)/RATE
    buzz = .6*np.sign(np.sin(phase))+.4*((phase/(2*math.pi)) % 1.0*2-1)
    buzz = biquad(buzz, 'band', 900.0, .5)+.35*buzz
    gate = np.zeros(n)
    i = 0
    while i < n:
        span = int(rng.uniform(.003, .022)*RATE)
        gate[i:i+span] = 0.0 if rng.random() < .3 else rng.uniform(.4, 1.0)
        i += span
    gate = np.convolve(gate, np.ones(48)/48, mode='same')
    out += buzz*gate*np.exp(-t/.2)*1.15
    # The sizzle: sparks of bright noise, thick at first and thinning out.
    sparks = np.zeros(n)
    for k in np.nonzero(rng.random(n) < 900/RATE*np.exp(-t/.3))[0]: sparks[k] = rng.uniform(.3, 1.0)*(1 if rng.random() < .5 else -1)
    tail = np.exp(-np.arange(int(.003*RATE))/(.0006*RATE))
    sparks = np.convolve(sparks, tail)[:n]*rng.standard_normal(n)
    out += biquad(sparks, 'band', 3400.0, .9)*1.4
    hiss = biquad(noise, 'band', 5500.0, .7)*np.exp(-t/.12)*.18
    out += hiss
    # (Rolled off above, so it crackles rather than hisses.)
    return finish(biquad(out, 'low', 8000.0, .7))


def whoosh():
    t = times(.62)
    n = len(t)
    # (The blow comes early: it is heard as the arrow strikes.)
    hit = .075
    noise = rng.standard_normal(n)
    # A rush of air whose pitch climbs as it swells into the blow, and falls
    # away after it.
    centre = np.where(t < hit, 260+1300*(t/hit)**1.6, 1560*np.exp(-(t-hit)/.1)+300)
    swell = np.where(t < hit, (t/hit)**2.4, np.exp(-(t-hit)/.09))
    air = biquad(noise, 'band', centre, .75)*swell*4.0
    # Its edge: a thin, bright swish just before the blow.
    edge = biquad(noise, 'band', centre*1.8+600, 1.4)*np.where(t < hit, (t/hit)**5, np.exp(-(t-hit)/.03))*.45
    # The punch: a low thud dropping in pitch, and a short crunch.
    after = np.clip(t-hit, 0, None)
    pitch = 38+70*np.exp(-after/.05)
    thud = np.sin(2*math.pi*np.cumsum(pitch)/RATE)*np.exp(-after/.16)*(t >= hit)*1.1
    crunch = biquad(noise*np.exp(-after/.012)*(t >= hit), 'low', 1300.0, .7)*1.8
    return finish(biquad(air+edge+thud+crunch, 'low', 4200.0, .7))


if __name__ == '__main__':
    write('lightning-zap.wav', zap())
    write('power-whoosh.wav', whoosh())
