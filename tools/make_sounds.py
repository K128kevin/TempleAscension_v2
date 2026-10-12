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
                      silence before the blow and after it cut away, its
                      blow given more weight (brought up as it lands, its
                      peaks saturated, and the whole about 6 dB louder),
                      faded out at its end.
  arrow-flesh-1..3.wav  An arrow striking a bandit: the three hits of a
                      recording supplied by the user
                      (source_art/audio/arrow-hits.mp3), cut apart at the
                      silences between them, as recorded, each faded out
                      at its end.

And Orion's at his work in the smithy (scripts/smith.gd), synthesised (noise,
tones and filters; no recording), with a generator of their own so the
sounds above are made as they always were:

  smith-hammer-1..4.wav  His hammer striking the sword on the anvil: one
                      short dead clank (a hard crack, a dense cluster of
                      steel's partials damped within a few hundredths of a
                      second, the hammer's weight thudding into the anvil),
                      heard in the small stone room. Four blows, none quite
                      like another.
  smith-grind.wav     The blade's edge held to the turning grindstone: steel
                      hissing on wet sandstone, the grit crackling, the
                      blade singing faintly, the wheel rumbling round. It
                      loops (its end flows into its start; the wheel turns
                      a whole number of times in it).

  python3 tools/make_sounds.py          (all of them)
  python3 tools/make_sounds.py smith    (Orion's only)
"""
from pathlib import Path
import math
import subprocess
import sys
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
# Its weight: how much the blow is brought up as it lands (at BLADE_BLOW
# seconds into the cut, for about BLADE_BLOW_SPAN), how hard it is driven
# into saturation, and the peak it is set to (the recording's own is .72).
BLADE_BLOW = .14
BLADE_BLOW_SPAN = .06
BLADE_PUNCH = .8
BLADE_DRIVE = 1.9
BLADE_PEAK = .89


def blade_hit():
    start, end = BLADE_HIT
    hit = decoded(ROOT/'source_art/audio/bandit-sword-hit.mp3')[int(start*RATE):int(end*RATE)].copy()
    rise, fall = int(.003*RATE), int(BLADE_FADE*RATE)
    t = np.arange(len(hit))/RATE
    hit *= (1+BLADE_PUNCH*np.exp(-((t-BLADE_BLOW)/BLADE_BLOW_SPAN)**2))[:, None]
    hit = np.tanh(hit*BLADE_DRIVE)
    hit[:rise] *= np.linspace(0, 1, rise)[:, None]
    hit[-fall:] *= (np.cos(np.linspace(0, math.pi, fall))*.5+.5)[:, None]
    return hit/np.max(np.abs(hit))*BLADE_PEAK


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


# ---- Orion's smithy ----

smithy_rng = np.random.default_rng(4411)


def room(signal, decay=.16, mix=.13):
    """Heard in the smithy: a short tail of the small stone room's
    reflections, dense noise dying away, under the dry sound."""
    t = times(decay*5)
    tail = smithy_rng.standard_normal(len(t))*np.exp(-t/decay)
    tail = biquad(tail, 'low', 3800.0, .7)
    tail[:int(.006*RATE)] = 0
    wet = np.convolve(signal, tail)[:len(signal)]
    return signal+wet/np.max(np.abs(wet))*np.max(np.abs(signal))*mix


# A blow is heard as a clank, not a note: the blade lying on the anvil's face
# and the hammer's face on it damp each other at once, so what rings is a
# dense cluster of steel's inharmonic partials, none standing out as a pitch,
# all dying within a few hundredths of a second. CLANK_MODES partials spread
# over CLANK_SPAN (times `pitch`), each lasting about `ring` seconds.
CLANK_MODES = 28
CLANK_SPAN = (1.0, 7.5)


def hammer(pitch, ring, blow, brightness):
    """One stroke of the hammer on the blade, the blade on the anvil: a
    short dead clank. `pitch` the bottom of its metallic cluster (Hz),
    `ring` about how long its partials last (s), `blow` how hard the knock,
    `brightness` how loud its top end."""
    t = times(.32)
    n = len(t)
    clank = np.zeros(n)
    for _ in range(CLANK_MODES):
        ratio = math.exp(smithy_rng.uniform(math.log(CLANK_SPAN[0]), math.log(CLANK_SPAN[1])))
        f = pitch*ratio
        level = smithy_rng.uniform(.3, 1.0)*brightness**math.log2(ratio)
        decay = ring*smithy_rng.uniform(.4, 1.3)/ratio**.35
        clank += np.sin(2*math.pi*f*t+smithy_rng.uniform(0, 2*math.pi))*level*np.exp(-t/decay)
    clank /= np.max(np.abs(clank))
    noise = smithy_rng.standard_normal(n)
    # Steel struck on steel: a hard bright crack at the instant of the blow,
    # rough metallic noise under the clank, the hammer's weight thudding into
    # the anvil's mass, and the blade chattering on the face for an instant.
    crack = biquad(noise*np.exp(-t/.0025), 'high', 2200.0, .7)*1.4*blow
    grit = biquad(noise*np.exp(-t/(ring*.5)), 'band', pitch*3.0, .9)*.9
    thud = np.sin(2*math.pi*np.cumsum(110+90*np.exp(-t/.008))/RATE)*np.exp(-t/.022)*.8*blow
    chatter = biquad(noise*np.exp(-t/.018)*(1+np.sign(np.sin(2*math.pi*55*t)))*.5, 'band', 1400.0, 1.2)*.35*blow
    signal = clank*.65*blow+crack+grit+thud+chatter
    signal = room(signal, decay=.05, mix=.08)
    return finish(biquad(signal, 'low', 8500.0, .7), peak=.86, drive=1.3)


# The grindstone: how long the loop is, how often the wheel goes round in it
# (a whole number of times, so it loops), and the stretch its end is laid
# over its start with.
GRIND_LOOP = 6.0
GRIND_TURNS = 9
GRIND_SEAM = .5


def grind():
    t = times(GRIND_LOOP+GRIND_SEAM)
    n = len(t)
    turn = 2*math.pi*GRIND_TURNS/GRIND_LOOP*t
    noise = smithy_rng.standard_normal(n)
    # Steel hissing on the stone: two bands of noise, the stone not quite
    # round, so it bites harder once a turn.
    bite = 1+.18*np.sin(turn+.7)+.06*np.sin(2*turn+2.1)
    hiss = biquad(noise, 'band', 2700.0, .7)*1.0+biquad(noise, 'band', 5200.0, 1.1)*.4+biquad(noise, 'band', 1400.0, 1.2)*.35
    hiss = biquad(hiss, 'high', 700.0, .7)*bite
    # The grit: a crackle of tiny scrapes, thick and uneven.
    grains = np.zeros(n)
    for k in np.nonzero(smithy_rng.random(n) < 2600/RATE)[0]:
        grains[k] = smithy_rng.exponential(1.0)*smithy_rng.choice((-1, 1))
    grit = biquad(biquad(grains, 'band', 3400.0, 1.2), 'high', 1200.0, .7)*.6*bite
    # The blade singing faintly where the stone takes it.
    sing = (biquad(noise, 'band', 2650.0, 18.0)+biquad(noise, 'band', 4120.0, 22.0)*.7)*3.0*(1+.3*np.sin(turn))
    # The wheel's own rumble, and a soft knock of its axle each turn.
    rumble = biquad(biquad(smithy_rng.standard_normal(n), 'low', 140.0, .7), 'high', 45.0, .7)*2.2
    axle = np.zeros(n)
    for k in range(GRIND_TURNS+1):
        start = int(k*GRIND_LOOP/GRIND_TURNS*RATE)
        span = min(n-start, int(.06*RATE))
        if span > 0: axle[start:start+span] += np.sin(2*math.pi*95*np.arange(span)/RATE)*np.exp(-np.arange(span)/RATE/.02)
    signal = hiss*.6+grit+sing*.35+rumble*.5+axle*.25
    # (Steel on stone is harsh, but not a hiss of static: the top rolled off.)
    signal = biquad(biquad(signal, 'low', 7000.0, .7), 'low', 9000.0, .7)
    signal = room(signal, decay=.12, mix=.1)
    # (Seamless: its last GRIND_SEAM seconds laid over its first, crossfaded.)
    seam = int(GRIND_SEAM*RATE)
    loop = signal[:n-seam].copy()
    fade = np.linspace(0, 1, seam)
    loop[:seam] = loop[:seam]*np.sqrt(fade)+signal[n-seam:]*np.sqrt(1-fade)
    loop = np.tanh(loop/np.max(np.abs(loop))*1.1)
    return loop/np.max(np.abs(loop))*.8


# Four blows: [bottom of the clank, how long it lasts, knock, brightness].
HAMMER_BLOWS = [(700.0, .045, 1.0, .9), (780.0, .04, .85, .85), (640.0, .055, 1.1, .95), (840.0, .038, .9, .8)]


def smith_sounds():
    for i, blow in enumerate(HAMMER_BLOWS):
        write('smith-hammer-%d.wav' % (i+1), hammer(*blow))
    write('smith-grind.wav', grind())


if __name__ == '__main__' and sys.argv[1:] == ['smith']:
    smith_sounds()
    sys.exit()

if __name__ == '__main__':
    write('lightning-zap.wav', zap())
    write('power-whoosh.wav', whoosh())
    write('sword-hit-flesh.wav', blade_hit())
    for i, hit in enumerate(arrow_hits()):
        write('arrow-flesh-%d.wav' % (i+1), hit)
    smith_sounds()
