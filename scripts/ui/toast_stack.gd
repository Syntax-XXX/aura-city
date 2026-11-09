class_name ToastStack
extends VBoxContainer
## Kurze Meldungen oben mittig (max. 5 gleichzeitig, verschwinden nach 3 s).

func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	UIKit.pin(self, Control.PRESET_CENTER_TOP, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	Events.toast.connect(show_toast)


func show_toast(text: String, color := UITheme.CYAN) -> void:
	if get_child_count() >= 5:
		get_child(0).queue_free()
	var p := UIKit.panel(self, Color(0.07, 0.05, 0.14, 0.92), color, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, 16, color.lightened(0.3), p)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
