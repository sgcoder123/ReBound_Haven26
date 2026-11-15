extends Node2D

const MAX_SATURATION := 0.35
const PER_HIT := 0.02

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

func _ready() -> void:
	screen_w = get_viewport_rect().size.x
	center = get_viewport_rect().size / 2.0
	GameManager.set_saturation(0.0)
	opponent.ball = ball
	ball.hit_paddle.connect(_on_ball_hit_paddle)
	player.shattered.connect(on_paddle_shatter)
	_update_score()
	_serve(1.0)
	ball.hit_paddle.connect(_on_ball_hit_paddle)
	
func _physics_process(_delta: float) -> void:
	if ended or serving:
		return
	if ball.global_position.x < -20.0:        # got past the player
		opponent_score += 1
		_serve(-1.0)
	elif ball.global_position.x > screen_w + 20.0:  # got past the opponent
		player_score += 1
		_serve(1.0)

func _serve(dir_x: float) -> void:
	serving = true
	_update_score()
	ball.reset_to(center)
	await get_tree().create_timer(1.0).timeout
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
	print("chapter got hit from: ", paddle.name)
	
func _update_score() -> void:
	player_label.text = str(player_score)
	opponent_label.text = str(opponent_score)

func on_paddle_shatter() -> void:
	ended = true
	ball.set_physics_process(false)
	opponent.set_physics_process(false)
	GameManager.fade_saturation(0.0, 0.1)
	await get_tree().create_timer(1.5).timeout
	GameManager.next_chapter()
