class_name SoftPanel
extends PanelContainer
## A panel in the compass's style: no box, just the soft dark band
## (HudGlyphs.band) fading out at every edge behind its content. The margins
## keep the content on the darker middle.

@export var strength := 0.62


func _init() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 96.0
	sb.content_margin_right = 96.0
	sb.content_margin_top = 34.0
	sb.content_margin_bottom = 34.0
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	HudGlyphs.band(self, Rect2(Vector2.ZERO, size), strength)
