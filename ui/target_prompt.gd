class_name TargetPrompt
extends Control
## What E does to the thing he's facing (Player.target_changed), in the HUD's
## style (Sleek), just under the middle of the screen as in Grounded: its name
## in small spaced capitals, then the E cap and the action ("Chop", "Smash",
## a hand and "Pick up"). Without the right tool: a dim lock and what it needs
## ("Needs a hammer"). With pieces lying round him: "Hold E · Pick up all".

var info := {}
var _shown := 0.0
var _last := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_info(i: Dictionary) -> void:
	info = i
	if not i.is_empty():
		_last = i
	queue_redraw()


func _process(delta: float) -> void:
	var want := 0.0 if info.is_empty() else 1.0
	if _shown != want:
		_shown = move_toward(_shown, want, delta * 8.0)
		queue_redraw()


func _draw() -> void:
	if _shown <= 0.0 or _last.is_empty():
		return
	var a := _shown
	var c := size.x * 0.5
	var name := String(_last.get("name", "")).to_upper()
	var ok := bool(_last.get("ok", true))
	var key := GameSettings.key_text("interact")
	var verb := String(_last.get("verb", ""))
	var fs := 20
	var row_w := 40.0 + Sleek.text_width(verb, fs) + (28.0 if bool(_last.get("hand", false)) else 0.0)
	if not ok:
		row_w = 26.0 + Sleek.text_width(String(_last.get("need", "")), 17)
	var name_w := Sleek.text_width(name, 13, Sleek.spaced(3))
	var w := maxf(row_w, name_w) + 140.0
	HudGlyphs.band(self, Rect2(c - w * 0.5, 2.0, w, 72.0), 0.42 * a)
	Sleek.draw_text(self, Vector2(c, 24.0), name, 13, Color(Sleek.CREAM, 0.88 * a), true, Sleek.spaced(3))
	var y := 50.0
	var x := c - row_w * 0.5
	if ok:
		_cap(Vector2(x + 14.0, y), key, a)
		x += 34.0
		if bool(_last.get("hand", false)):
			_hand(Vector2(x + 10.0, y), 9.0, Color(Sleek.CREAM, a))
			x += 26.0
		Sleek.draw_text(self, Vector2(x, y + 7.0), verb, fs, Color(Sleek.CREAM, a))
	else:
		_lock(Vector2(x + 9.0, y), 8.0, Color(Sleek.AMBER, 0.9 * a))
		Sleek.draw_text(self, Vector2(x + 26.0, y + 6.0), String(_last.get("need", "")), 17, Color(Sleek.AMBER, 0.9 * a))
	var more := int(_last.get("more", 0))
	if ok and more >= 2:
		var t := "Hold %s · Pick up all (%d)" % [key, more]
		Sleek.draw_text(self, Vector2(c, y + 34.0), t, 14, Color(Sleek.CREAM, 0.62 * a), true)


## The key on a small cream cap, centred on `c`.
func _cap(c: Vector2, key: String, a: float) -> void:
	var fs := 15
	var tw := Sleek.text_width(key, fs)
	var r := Rect2(c.x - maxf(tw + 14.0, 26.0) * 0.5, c.y - 13.0, maxf(tw + 14.0, 26.0), 26.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9, 0.95 * a)
	sb.set_corner_radius_all(6)
	sb.border_width_bottom = 3
	sb.border_color = Color(0.62, 0.58, 0.5, a)
	draw_style_box(sb, r)
	draw_string(Sleek.font(), Vector2(c.x - tw * 0.5, c.y + 5.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Sleek.INK, a))


## A small open hand (picking up), in the glyphs' style.
func _hand(c: Vector2, s: float, col: Color) -> void:
	var ink := Color(0, 0, 0, 0.55 * col.a)
	var palm := Rect2(c.x - s * 0.55, c.y - s * 0.1, s * 1.1, s * 0.95)
	for pass_i in 2:
		var cc := ink if pass_i == 0 else col
		var grow := 1.5 if pass_i == 0 else 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = cc
		sb.set_corner_radius_all(int(s * 0.35))
		draw_style_box(sb, palm.grow(grow))
		for f in 4:  # fingers
			var fx := c.x - s * 0.42 + f * s * 0.28
			draw_line(Vector2(fx, c.y), Vector2(fx, c.y - s * (0.75 + 0.12 * (1.5 - absf(f - 1.5)))), cc, s * 0.2 + grow * 2.0)
		draw_line(Vector2(c.x - s * 0.5, c.y + s * 0.35), Vector2(c.x - s * 0.95, c.y - s * 0.05), cc, s * 0.22 + grow * 2.0)


## A small padlock (something he can't do yet).
func _lock(c: Vector2, s: float, col: Color) -> void:
	draw_arc(c + Vector2(0, -s * 0.2), s * 0.45, PI, TAU, 12, Color(0, 0, 0, 0.5 * col.a), s * 0.3)
	draw_arc(c + Vector2(0, -s * 0.2), s * 0.45, PI, TAU, 12, col, s * 0.18)
	var body := Rect2(c.x - s * 0.65, c.y - s * 0.2, s * 1.3, s * 1.0)
	draw_rect(body.grow(1.5), Color(0, 0, 0, 0.5 * col.a))
	draw_rect(body, col)
