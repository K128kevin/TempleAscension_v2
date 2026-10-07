"""Makes the wizard's spell sounds, written to assets/audio as 48 kHz 16-bit
WAV. All are synthesised (noise, tones and filters only), with
tools/make_sounds.py's helpers.

  fireball-cast.wav   Fireball leaving the staff (and Blazing Speed): a roar
                      of flame that bursts out at once and rushes away.
  fireball-burst.wav  Fireball striking (and Ignition): a short, fiery
                      burst, a thump and a spray of crackles.
  fire-blast.wav      Blast Wave: a deep whoomph of flame rushing outward.
  fire-tornado.wav    Fire Tornado, looped while it burns: whooshing flames
                      swirling round, a rumble under them, crackling.
  thunder-strike.wav  Lightning Rod's bolt from the sky: a splitting crack
                      (struck again twice, as the bolt is drawn:
                      scripts/wizard_fx.gd SkyStrike), a boom, and thunder
                      rolling away.
  frost-bolt.wav      Ice Bolt cast: an icy rush with a glassy shimmer.
  ice-impact.wav      Ice Bolt striking: ice shattering.
  ice-spikes.wav      Ice Spikes: ice grinding up out of the floor and
                      cracking apart.
  ice-prison.wav      Ice Prison: ice creaking shut round its prisoner, and
                      a solid clunk as it sets.
  frost-stream.wav    Freeze Floor and Frost Blast, looped while channelled:
                      a hissing spray of frost.
  ice-storm.wav       Ice Storm, looped while it lasts: a howling wind full
                      of tinkling ice.
  ignition-burst.wav  Ignition going off: a quick, bursting pop of flame, a
                      sharp crack and a punch, over in a third of a second.

The loops (fire-tornado, frost-stream, ice-storm) are made circular (every
filter and swell repeats exactly over their length), so they loop without a
seam; their .import files loop them (edit/loop_mode=2).

  python3 tools/make_spell_sounds.py
"""
import math
import numpy as np
from make_sounds import RATE, times, finish, write

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


def pings(t, count, span, low, high, decay=(.02, .09), start=0.0):
    """Glassy pings of ice: short sines at scattered pitches, struck within
    `span` seconds after `start`."""
    out = np.zeros_like(t)
    for i in range(count):
        at = start+rng.uniform(0, span)**1.5/max(span, 1e-4)**.5
        pitch = math.exp(rng.uniform(math.log(low), math.log(high)))
        after = t-at
        ring = np.where(after >= 0, np.exp(-np.clip(after, 0, None)/rng.uniform(*decay)), 0.0)
        out += np.sin(2*math.pi*pitch*after+rng.uniform(0, 6.28))*ring*rng.uniform(.3, 1.0)
    return out


def flutter(seconds, rate, depth, looped=True):
    """A flame's flicker: a slow, random swell and ebb of loudness, about
    `rate` times a second, `depth` deep (circular when `looped`)."""
    wobble = norm(band(noise(seconds), rate*.4, rate*2.0))
    return 1.0+depth*wobble


def periodic(t, length, cycles, phase=0.0):
    """A swell repeating exactly `cycles` times over `length` seconds."""
    return .5+.5*np.sin(2*math.pi*cycles*t/length+phase)


def fireball_cast():
    seconds = .95
    t = times(seconds)
    roar = tilt(noise(seconds), 2.0)
    # The rush: low flame noise bursting out at once, its body climbing in
    # pitch as it leaves the staff and falling away.
    rush = band(roar, 120, 900)*rise_fall(t, .03, .22)*1.3
    air = band(noise(seconds), 600, 3200)*rise_fall(t, .05, .12)*.5
    licks = band(roar, 250, 1400)*rise_fall(t, .02, .35)*flutter(seconds, 14, .7, False)*.7
    thump = sweep_tone(t, 120, 50, .05)*rise_fall(t, .004, .09)*.6
    snap = crackles(seconds, 90, 1200, 5000, density=rise_fall(t, .02, .3))*1.1
    return finish(band(rush+air*.6+licks+thump+snap, 20, 7000), drive=1.4)


def fireball_burst():
    seconds = .6
    t = times(seconds)
    thump = sweep_tone(t, 110, 38, .06)*rise_fall(t, .003, .12)*1.2
    body = band(tilt(noise(seconds), 1.5), 60, 2600)*rise_fall(t, .006, .09)*1.6
    whoomph = band(noise(seconds), 180, 700)*rise_fall(t, .015, .18)*.9
    snap = crackles(seconds, 260, 1200, 5000, density=rise_fall(t, .01, .14))*1.4
    return finish(band(thump+body+whoomph+snap, 20, 6500), drive=1.6)


def fire_blast():
    seconds = 1.4
    t = times(seconds)
    roar = tilt(noise(seconds), 2.5)
    thump = sweep_tone(t, 90, 30, .1)*rise_fall(t, .005, .2)*1.3
    # The wave rushing outward: a deep roar, and above it the air it drives.
    wave = band(roar, 70, 1100)*rise_fall(t, .06, .4)*flutter(seconds, 9, .5, False)*1.4
    air = band(noise(seconds), 500, 4000)*rise_fall(t, .1, .2)*.45
    snap = crackles(seconds, 160, 1200, 5000, density=rise_fall(t, .05, .5))*1.2
    return finish(band(thump+wave+air*.6+snap, 20, 6500), drive=1.5)


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
    shimmer = pings(t, 14, .25, 2200, 7500, (.05, .2))*.5
    return finish(rush+body+shimmer, drive=1.3)


def ice_impact():
    seconds = .55
    t = times(seconds)
    crack = band(noise(seconds), 1500, 12000)*rise_fall(t, .001, .02)*1.6
    thud = sweep_tone(t, 160, 70, .03)*rise_fall(t, .002, .05)*.7
    shards = pings(t, 26, .14, 1800, 8000, (.015, .08))*.7
    grit = crackles(seconds, 500, 2000, 9000, density=rise_fall(t, .002, .07))*2.0
    return finish(crack+thud+shards+grit, drive=1.5)


def ice_spikes():
    seconds = 1.0
    t = times(seconds)
    grind = band(tilt(noise(seconds), 1.5), 200, 2600)*rise_fall(t, .07, .18)*1.3
    crunch = crackles(seconds, 900, 700, 4500, density=rise_fall(t, .05, .2))*2.8
    thud = sweep_tone(t, 130, 45, .07)*rise_fall(t, .01, .15, .03)*1.0
    shards = pings(t, 30, .3, 1600, 7000, (.02, .12), .06)*.55
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
    ring = pings(t, 12, .08, 2000, 6000, (.08, .3), sets)*.5
    return finish(creak+groan+clunk+knock+ring, drive=1.5)


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
