extends RefCounted
## The day: thirty minutes from one sunrise to the next. Sunrise and sunset
## take three minutes each, night ten, and the rest is day. The clock (seconds,
## kept in the run) starts at sunrise; a new character wakes in the night.
const CYCLE = 1800.0
const SUNRISE = 180.0
const SUNSET = 1020.0
const NIGHT = 1200.0
# A new character wakes with six minutes of the night left; a character from
# before the clock was kept finds a clear morning.
const START = 1440.0
const MORNING = 420.0
# The one light in the sky is the moon until this long into the sunrise, and
# again from this long before the night; its light passes through nothing as
# it changes hands.
const HANDOVER = 40.0
const MOON = Color(.60,.70,1.0)
const GOLD = Color(1.0,.55,.28)
const RED = Color(1.0,.38,.20)
# Through the cycle: when, the light's colour and strength, the ambient
# light's, the sky's colour, and how far it is night (fires light the ground).
const KEYS = [
	[0.0,MOON,.21,Color(.30,.38,.66),.29,Color(.035,.05,.10),1.0],
	[40.0,MOON,0.0,Color(.50,.44,.56),.42,Color(.30,.21,.24),.7],
	[40.01,RED,0.0,Color(.50,.44,.56),.42,Color(.30,.21,.24),.7],
	[110.0,GOLD,.72,Color(.80,.62,.55),.38,Color(.86,.52,.32),.1],
	[180.0,Color(1.0,.74,.50),.9,Color(.74,.72,.80),.4,Color(.84,.62,.42),0.0],
	[300.0,Color(1.0,.95,.88),1.0,Color(.70,.78,.96),.42,Color(.80,.68,.50),0.0],
	[900.0,Color(1.0,.95,.88),1.0,Color(.70,.78,.96),.42,Color(.80,.68,.50),0.0],
	[1020.0,Color(1.0,.86,.68),.95,Color(.72,.76,.90),.4,Color(.80,.66,.46),0.0],
	[1100.0,GOLD,.75,Color(.80,.62,.55),.38,Color(.86,.50,.30),.1],
	[1159.99,RED,0.0,Color(.52,.42,.54),.42,Color(.34,.21,.25),.7],
	[1160.0,MOON,0.0,Color(.52,.42,.54),.42,Color(.34,.21,.25),.7],
	[1200.0,MOON,.21,Color(.30,.38,.66),.29,Color(.035,.05,.10),1.0],
	[1800.0,MOON,.21,Color(.30,.38,.66),.29,Color(.035,.05,.10),1.0]]

static func of_day(clock: float) -> float:
	return fposmod(clock,CYCLE)

# "night", "sunrise", "day" or "sunset".
static func phase(clock: float) -> String:
	var t = of_day(clock)
	if t < SUNRISE: return "sunrise"
	if t < SUNSET: return "day"
	return "sunset" if t < NIGHT else "night"

# The sky at a time: {"light" (colour), "energy", "ambient", "ambient_energy",
# "sky", "night" (0 to 1), "moon" (whether the light is the moon), "toward"
# (the way to the light), "fog" (the mist's density) and "fog_colour"}.
static func sky(clock: float) -> Dictionary:
	var t = of_day(clock)
	var next = 1
	while KEYS[next][0] < t: next += 1
	var a: Array = KEYS[next-1]
	var b: Array = KEYS[next]
	var f = clampf((t-a[0])/maxf(b[0]-a[0],.001),0.0,1.0)
	var moon = t < HANDOVER or t >= NIGHT-HANDOVER
	var sky_colour: Color = a[5].lerp(b[5],f)
	var ambient: Color = a[3].lerp(b[3],f)
	return {"light":a[1].lerp(b[1],f),"energy":lerpf(a[2],b[2],f),"ambient":ambient,"ambient_energy":lerpf(a[4],b[4],f),"sky":sky_colour,"night":lerpf(a[6],b[6],f),"moon":moon,"toward":toward(t,moon),"fog":fog(t),"fog_colour":sky_colour.lerp(Color(.78,.78,.80)*clampf(ambient.get_luminance()*1.5,.25,1.0),.7)}

# The way to the sun, which rises in the east (+X), stands in the south at
# noon and sets in the west; or to the moon, which crosses the southern sky
# through the night. Neither is followed quite down to the horizon: the
# shadows stay a sane length.
static func toward(t: float, moon: bool) -> Vector3:
	if moon:
		var through = clampf(fposmod(t-NIGHT,CYCLE)/(CYCLE-NIGHT),0.0,1.0) if t >= NIGHT else (0.0 if t > NIGHT*.5 else 1.0)
		var angle = lerpf(.3,.7,through)*PI
		return Vector3(cos(angle)*.7,sin(angle),.55).normalized()
	var angle = clampf(t/NIGHT,0.0,1.0)*PI
	return Vector3(cos(angle)*.85,maxf(sin(angle),.24),.5).normalized()

# Mist gathers at the end of the night, lies through the sunrise and the early
# morning, and has burned off four minutes after the sunrise ends.
static func fog(t: float) -> float:
	var density = .0065
	if t >= CYCLE-70.0: return density*(t-(CYCLE-70.0))/70.0*.5
	if t < 50.0: return density*lerpf(.5,1.0,t/50.0)
	if t < 230.0: return density
	return density*clampf(1.0-(t-230.0)/190.0,0.0,1.0)
