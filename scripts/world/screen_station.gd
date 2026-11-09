class_name ScreenStation
extends Interactable
## Öffnet einen UI-Bildschirm (Tagesbelohnung, Bestenliste, Garderobe …).

@export var screen: StringName = &"daily"
@export var only_when_daily_available := false


func prompt_text() -> String:
	if only_when_daily_available and not Economy.daily_available():
		return "Tagesbelohnung morgen wieder"
	return super.prompt_text()


func interact(_player: Node3D) -> void:
	Audio.play(&"open")
	Events.open_screen.emit(screen)
