extends RefCounted
## Written by tools/make_townsfolk.py: what each garment covers, as
## [top, hem, sleeve] in metres on the body at rest.
const COVER = {
	"man": {"Tunic": [1.532, 0.502, 0.138], "Sack": [1.532, 0.682, 0.0], "Robe": [1.532, 0.302, 0.239], "Belt": [1.122, 1.082, 0.0]},
	"woman": {"Gown": [1.497, 0.121, 0.12], "Shift": [1.497, 0.335, 0.0], "Blouse": [1.507, 1.233, 0.46], "Dress": [1.497, 0.141, 0.0], "Belt": [1.105, 1.065, 0.0]},
}
