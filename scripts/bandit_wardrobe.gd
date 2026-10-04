extends RefCounted
## Written by tools/make_bandits.py: what each garment covers, as
## [top, hem, sleeve] in metres on the body at rest.
const COVER = {
	"man": {"Tunic": [1.532, 0.462, 0.045], "Vest": [1.536, 1.067, 0.0], "Strap": [1.54, 1.042, 0.0], "Sash": [1.162, 1.037, 0.0], "Belt": [1.097, 1.052, 0.0], "Apron": [1.062, 0.642, 0.0], "Shawl": [1.564, 1.396, 0.0], "Cape": [1.476, 0.492, 0.0], "Headwrap": [1.783, 1.72, 0.0], "Bracer_l": [0.0, 0.0, 0.0], "Bindings_l": [0.0, 0.0, 0.0], "Bracer_r": [0.0, 0.0, 0.0], "Bindings_r": [0.0, 0.0, 0.0]},
	"woman": {"Tunic": [1.497, 0.455, 0.053], "Vest": [1.501, 1.05, 0.0], "Strap": [1.505, 1.025, 0.0], "Sash": [1.145, 1.02, 0.0], "Belt": [1.08, 1.035, 0.0], "Apron": [1.045, 0.635, 0.0], "Shawl": [1.52, 1.358, 0.0], "Cape": [1.438, 0.485, 0.0], "Headwrap": [1.741, 1.678, 0.0], "Bracer_l": [0.0, 0.0, 0.0], "Bindings_l": [0.0, 0.0, 0.0], "Bracer_r": [0.0, 0.0, 0.0], "Bindings_r": [0.0, 0.0, 0.0]},
}
