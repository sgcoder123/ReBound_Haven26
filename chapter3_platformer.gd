extends Node3D
# RE:BOUND chapter 3: simple behind-the-player 3D course.
# All geometry is generated from Godot primitives: no paid assets required.

const MOVE_SPEED := 5.5
const JUMP_SPEED := 8.0
const GRAVITY := 19.0

var player: CharacterBody3D
var camera: Camera3D
var velocity_y := 0.0
var trophy: Area3D
var completed := false
var attempted_final_jump := false
var spawn_position := Vector3(0, 2.5, 2)

func _ready() -> void:
    _create_world()
    _create_player()
    _create_camera()
    _create_ui()

func _process(delta: float) -> void:
    if camera and player:
        var target := player.global_position + Vector3(0, 3.6, 8.0)
        camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 3.0))
        camera.look_at(player.global_position + Vector3(0, 1.0, -5.0), Vector3.UP)

func _physics_process(delta: float) -> void:
    if completed or not player:
        return
    var axis := Input.get_axis("ui_left", "ui_right")
    var forward := Input.get_axis("ui_down", "ui_up")
    var movement := Vector3(axis, 0, -forward)
    if movement.length() > 1.0:
        movement = movement.normalized()
    player.velocity.x = movement.x * MOVE_SPEED
    player.velocity.z = movement.z * MOVE_SPEED
    if player.is_on_floor():
        velocity_y = 0.0
        if Input.is_action_just_pressed("ui_accept"):
            velocity_y = JUMP_SPEED
    else:
        velocity_y -= GRAVITY * delta
    player.velocity.y = velocity_y
    player.move_and_slide()
    if player.global_position.y < -4.0 and player.global_position.z < -18.0:
        _fall_back_to_pong()
        return
    if player.global_position.y < -8.0:
        player.global_position = spawn_position
        player.velocity = Vector3.ZERO
        velocity_y = 0.0

func _mat(color: Color, glow := false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.05
    material.roughness = 0.75
    if glow:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 0.9
    return material

func _box(position: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
    var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
    root.position = position
    add_child(root)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.material_override = _mat(color)
    root.add_child(mesh)
    if solid:
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collider.shape = shape
        root.add_child(collider)
    return root

func _create_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("1fc1ffff")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("a783ff")
    env.ambient_light_energy = 0.8
    environment.environment = env
    add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 25, 0)
    light.light_color = Color("ff6ebd")
    light.light_energy = 1.0
    add_child(light)
    # Each separate platform is a real collidable 3D object.
    var platforms: Array[Array] = [
        [Vector3(0, 0, 0), Vector3(7, 0.7, 7)],
        [Vector3(0, 0.5, -7), Vector3(4.5, 0.7, 3.8)],
        [Vector3(2.5, 1.0, -12.5), Vector3(4.5, 0.7, 3.8)],
        [Vector3(-0.5, 1.5, -18), Vector3(5, 0.7, 4)],
        [Vector3(0, 2.0, -32), Vector3(7, 0.7, 5)],
    ]
    for i in platforms.size():
        var item: Array = platforms[i]
        var platform_position: Vector3 = item[0]
        var platform_size: Vector3 = item[1]
        _box(platform_position, platform_size, Color("5032ad") if i % 2 == 0 else Color("8954ef"))
        var platform_top: Vector3 = platform_position + Vector3(0.0, platform_size.y * 0.5 + 0.06, 0.0)
        _box(platform_top, Vector3(platform_size.x, 0.12, platform_size.z), Color("004aa2ff"), false)
    # Distant silhouettes for depth.
    for i in range(8):
        var x := -15.0 if i % 2 == 0 else 15.0
        _box(Vector3(x, -2.5, -float(i) * 5.0), Vector3(2.0, 8.0 + float(i % 3), 2.0), Color("21124a"), false)
    trophy = Area3D.new()
    trophy.position = Vector3(0, 3.9, -32)
    add_child(trophy)
    var collision := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.25
    collision.shape = sphere
    trophy.add_child(collision)
    var trophy_mesh := MeshInstance3D.new()
    var trophy_shape := CylinderMesh.new()
    trophy_shape.top_radius = 0.45
    trophy_shape.bottom_radius = 0.2
    trophy_shape.height = 1.1
    trophy_mesh.mesh = trophy_shape
    trophy_mesh.material_override = _mat(Color("ffe36e"), true)
    trophy.add_child(trophy_mesh)
    trophy.body_entered.connect(_on_trophy)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.position = spawn_position
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.7
    collision.shape = capsule
    player.add_child(collision)
    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(0.55, 0.7, 0.38)
    body.mesh = body_mesh
    body.position.y = -0.28
    body.material_override = _mat(Color("a89fffff"))
    player.add_child(body)
    # The original Pong ball is now the character's head.
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.43
    sphere.height = 0.86
    head.mesh = sphere
    head.position.y = 0.52
    head.material_override = _mat(Color("f7e8ff"))
    player.add_child(head)
    for side in [-1, 1]:
        var leg := MeshInstance3D.new()
        var leg_mesh := BoxMesh.new()
        leg_mesh.size = Vector3(0.16, 0.45, 0.18)
        leg.mesh = leg_mesh
        leg.position = Vector3(float(side) * 0.17, -0.67, 0)
        leg.material_override = _mat(Color("ff9d56"))
        player.add_child(leg)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 65.0
    camera.position = spawn_position + Vector3(0, 3.6, 8.0)
    add_child(camera)
    camera.look_at(player.position + Vector3(0, 1, -5), Vector3.UP)

func _create_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var label := Label.new()
    label.text = "ARROWS: MOVE  |  SPACE: JUMP  |  REACH THE GOLD"
    label.position = Vector2(20, 20)
    label.add_theme_color_override("font_color", Color("f5d6ff"))
    ui.add_child(label)

func _on_trophy(body: Node3D) -> void:
    if body != player or completed:
        return
    completed = true
    # Reaching the trophy also returns to the final Pong challenge.
    await get_tree().create_timer(0.8).timeout
    _return_to_pong()

func _fall_back_to_pong() -> void:
    if completed:
        return
    completed = true
    player.velocity = Vector3.ZERO
    await get_tree().create_timer(0.6).timeout
    _return_to_pong()

func _return_to_pong() -> void:
    var manager: Node = get_node_or_null("/root/GameManager")
    if manager != null:
        manager.set("final_pong", true)
        if manager.has_method("go_to_chapter"):
            manager.call("go_to_chapter", 0)
