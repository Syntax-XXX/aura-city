class_name DailyScreen
extends UIScreen
## Tagesbelohnung mit 7-Tage-Serie.

var _days: HBoxContainer
var _status: Label
var _claim: Button


func _init() -> void:
	screen_title = "Tagesbelohnung"
	window_size = Vector2(900, 420)


func build_content() -> void:
	UIKit.label("Komm jeden Tag vorbei – die Belohnung wächst mit deiner Serie (bis Tag 7).", 15, UITheme.MUTED, content)
	_days = UIKit.hbox(content, 10)
	_days.alignment = BoxContainer.ALIGNMENT_CENTER
	_status = UIKit.label("", 18, UITheme.TEXT, content)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	content.add_child(c)
	_claim = UIKit.primary("Abholen", _on_claim, c, UITheme.GOLD.darkened(0.2))
	_claim.custom_minimum_size = Vector2(260, 54)


func refresh() -> void:
	for c in _days.get_children():
		c.queue_free()
	var avail := Economy.daily_available()
	# Tag, der heute abgeholt würde (bzw. wurde)
	var today_day := clampi(Economy.daily_amount() / Economy.DAILY_REWARD_BASE, 1, 7) if avail else clampi(Economy.daily_streak, 1, 7)
	for d in range(1, 8):
		var done := d < today_day or (d == today_day and not avail)
		var is_today := d == today_day
		var p := UIKit.panel(_days, UITheme.PANEL_2, UITheme.GOLD if is_today else (UITheme.GREEN if done else UITheme.LINE), 12)
		p.custom_minimum_size = Vector2(100, 120)
		var v := UIKit.vbox(p, 4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		UIKit.label("Tag %d" % d, 14, UITheme.MUTED, v).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.label("✔" if done else "✦", 28, UITheme.GREEN if done else UITheme.GOLD, v).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.label(UIFormat.number(Economy.DAILY_REWARD_BASE * d), 15, UITheme.TEXT, v).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_claim.disabled = not avail
	_claim.text = "✦ %s abholen" % UIFormat.number(Economy.daily_amount()) if avail else "Morgen wieder"
	_status.text = "Serie: %d Tag(e)" % Economy.daily_streak


func _on_claim() -> void:
	var got := Economy.claim_daily()
	if got > 0:
		Audio.play(&"reward")
		Events.toast.emit("Tagesbelohnung: ✦ %s" % UIFormat.number(got), UITheme.GOLD)
		SaveSystem.save_game()
	refresh()
