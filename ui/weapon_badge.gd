class_name WeaponBadge
extends Control
## What Amodu has in his hands, bottom right, in the compass's style: the icon
## and name on a soft fading band. It brightens when he switches, with the
## weapons either side ghosted in, then settles to a quiet icon. Hidden until
## he owns something besides his fists.

const CREAM := HudGlyphs.CREAM
const AMBER := HudGlyphs.AMBER
const SETTLE := 2.2  # seconds bright after a switch

var inventory: Inventory
var font: Font
var _bright := 0.0
var _shown := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = get_theme_default_font()
	if inventory != null:
		inventory.equipped_changed.connect(func(_id: StringName) -> void: _bright = SETTLE)
		inventory.changed.connect(func() -> void: _bright = SETTLE)


func _process(delta: float) -> void:
	_bright = maxf(_bright - delta, 0.0)
	var want := 1.0 if inventory != null and inventory.combat_cycle().size() > 1 else 0.0
	_shown = move_toward(_shown, want, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if inventory == null or _shown <= 0.0:
		return
	var w := size.x
	var h := size.y
	var lit := clampf(_bright / 0.6, 0.0, 1.0)  # fades over the last 0.6 s
	var alpha := _shown * lerpf(0.62, 1.0, lit)
	HudGlyphs.band(self, Rect2(0.0, h * 0.14, w, h * 0.72), 0.42 * _shown)
	var c := Vector2(w * 0.5, h * 0.42)
	var id := inventory.equipped
	var info := Weapons.info(id)
	HudGlyphs.draw(self, String(info["glyph"]), c, 30.0, Color(CREAM, alpha))
	# the neighbours, only while it's bright after a switch
	var order := inventory.combat_cycle()
	if lit > 0.0 and order.size() > 1:
		var i := order.find(id)
		for side: int in [-1, 1]:
			var other: StringName = order[posmod(i + side, order.size())]
			if other == id:
				continue
			HudGlyphs.draw(self, String(Weapons.info(other)["glyph"]), c + Vector2(side * 46.0, 2.0), 18.0,
				Color(CREAM, 0.4 * lit * _shown))
	# the name under an amber hairline
	var label := String(info["name"])
	var fs := 15
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_line(Vector2(c.x - 18.0, h * 0.66), Vector2(c.x + 18.0, h * 0.66), Color(AMBER, 0.85 * alpha), 2.0)
	var at := Vector2(c.x - tw * 0.5, h * 0.66 + 18.0)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6 * alpha))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, alpha))
