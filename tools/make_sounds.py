"""Makes the ranger's sounds, written to assets/audio as 48 kHz 16-bit WAV.

  lightning-zap.wav   Lightning Shot striking: ZapSplat's electric crackle
                      (source_art/audio/electric.m4a, supplied by the user),
                      decoded with macOS afconvert, brought up to the other
                      effects' level and faded out over its last stretch
                      rather than stopping short.
  power-whoosh.wav    Power Shot striking (synthesised: noise, tones and
                      filters only): a quick rush of air that swells into the
                      blow and stops with it, and a deep punch.
  sword-hit-flesh.wav A blade striking a bandit: a recording supplied by the
                      user (source_art/audio/bandit-sword-hit.mp3), its
                      silence before the blow and after it cut away, faded
                      out at its end.
  arrow-flesh-1..3.wav  An arrow striking a bandit: the three hits of a
                      recording supplied by the user
                      (source_art/audio/arrow-hits.mp3), cut apart at the
                      silences between them, as recorded, each faded out
                      at its end.

  python3 tools/make_sounds.py
"""
from pathlib import Path
import math
import subprocess
import tempfile
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
    """`signal` is mono, or (samples, channels)."""
    data = (np.clip(signal, -1, 1)*32767).astype('<i2')
    with wave.open(str(ROOT/'assets/audio'/name), 'wb') as w:
        w.setnchannels(1 if signal.ndim == 1 else signal.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print('SOUND', name, '%.2f s' % (len(signal)/RATE))


# How long Lightning Shot's crackle takes to fade away at its end.
ZAP_FADE = .6


def zap():
    """ZapSplat's crackle, decoded, levelled and faded out at its end."""
    signal = decoded(ROOT/'source_art/audio/electric.m4a').copy()
    fade = int(ZAP_FADE*RATE)
    # (An eased fall, gentle at first, so it dies away rather than dips.)
    signal[-fade:] *= (np.cos(np.linspace(0, math.pi, fade))*.5+.5)[:, None]
    return signal/np.max(np.abs(signal))*.89


# Where each of the recording's three arrow hits begins and ends (seconds):
# just before each strikes, and in the quiet after it.
ARROW_HITS = [(.044, .275), (.296, .655), (.676, .96)]


def decoded(path):
    """A recording decoded by macOS afconvert, as (samples, channels)."""
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder)/'decoded.wav'
        subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@48000', str(path), str(out)], check=True)
        with wave.open(str(out)) as w:
            channels = w.getnchannels()
            return np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, channels)/32767


def arrow_hits():
    recording = decoded(ROOT/'source_art/audio/arrow-hits.mp3')
    hits = []
    for start, end in ARROW_HITS:
        hit = recording[int(start*RATE):int(end*RATE)].copy()
        rise, fall = int(.002*RATE), int(.02*RATE)
        hit[:rise] *= np.linspace(0, 1, rise)[:, None]
        hit[-fall:] *= np.linspace(1, 0, fall)[:, None]
        hits.append(hit)
    return hits


# Where the blade's hit begins (its slash, just before the blow lands) and
# where its ring has died away, in seconds, and how long it fades out over.
BLADE_HIT = (.135, .7)
BLADE_FADE = .08


def blade_hit():
    start, end = BLADE_HIT
    hit = decoded(ROOT/'source_art/audio/bandit-sword-hit.mp3')[int(start*RATE):int(end*RATE)].copy()
    rise, fall = int(.003*RATE), int(BLADE_FADE*RATE)
    hit[:rise] *= np.linspace(0, 1, rise)[:, None]
    hit[-fall:] *= (np.cos(np.linspace(0, math.pi, fall))*.5+.5)[:, None]
    return hit


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
    write('sword-hit-flesh.wav', blade_hit())
    for i, hit in enumerate(arrow_hits()):
        write('arrow-flesh-%d.wav' % (i+1), hit)
