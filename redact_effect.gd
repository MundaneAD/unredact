# redact_effect.gd  ─  Godot 4 Custom BBCode Redaction Effect
# ─────────────────────────────────────────────────────────────
# Renders tagged text as solid black redaction bars.
# Supports a smooth per-character "wipe in" reveal when the label is hovered.
#
# TAG SYNTAX
#   [redact]top secret[/redact]              — permanent black bar
#   [redact reveal=1]hover me[/redact]       — reveals on mouse hover (needs RedactLabel.gd)
#
# ─── QUICK SETUP ────────────────────────────────────────────
#
#  Option A – Pure effect (no hover reveal):
#    var label := $RichTextLabel
#    label.bbcode_enabled = true
#    label.custom_effects.append(load("res://redact_effect.gd").new())
#    label.text = "[redact]CLASSIFIED[/redact]"
#
#  Option B – With hover reveal:
#    Attach RedactLabel.gd to your RichTextLabel node instead.
#    It handles everything automatically.
#
# ─────────────────────────────────────────────────────────────

@tool
extends RichTextEffect

## The BBCode tag this effect responds to.
var bbcode := "redact"

# Colour of the redaction bar
const BAR_COLOR       := Color(0.07, 0.07, 0.07, 1.0)
# Slight variation per character so it looks like typed text under a bar
const BAR_COLOR_LIGHT := Color(0.12, 0.12, 0.12, 1.0)

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# ── Read tag options ────────────────────────────────────
	var can_reveal: bool = int(char_fx.env.get("reveal", 0)) == 1

	# ── Determine whether this character should be visible ──
	var visible := false

	if can_reveal:
		# Shared reveal state written by RedactLabel.gd via resource meta
		var hovered: bool     = get_meta("hovered",     false)
		var progress: float   = get_meta("reveal_time", 0.0)   # 0.0 → 1.0

		if hovered and progress > 0.0:
			# Stagger: character i reveals when progress passes i / total_chars
			# We approximate position within the tag using char_fx.range.x
			var char_offset: float = float(char_fx.range.x) * 0.04
			visible = progress > char_offset
	# else: reveal=0 → always redacted

	# ── Apply visual ────────────────────────────────────────
	if visible:
		# Let the real glyph show through, restore default colour
		char_fx.color.a = 1.0
	else:
		# Paint a black bar:
		# • Keep glyph so spacing is preserved (don't zero glyph_index)
		# • Overwrite colour with bar colour — character becomes invisible against it
		# • Add a tiny brightness dither so the bar has subtle texture
		var dither: float = fmod(float(char_fx.range.x) * 1.618, 1.0) * 0.06
		char_fx.color = Color(
			BAR_COLOR.r + dither,
			BAR_COLOR.g + dither,
			BAR_COLOR.b + dither,
			1.0
		)
		# Scale glyph to fill the cell → acts as a solid block
		char_fx.transform = char_fx.transform.scaled_local(Vector2(1.05, 0.85))

	return true
