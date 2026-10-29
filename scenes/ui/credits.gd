class_name Credits
extends RefCounted
## Who made what. Add a line here when a new asset pack comes in; the credits screen builds itself
## from this list. Licenses are as shipped with each pack (see the LICENSE files in assets/).

const SECTIONS := [
	{
		"heading": "Characters and animations",
		"entries": [
			{"name": "Adventurers Character Pack 2.0", "by": "Kay Lousberg (KayKit)", "license": "CC0", "url": "https://kaylousberg.com"},
			{"name": "Character Animations 1.1", "by": "Kay Lousberg (KayKit)", "license": "CC0", "url": "https://kaylousberg.com"},
		],
	},
	{
		"heading": "World",
		"entries": [
			{"name": "Nature Kit 2.1", "by": "Kenney", "license": "CC0", "url": "https://kenney.nl"},
			{"name": "Survival Kit 2.0", "by": "Kenney", "license": "CC0", "url": "https://kenney.nl"},
			{"name": "Fantasy Town Kit 2.0", "by": "Kenney", "license": "CC0", "url": "https://kenney.nl"},
			{"name": "Skyboxes 1.0", "by": "Kenney", "license": "CC0", "url": "https://kenney.nl"},
			{"name": "Pattern Pack", "by": "Kenney", "license": "CC0", "url": "https://kenney.nl"},
		],
	},
	{
		"heading": "Wildlife",
		"entries": [
			{
				"name": "Animated Low Poly animals (rabbit, fox, squirrel, duck, owls, birds, eagle, harpy)",
				"by": "WildPoly3D",
				"license": "CC BY-NC 4.0",
				"url": "https://sketchfab.com/WildPoly3D",
			},
		],
	},
	{
		"heading": "Engine",
		"entries": [
			{"name": "Godot Engine", "by": "Juan Linietsky, Ariel Manzur and contributors", "license": "MIT", "url": "https://godotengine.org"},
			{"name": "Jolt Physics", "by": "Jorrit Rouwe", "license": "MIT", "url": "https://github.com/jrouwe/JoltPhysics"},
		],
	},
]

const HEADING_COLOR := "#f6e8c8"
const NAME_COLOR := "#ffffff"
const DIM_COLOR := "#c9b79a"
const LINK_COLOR := "#8fd6e8"


## The whole list as BBCode for a RichTextLabel with bbcode and meta handling on; clicking a link
## sends its url as meta.
static func bbcode() -> String:
	var text := ""
	for section: Dictionary in SECTIONS:
		text += "[font_size=26][color=%s]%s[/color][/font_size]\n" % [HEADING_COLOR, section["heading"]]
		for entry: Dictionary in section["entries"]:
			text += "[color=%s]%s[/color]\n" % [NAME_COLOR, entry["name"]]
			text += "[color=%s]by %s  -  %s  -  [/color][url=%s][color=%s]%s[/color][/url]\n\n" % [
				DIM_COLOR, entry["by"], entry["license"], entry["url"], LINK_COLOR, entry["url"].trim_prefix("https://"),
			]
	return text
