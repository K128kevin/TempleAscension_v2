"""Synthesises two of the ranger's sounds, written to assets/audio as 48 kHz
mono 16-bit WAV (no recordings: noise, tones and filters only).

  lightning-zap.wav   Lightning Shot striking: the falling "zzzt" of the
                      discharge, buzzing as the current pulses, over the
                      arc's hum, with a soft snap and a few muffled crackles.
  power-whoosh.wav    Power Shot striking: a quick rush of air that swells
                      into the blow and stops with it, and a deep punch.

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


def finish(signal, peak=.89, drive=1.4, level=None):
    """Saturated a little (for weight), faded at its ends, and set to `peak`
    (or scaled by `level`, a gain already settled on)."""
    signal = np.tanh(signal*drive)
    fade = int(.004*RATE)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade*4:] *= np.linspace(1, 0, fade*4)
    return signal*(level if level is not None else peak/np.max(np.abs(signal)))


def write(name, signal):
    data = (np.clip(signal, -1, 1)*32767).astype('<i2')
    with wave.open(str(ROOT/'assets/audio'/name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print('SOUND', name, '%.2f s' % (len(signal)/RATE))


def zap():
    t = times(.7)
    n = len(t)
    # (Its own noise, so the blow below keeps the noise it was first made of.)
    own = np.random.default_rng(2207)
    noise = own.standard_normal(n)
    # The discharge: a falling tone, "zzzt", from a bright whine down to a
    # low hum, buzzing as the current pulses through it.
    sweep = 120+780*np.exp(-t/.07)
    phase = 2*math.pi*np.cumsum(sweep)/RATE
    pulse = .6+.4*np.sin(2*math.pi*100*t)**2
    tone = (np.sin(phase)+.35*np.sin(2*phase)+.12*np.sin(3*phase))*pulse
    out = tone*np.exp(-t/.22)*.9
    # The arc's hum beneath it, wavering a little.
    hum_phase = 2*math.pi*np.cumsum(100+4*np.sin(2*math.pi*6*t))/RATE
    hum = (np.sin(hum_phase)+.3*np.sin(2*hum_phase))*np.exp(-t/.3)
    swell = np.convolve((own.random(n) < .002).astype(float)*own.uniform(.5, 1.0, n), np.ones(1400)/40, mode='same')
    out += hum*(.25+np.clip(swell, 0, .5))*.5
    # A soft snap as it strikes, and a few muffled crackles after.
    out += biquad(noise*np.exp(-t/.003), 'low', 3000.0, .7)*.9
    clicks = np.zeros(n)
    for k in np.nonzero(own.random(n) < 120/RATE*np.exp(-t/.2))[0]: clicks[k] = own.uniform(.4, 1.0)
    clicks = np.convolve(clicks, np.exp(-np.arange(240)/40.0))[:n]
    out += biquad(clicks*noise, 'low', 2400.0, .7)*.35
    # (Rolled well off above: a hum and a zap, not static.)
    return finish(biquad(out, 'low', 4500.0, .7), drive=.7)


def drawn_before():
    """The draws the first lightning sound made of the shared generator, made
    again (and thrown away), so the blow below keeps the noise it was first
    heard and kept with."""
    n = int(.8*RATE)
    t = times(.8)
    rng.standard_normal(n)
    rng.standard_normal(n)
    i = 0
    while i < n:
        span = int(rng.uniform(.003, .022)*RATE)
        if rng.random() >= .3: rng.uniform(.4, 1.0)
        i += span
    for k in np.nonzero(rng.random(n) < 900/RATE*np.exp(-t/.3))[0]:
        rng.uniform(.3, 1.0)
        rng.random()
    rng.standard_normal(n)


def whoosh():
    drawn_before()
    t = times(.62)
    n = len(t)
    # (The blow comes early: it is heard as the arrow strikes.)
    hit = .075
    noise = rng.standard_normal(n)
    # A rush of air whose pitch climbs as it swells into the blow, and falls
    # away after it.
    centre = np.where(t < hit, 260+1300*(t/hit)**1.6, 1560*np.exp(-(t-hit)/.1)+300)
    swell = np.where(t < hit, (t/hit)**2.4, np.exp(-(t-hit)/.09))
    # (It stops with the blow: no gust trails after it.)
    stop = np.where(t < hit, 1.0, np.exp(-(t-hit)/.008))
    air = biquad(noise, 'band', centre, .75)*swell*4.0
    # Its edge: a thin, bright swish just before the blow.
    edge = biquad(noise, 'band', centre*1.8+600, 1.4)*np.where(t < hit, (t/hit)**5, np.exp(-(t-hit)/.03))*.45
    # The punch: a low thud dropping in pitch, and a short crunch.
    after = np.clip(t-hit, 0, None)
    pitch = 38+70*np.exp(-after/.05)
    thud = np.sin(2*math.pi*np.cumsum(pitch)/RATE)*np.exp(-after/.16)*(t >= hit)*1.1
    crunch = biquad(noise*np.exp(-after/.012)*(t >= hit), 'low', 1300.0, .7)*1.8
    # (At the loudness the blow was first heard at, with its gust.)
    level = .89/np.max(np.abs(np.tanh(biquad(air+edge+thud+crunch, 'low', 4200.0, .7)*1.4)))
    return finish(biquad((air+edge)*stop+thud+crunch, 'low', 4200.0, .7), level=level)


if __name__ == '__main__':
    write('lightning-zap.wav', zap())
    write('power-whoosh.wav', whoosh())
