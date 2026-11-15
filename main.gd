extends Node

@onready var chapter_container: Node = $ChapterContainer
@onready var transition_player: AnimationPlayer = $TransitionPlayer

var current_chapter: Node = null

func _ready() -> void:
	GameManager.main = self
	load_chapter(GameManager.chapters[0])

func load_chapter(path: String) -> void:
	if current_chapter:
		current_chapter.queue_free()
		await current_chapter.tree_exited
	var scene: PackedScene = load(path)
	current_chapter = scene.instantiate()
	chapter_container.add_child(current_chapter)
	
