extends Control


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	$StartButton.grab_focus()


func _on_start_pressed() -> void:
	GameManager.start_game()
