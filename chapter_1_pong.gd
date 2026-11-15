extends Node2D

const MAX_SATURATION := 0.35
const PER_HIT := 0.02
const SPLIT_ACROSS_LONG_AXIS := true   # false = always cut vertically (left/right halves)

@onready var player: CharacterBody2D = $PlayerPaddle
@onready var opponent: CharacterBody2D = $OpponentPaddle
@onready var ball: CharacterBody2D = $Ball
@onready var player_label: Label = $PlayerScore
@onready var opponent_label: Label = $OpponentScore

var center := Vector2.ZERO
var screen_w := 1152.0
var player_score := 0
var opponent_score := 0
var ended := false
var serving := false
var split_dir := Vector2.DOWN    # direction from half 0 to half 1

func _ready() -> void:
	screen_w = get_viewport_rect().size.x
	center = get_viewport_rect().size / 2.0
	GameManager.set_saturation(0.0)

	# The ball must be free to reach the side edges so a point can score
	ball.enforce_side_bounds = false
	ball.bounce_bottom = true

	# Walls are only markers in Chapter 1; stop them from blocking the ball
	for wall_name in ["WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is CollisionObject2D:
			wall.collision_layer = 0
			wall.collision_mask = 0

	opponent.ball = ball
	ball.hit_paddle.connect(_on_ball_hit_paddle)
	player.shattered.connect(on_paddle_shatter)
	_update_score()
	_serve(1.0, 1.8)    # longer wait on the first serve so the fade-in finishes

func _physics_process(_delta: float) -> void:
	if ended or serving:
		return
	if ball.global_position.x - ball.radius <= 0.0:
		opponent_score += 1          # touched your (left) side: AI scores
		_serve(-1.0)
	elif ball.global_position.x + ball.radius >= screen_w:
		player_score += 1            # touched the AI's (right) side: you score
		_serve(1.0)

func _serve(dir_x: float, delay := 1.0) -> void:
	serving = true
	_update_score()
	ball.reset_to(center)
	await get_tree().create_timer(delay).timeout
	if not ended:
		ball.launch(dir_x)
	serving = false

func _on_ball_hit_paddle(paddle: Node) -> void:
	if ended:
		return
	if paddle == player:
		player.register_hit()
	GameManager.fade_saturation(
		minf(GameManager.saturation + PER_HIT, MAX_SATURATION), 0.3)

func _update_score() -> void:
	player_label.text = str(player_score)
	opponent_label.text = str(opponent_score)

# ---------- The snap ----------

func on_paddle_shatter() -> void:
	if ended:
		return
	ended = true
	ball.set_physics_process(false)
	opponent.set_physics_process(false)
	GameManager.fade_saturation(0.0, 0.1)

	var halves := _spawn_halves()
	await _crack_open(halves)                     # shake and split apart
	_drop_everything(halves)
	await get_tree().create_timer(1.8).timeout    # let it all fall
	GameManager.next_chapter()

func _find_sprite(node: Node) -> Node2D:
	for c in node.get_children():
		if c is AnimatedSprite2D or c is Sprite2D:
			return c
	return null

# Splits the paddle's current picture in half across the middle of its long side
func _spawn_halves() -> Array[Node2D]:
	var halves: Array[Node2D] = []
	var vis := _find_sprite(player)
	var tex: Texture2D = null
	if vis is AnimatedSprite2D:
		tex = vis.sprite_frames.get_frame_texture(vis.animation, vis.frame)
	elif vis is Sprite2D:
		tex = vis.texture

	var sc := Vector2.ONE
	var rot := 0.0
	var pos := player.global_position
	if vis:
		sc = vis.global_scale
		rot = vis.global_rotation
		pos = vis.global_position

	var off := Vector2.ZERO   # how far each half sits from the center, on screen

	if tex:
		var sz := tex.get_size()
		# Cut across the longer side of the picture (or always left/right)
		var cut_x := true
		if SPLIT_ACROSS_LONG_AXIS:
			cut_x = sz.x >= sz.y
		for i in 2:
			var s := Sprite2D.new()
			s.texture = tex
			s.region_enabled = true
			if cut_x:
				s.region_rect = Rect2(0.0 if i == 0 else sz.x / 2.0, 0, sz.x / 2.0, sz.y)
			else:
				s.region_rect = Rect2(0, 0.0 if i == 0 else sz.y / 2.0, sz.x, sz.y / 2.0)
			s.scale = sc
			s.rotation = rot
			halves.append(s)
		var local_off := Vector2(sz.x / 4.0, 0.0) if cut_x else Vector2(0.0, sz.y / 4.0)
		off = (local_off * sc).rotated(rot)
	else:
		# Fallback: plain rectangles, cut across the middle
		var full := Vector2(20.0, player.half_height * 2.0)
		for i in 2:
			var p := Polygon2D.new()
			var hw := full.x / 2.0
			var hh := full.y / 4.0
			p.polygon = PackedVector2Array([
				Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
			p.color = Color(0.9, 0.9, 0.9)
			halves.append(p)
		off = Vector2(0.0, full.y / 4.0)

	split_dir = off.normalized()
	print("split: sprite=", vis, " texture=", tex, " dir=", split_dir)

	# Add to the scene first, then position
	for h in halves:
		h.z_index = 5
		add_child(h)
	halves[0].global_position = pos - off
	halves[1].global_position = pos + off
	return halves

# Shake, then the two halves visibly pull apart
func _crack_open(halves: Array[Node2D]) -> void:
	var open := create_tween().set_parallel(true)
	open.tween_property(halves[0], "position", halves[0].position - split_dir * 14.0, 0.5)
	open.tween_property(halves[1], "position", halves[1].position + split_dir * 14.0, 0.5)
	for i in 10:
		for h in halves:
			h.set("offset", Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)))
		await get_tree().create_timer(0.05).timeout
	for h in halves:
		h.set("offset", Vector2.ZERO)
	await get_tree().create_timer(0.3).timeout    # hold on the split

# Halves tumble away and the ball falls with them
func _drop_everything(halves: Array[Node2D]) -> void:
	var floor_y := get_viewport_rect().size.y + 150.0
	var dirs := [-1.0, 1.0]
	for i in halves.size():
		var piece := halves[i]
		var t := create_tween().set_parallel(true)
		t.tween_property(piece, "position:y", floor_y, 1.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(piece, "position:x",
			piece.position.x + dirs[i] * randf_range(60.0, 140.0), 1.4)
		t.tween_property(piece, "rotation",
			piece.rotation + dirs[i] * randf_range(1.0, 2.2), 1.4)

	var bt := create_tween().set_parallel(true)
	bt.tween_property(ball, "position:y", floor_y, 1.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bt.tween_property(ball, "position:x", ball.position.x + randf_range(-40.0, 40.0), 1.5)
