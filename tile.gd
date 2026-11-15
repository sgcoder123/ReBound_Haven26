extends StaticBody2D

signal hit_taken(brick)
signal broken(brick)

@export var max_hits := 1        # normal brick = 1, final brick = 3 or more
@export var tint := Color.WHITE  # per-brick color from the Inspector

@onready var visual: AnimatedSprite2D = $brickanimated

var hits_left := 1
var dead := false

func _ready() -> void:
	hits_left = max_hits
	visual.modulate = tint
	visual.stop()
	visual.frame = 0

func hit() -> void:
	if dead:
		return
	hits_left -= 1
	hit_taken.emit(self)
	if hits_left <= 0:
		_break()
	else:
		_show_damage()
		_flash()

func _show_damage() -> void:
	var count := visual.sprite_frames.get_frame_count(visual.animation)
	var progress := float(max_hits - hits_left) / float(max_hits)
	visual.frame = mini(int(progress * count), count - 1)

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.05)
	tween.tween_property(visual, "modulate", tint, 0.15)

func _break() -> void:
	dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	broken.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", visual.scale * 1.3, 0.2)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
