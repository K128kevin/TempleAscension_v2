"""Makes the wizard's spell sounds, written to assets/audio as 48 kHz 16-bit
WAV. All but the fireball's are synthesised (noise, tones and filters
only), with tools/make_sounds.py's helpers.

  fireball-cast.wav   Fireball leaving the staff (and Fire Tornado rising,
                      Blazing Speed): the original game's fire whoosh
                      (fire-whoosh.mp3), its silence before it cut away so
                      it swells the moment it is cast.
  fireball-burst.wav  Fireball striking: that roar struck at its loudest and
                      cut short, with a low thump.
  fire-blast.wav      Blast Wave: a deep whoomph of flame rushing outward.
  fire-tornado.wav    Fire Tornado, looped while it burns: whooshing flames
                      swirling round, a rumble under them, crackling.
  thunder-strike.wav  Lightning Rod's bolt from the sky: a splitting crack
                      (struck again twice, as the bolt is drawn:
                      scripts/wizard_fx.gd SkyStrike), a boom, and thunder
                      rolling away.
  frost-bolt.wav      Ice Bolt cast: an icy rush, frost crackling off it.
  ice-impact.wav      Ice Bolt striking: ice cracking and shattering (no
                      chiming: its shards are bursts of noise, not tones).
  ice-spikes.wav      Ice Spikes: ice grinding up out of the floor and
                      splintering apart.
  ice-prison.wav      Ice Prison: ice creaking shut round its prisoner, a
                      solid clunk as it sets and the ice cracking through.
  frost-stream.wav    Freeze Floor and Frost Blast, looped while channelled:
                      a hissing spray of frost.
  ice-storm.wav       Ice Storm, looped while it lasts: a howling wind full
                      of tinkling ice.
  teleport.wav        The wizard's teleport: a quick rush of air drawn in as
                      he goes, and a soft whump of air as he arrives.
  ignition-burst.wav  Ignition going off: a quick, bursting pop of flame, a
                      sharp crack and a punch, over in a third of a second.

The loops (fire-tornado, frost-stream, ice-storm) are made circular (every
filter and swell repeats exactly over their length), so they loop without a
seam; their .import files loop them (edit/loop_mode=2).

  python3 tools/make_spell_sounds.py
"""
import math
import numpy as np
from make_sounds import RATE, ROOT, times, finish, write, decoded

rng = np.random.default_rng(5150)


def band(signal, low, high, soft=.25):
    """`signal` kept between `low` and `high` Hz (edges eased over `soft` of
    an octave), filtered circularly in the frequency domain: a loop stays a
    loop."""
    spectrum = np.fft.rfft(signal)
    freq = np.fft.rfftfreq(len(signal), 1/RATE)
    octave = np.log2(np.maximum(freq, 1.0))
    gain = np.ones_like(freq)
    if low > 0: gain *= np.clip((octave-math.log2(low))/soft+.5, 0, 1)
    if high < RATE/2: gain *= np.clip((math.log2(high)-octave)/soft+.5, 0, 1)
    return np.fft.irfft(spectrum*gain, len(signal))


def tilt(signal, slope):
    """Each octave up `slope` dB quieter (pink-ish for 3)."""
    spectrum = np.fft.rfft(signal)
    freq = np.maximum(np.fft.rfftfreq(len(signal), 1/RATE), 20.0)
    return np.fft.irfft(spectrum*(freq/20.0)**(-slope/6.02), len(signal))


def noise(seconds):
    return rng.standard_normal(int(seconds*RATE))


def norm(signal):
    return signal/max(np.max(np.abs(signal)), 1e-9)


def rise_fall(t, rise, fall, at=0.0):
    """An envelope rising over `rise` seconds from `at`, then falling away
    (time constant `fall`)."""
    after = t-at
    up = np.clip(after/max(rise, 1e-4), 0, 1)**2
    down = np.exp(-np.clip(after-rise, 0, None)/fall)
    return np.where(after < 0, 0.0, up*down)


def sweep_tone(t, start, end, span):
    """A sine whose pitch falls from `start` to `end` Hz over about `span`."""
    pitch = end+(start-end)*np.exp(-t/span)
    return np.sin(2*math.pi*np.cumsum(pitch)/RATE)


def crackles(seconds, rate, low=1800, high=7000, looped=False, density=None):
    """Sparse snaps of fire (or of ice): short clicks, `rate` a second on
    average (shaped over time by `density`, 0 to 1 per sample), kept in a
    band."""
    n = int(seconds*RATE)
    chance = rate/RATE*(density if density is not None else 1.0)
    clicks = np.zeros(n)
    for k in np.nonzero(rng.random(n) < chance)[0]:
        length = int(rng.uniform(.0015, .006)*RATE)
        shape = rng.standard_normal(length)*np.exp(-np.arange(length)/(length*.25))*rng.uniform(.3, 1.0)
        end = k+length
        if end <= n: clicks[k:end] += shape
        elif looped:
            clicks[k:] += shape[:n-k]
            clicks[:end-n] += shape[n-k:]
    return band(clicks, low, high)


def splinters(t, count, span, low, high, start=0.0):
    """Ice cracking and splintering: short bursts of noise, each kept in a
    band an octave or more wide (so none rings at a pitch, as a chime
    would), struck within `span` seconds after `start`, each gone in a few
    milliseconds."""
    n = len(t)
    out = np.zeros(n)
    for i in range(count):
        at = int((start+rng.uniform(0, span)**1.5/max(span, 1e-4)**.5)*RATE)
        length = int(rng.uniform(.004, .018)*RATE)
        if at >= n: continue
        length = min(length, n-at)
        bottom = math.exp(rng.uniform(math.log(low), math.log(high/2)))
        piece = band(rng.standard_normal(length+256), bottom, min(bottom*rng.uniform(2.0, 4.0), 20000))[:length]
        out[at:at+length] += piece*np.exp(-np.arange(length)/(length*.3))*rng.uniform(.3, 1.0)
    return out


def flutter(seconds, rate, depth, looped=True):
    """A flame's flicker: a slow, random swell and ebb of loudness, about
    `rate` times a second, `depth` deep (circular when `looped`)."""
    wobble = norm(band(noise(seconds), rate*.4, rate*2.0))
    return 1.0+depth*wobble


def periodic(t, length, cycles, phase=0.0):
    """A swell repeating exactly `cycles` times over `length` seconds."""
    return .5+.5*np.sin(2*math.pi*cycles*t/length+phase)


# The original game's fire whoosh (assets/audio/fire-whoosh.mp3): silent for
# its first 0.62 seconds, then a deep roar swelling to its loudest at about
# 1.05 and dying away over the next second and a half. The cast begins
# FIREBALL_CAST seconds in (just as it is heard, so it swells at once); the
# burst cuts in at FIREBALL_BURST, at the roar's loudest, and is cut short.
FIREBALL_CAST = .74
FIREBALL_BURST = .98
BURST_SECONDS = .7


def roar():
    return decoded(ROOT/'assets/audio/fire-whoosh.mp3')


def fireball_cast():
    """The old whoosh, without the silence before it: a roar of flame
    swelling from the staff the moment it is cast (and Fire Tornado
    rising, and Blazing Speed)."""
    whoosh = roar()[int(FIREBALL_CAST*RATE):].copy()
    rise, fall = int(.012*RATE), int(.5*RATE)
    whoosh[:rise] *= np.linspace(0, 1, rise)[:, None]
    whoosh[-fall:] *= (np.cos(np.linspace(0, math.pi, fall))*.5+.5)[:, None]
    return whoosh/np.max(np.abs(whoosh))*.89


def fireball_burst():
    """Fireball striking: the same roar, struck at its loudest and short,
    with a low thump under it; no crackling."""
    whoosh = roar()[int(FIREBALL_BURST*RATE):int((FIREBALL_BURST+BURST_SECONDS)*RATE)].copy()
    t = times(len(whoosh)/RATE)
    whoosh *= (rise_fall(t, .004, .2)/max(rise_fall(t, .004, .2).max(), 1e-9))[:, None]
    thump = (sweep_tone(t, 95, 38, .06)*rise_fall(t, .003, .14))[:, None]*.5
    body = band(tilt(noise(len(t)/RATE), 3.0), 40, 900)*rise_fall(t, .004, .1)
    out = whoosh/np.max(np.abs(whoosh))+thump+(body/np.max(np.abs(body))*.25)[:, None]
    out = np.tanh(out*1.4)
    fall = int(.08*RATE)
    out[-fall:] *= (np.cos(np.linspace(0, math.pi, fall))*.5+.5)[:, None]
    return out/np.max(np.abs(out))*.89


def fire_blast():
    seconds = 1.4
    t = times(seconds)
    roar = tilt(noise(seconds), 2.5)
    thump = sweep_tone(t, 90, 30, .1)*rise_fall(t, .005, .2)*1.3
    # The wave rushing outward: a deep roar, and above it the air it drives.
    wave = band(roar, 70, 1100)*rise_fall(t, .06, .4)*flutter(seconds, 9, .5, False)*1.4
    air = band(noise(seconds), 500, 4000)*rise_fall(t, .1, .2)*.45
    # (No crackling in it: a clean rush of flame.)
    return finish(band(thump+wave+air*.6, 20, 6500), drive=1.5)


TORNADO_LOOP = 4.0


def fire_tornado():
    seconds = TORNADO_LOOP
    t = times(seconds)
    roar = tilt(noise(seconds), 2.0)
    # Flames whooshing round: a low body and a brighter band swelling in turn
    # (twice and three times as often, so the swirl never quite repeats
    # within the loop), a deep rumble under them, and crackling.
    low = band(roar, 90, 650)*(.55+.45*periodic(t, seconds, 6))
    high = band(roar, 500, 2600)*(.3+.7*periodic(t, seconds, 9, 1.3)**2)*1.6
    rumble = band(noise(seconds), 30, 140)*(.7+.3*periodic(t, seconds, 4, .6))*1.4
    licks = band(roar, 200, 1600)*(flutter(seconds, 11, .6)-1.0)*.8
    snap = crackles(seconds, 70, 1200, 5000, looped=True)*1.2
    whole = band((low+high+rumble+licks+snap)*(flutter(seconds, 3, .15)), 20, 6000)
    # (No fades: it loops.)
    whole = np.tanh(whole/np.max(np.abs(whole))*1.5)
    return whole/np.max(np.abs(whole))*.85


# When the sky bolt's strokes fall (scripts/wizard_fx.gd SkyStrike.STROKES).
STROKES = [0.0, .14, .27]


def thunder_strike():
    seconds = 3.4
    t = times(seconds)
    crack = np.zeros_like(t)
    for i, at in enumerate(STROKES):
        strength = [1.0, .55, .4][i]
        crack += band(noise(seconds), 1200, 9000)*rise_fall(t, .001, .02, at)*strength*1.0
        crack += band(noise(seconds), 150, 2500)*rise_fall(t, .002, .06, at)*strength*1.4
    sizzle = band(noise(seconds), 3000, 9000)*rise_fall(t, .002, .15)*.15
    boom = sweep_tone(t, 70, 32, .2)*rise_fall(t, .01, .45, .01)*1.4
    body = band(tilt(noise(seconds), 3.0), 30, 320)*rise_fall(t, .03, .5, .02)*2.2
    # The thunder rolling away: deep, lumpy, slowly dying.
    roll = band(tilt(noise(seconds), 3.0), 25, 180)*rise_fall(t, .25, 1.1, .15)*(1.0+.8*norm(band(noise(seconds), 1.5, 5)))*2.0
    return finish(band(crack+sizzle+boom*1.3+body*1.4+roll*1.4, 20, 10000), drive=1.8)


def frost_bolt():
    seconds = .7
    t = times(seconds)
    rush = band(noise(seconds), 1800, 9000)*rise_fall(t, .02, .16)*1.1
    body = band(noise(seconds), 400, 1800)*rise_fall(t, .015, .1)*.5
    # (Frost crackling off it as it goes: splintering, not chiming.)
    frost = splinters(t, 22, .3, 2000, 10000)*1.6
    return finish(rush+body+frost, drive=1.3)


def ice_impact():
    seconds = .55
    t = times(seconds)
    crack = band(noise(seconds), 1500, 12000)*rise_fall(t, .001, .02)*1.6
    thud = sweep_tone(t, 160, 70, .03)*rise_fall(t, .002, .05)*.7
    shards = splinters(t, 34, .14, 1500, 11000)*2.2
    grit = crackles(seconds, 500, 2000, 9000, density=rise_fall(t, .002, .07))*2.0
    return finish(crack+thud+shards+grit, drive=1.5)


def ice_spikes():
    seconds = 1.0
    t = times(seconds)
    grind = band(tilt(noise(seconds), 1.5), 200, 2600)*rise_fall(t, .07, .18)*1.3
    crunch = crackles(seconds, 900, 700, 4500, density=rise_fall(t, .05, .2))*2.8
    thud = sweep_tone(t, 130, 45, .07)*rise_fall(t, .01, .15, .03)*1.0
    shards = splinters(t, 40, .3, 1200, 9000, .06)*2.0
    return finish(grind+crunch+thud+shards, drive=1.7)


def ice_prison():
    seconds = 1.0
    t = times(seconds)
    # Creaking shut: crackling that thickens toward the moment it sets.
    sets = .32
    creak = crackles(seconds, 700, 900, 5000, density=np.where(t < sets, (t/sets)**2, np.exp(-(t-sets)/.05)))*2.2
    groan = band(noise(seconds), 300, 1200)*np.where(t < sets, t/sets, np.exp(-(t-sets)/.04))*.5
    clunk = sweep_tone(t, 180, 80, .04)*rise_fall(t, .002, .12, sets)*1.1
    knock = band(noise(seconds), 150, 2500)*rise_fall(t, .001, .03, sets)*1.2
    # (As it sets, the ice cracks through: splintering, not ringing.)
    split = splinters(t, 24, .1, 1500, 10000, sets)*1.8
    return finish(creak+groan+clunk+knock+split, drive=1.5)


FROST_LOOP = 3.0


def frost_stream():
    seconds = FROST_LOOP
    t = times(seconds)
    hiss = band(noise(seconds), 2200, 10000)*(.75+.25*periodic(t, seconds, 5))
    body = band(noise(seconds), 500, 2200)*(.6+.4*periodic(t, seconds, 7, 2.0))*.6
    sparkle = crackles(seconds, 120, 4000, 11000, looped=True)*1.5
    whole = (hiss+body+sparkle)*flutter(seconds, 6, .12)
    whole = np.tanh(whole/np.max(np.abs(whole))*1.3)
    return whole/np.max(np.abs(whole))*.8


STORM_LOOP = 4.0


def ice_storm():
    seconds = STORM_LOOP
    t = times(seconds)
    # Howling: two narrow bands of wind, rising and falling in turn.
    howl = band(noise(seconds), 380, 520, .08)*(.4+.6*periodic(t, seconds, 3))*2.2
    moan = band(noise(seconds), 600, 820, .08)*(.3+.7*periodic(t, seconds, 5, 2.4))*1.6
    gust = band(tilt(noise(seconds), 2.0), 120, 2000)*(.5+.5*periodic(t, seconds, 2, 1.0))
    hiss = band(noise(seconds), 3000, 10000)*.12
    tinkle = crackles(seconds, 60, 3000, 9000, looped=True)*.9
    whole = howl+moan+gust+hiss+tinkle
    whole = np.tanh(whole/np.max(np.abs(whole))*1.3)
    return whole/np.max(np.abs(whole))*.8


def ignition_burst():
    seconds = .4
    t = times(seconds)
    crack = band(noise(seconds), 700, 6000)*rise_fall(t, .0008, .012)*1.4
    punch = sweep_tone(t, 160, 45, .025)*rise_fall(t, .002, .07)*1.4
    body = band(tilt(noise(seconds), 1.5), 80, 2200)*rise_fall(t, .003, .05)*1.8
    whoomph = band(noise(seconds), 150, 600)*rise_fall(t, .008, .09)*.8
    snap = crackles(seconds, 400, 1200, 5000, density=rise_fall(t, .004, .08))*1.3
    return finish(band(crack+punch+body+whoomph+snap, 20, 7500), drive=2.2)


def teleport():
    seconds = .45
    t = times(seconds)
    arrive = .13
    # Drawn in: noise swept up quickly as he goes, cut off as he vanishes.
    centre = 600+4200*np.clip(t/arrive, 0, 1)**1.5
    swish = np.zeros_like(t)
    rushed = band(noise(seconds), 500, 9000)
    gate = np.where(t < arrive, (t/arrive)**1.8, np.exp(-(t-arrive)/.012))
    swish = rushed*gate*.9
    # (A narrower band riding the sweep gives it its rising pitch, unpitched.)
    from make_sounds import biquad
    sweep = biquad(noise(seconds), 'band', centre, 1.2)*gate*1.6
    # Arriving: a soft whump of displaced air, and a breath after it.
    whump = sweep_tone(t, 140, 55, .04)*rise_fall(t, .004, .09, arrive)*.9
    breath = band(noise(seconds), 300, 3000)*rise_fall(t, .01, .1, arrive)*.6
    return finish(swish+sweep+whump+breath, drive=1.4)


if __name__ == '__main__':
    write('fireball-cast.wav', fireball_cast())
    write('fireball-burst.wav', fireball_burst())
    write('fire-blast.wav', fire_blast())
    write('fire-tornado.wav', fire_tornado())
    write('thunder-strike.wav', thunder_strike())
    write('frost-bolt.wav', frost_bolt())
    write('ice-impact.wav', ice_impact())
    write('ice-spikes.wav', ice_spikes())
    write('ice-prison.wav', ice_prison())
    write('frost-stream.wav', frost_stream())
    write('ice-storm.wav', ice_storm())
    write('ignition-burst.wav', ignition_burst())
    write('teleport.wav', teleport())
