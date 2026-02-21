extends Node

var DOCS := [

	# ---------------- CHAPTER 0 ----------------
	{
		"id": "ev_textile_exam",
		"chapter": 0,
		"title": "ACT No. 199 — Textile Examination",
		"text_file": "res://docs/act_99.txt",

		# Always reveal these on open (fallback)
		"reveals_words": ["cut open", "from the inside"],

		# Reveal only if searched specifically
		"reveal_map": {
			"knife": ["cut open"],
			"cut": ["cut open"],
			"inside": ["from the inside"],
			"tent": ["cut open"]
		}
	},

	{
		"id": "ev_property_protocol",
		"chapter": 0,
		"title": "Case File 12 — Property Protocol",
		"text_file": "res://docs/case_file.txt",

		"reveals_words": ["yuri yudin"],

		"reveal_map": {
			"yudin": ["yuri yudin"],
			"cloth": ["cloth and glasses"],
			"glasses": ["cloth and glasses"],
			"military": ["united states military"]
		}
	},

	# ---------------- CHAPTER 1 ----------------
	{
		"id": "ev_autopsy_slobodin",
		"chapter": 1,
		"title": "Autopsy Report — Slobodin",
		"text_file": "res://docs/autopsy_file.txt",

		"reveals_words": ["skull"],

		"reveal_map": {
			"fracture": ["skull"],
			"skull": ["skull"]
		}
	},

	{
		"id": "ev_autopsy_underwear",
		"chapter": 1,
		"title": "Autopsy Reports — Clothing Condition",
		"text": "Several bodies were recovered only in underwear despite sub-zero temperatures.",

		"reveals_words": ["only in underwear", "paradoxical undressing"],

		"reveal_map": {
			"underwear": ["only in underwear"],
			"hypothermia": ["paradoxical undressing"]
		}
	},

	{
		"id": "ev_ravine_bodies",
		"chapter": 1,
		"title": "Ravine Recovery Notes",
		"text": "One body was missing a tongue and another exhibited missing eyebrows.",

		"reveals_words": ["tongue", "eyebrows"],

		"reveal_map": {
			"tongue": ["tongue"],
			"eyebrows": ["eyebrows"]
		}
	},

	{
		"id": "ev_radiation_test",
		"chapter": 1,
		"title": "Radiological Examination",
		"text": "Clothing recovered from the ravine victims tested radioactive.",

		"reveals_words": ["radioactive"],

		"reveal_map": {
			"radiation": ["radioactive"],
			"radioactive": ["radioactive"]
		}
	},

	# ---------------- CHAPTER 2 ----------------
	{
		"id": "ev_military_docs",
		"chapter": 2,
		"title": "Declassified Military Documents",
		"text": "Documents from the United States military reference experimental dispersal systems involving LSD and 3-Quinuclidinyl benzilate (BZ).",

		"reveals_words": [
			"united states military",
			"lsd",
			"3-quinuclidinyl benzilate (bz)",
			"psychoactive agents",
			"radiological material"
		],

		"reveal_map": {
			"military": ["united states military"],
			"lsd": ["lsd"],
			"bz": ["3-quinuclidinyl benzilate (bz)"],
			"benzilate": ["3-quinuclidinyl benzilate (bz)"]
		}
	}
]
