extends Control

# Set the next level or menu in the Inspector
@export_file("*.tscn") var next_scene_path: String

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# Automatically move on when the video finishes
	video_player.finished.connect(_on_video_finished)

func _unhandled_input(event: InputEvent) -> void:
	# Optional: Let players skip the cutscene with Enter/Space/Click
	if event.is_action_pressed("ui_accept"):
		_on_video_finished()

func _on_video_finished() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
