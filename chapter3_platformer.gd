extends Node3D

const MOVE_SPEED := 6.5
const JUMP_SPEED := 9.0
const GRAVITY := 22.0
const PLATFORM_COUNT := 28
const FINAL_Z := -185.0
var player: CharacterBody3D
var camera: Camera3D
var trophy: Area3D
var velocity_y := 0.0
var introducing := true
var completed := false
var final_fall := false
var final_fall_time := 0.0
var elapsed := 0.0
var spawn_position := Vector3(0, 1.5, 2)
var checkpoint := Vector3(0, 1.5, 2)
var checkpoint_index := 0
var moving: Array[Dictionary] = []
var limbs: Array[Node3D] = []
var model: Node3D
var status: Label
var reveal_panel: MeshInstance3D

func _ready() -> void:
    _create_world()
    _create_player()
    _create_camera()
    _create_ui()
    _intro_reveal()

func _physics_process(delta: float) -> void:
    if introducing or completed:
        return
    elapsed += delta
    for item: Dictionary in moving:
        var node: Node3D = item.node
        if item.kind == "rotate":
            node.rotation.y = elapsed * float(item.speed)
        else:
            node.position = item.origin + item.axis * sin(elapsed * float(item.speed) + float(item.phase))
    if final_fall:
        final_fall_time += delta
        velocity_y = maxf(velocity_y - GRAVITY * delta, -30.0)
        player.velocity = Vector3(0, velocity_y, -2.0)
        player.move_and_slide()
        model.rotation.z = sin(final_fall_time * 0.7) * 0.2
        status.text = "SOMETIMES THE ONLY WAY FORWARD... IS DOWN."
        # A long, empty fall only at the ending; no floor or catch box.
        if final_fall_time > 7.0:
            completed = true
            _return_to_pong()
        return
    var axis := Input.get_axis("ui_left", "ui_right")
    var forward := Input.get_axis("ui_down", "ui_up")
    var movement := Vector3(axis, 0, -forward).limit_length(1.0)
    player.velocity.x = movement.x * MOVE_SPEED
    player.velocity.z = movement.z * MOVE_SPEED
    if player.is_on_floor():
        velocity_y = 0.0
        if Input.is_action_just_pressed("ui_accept"):
            velocity_y = JUMP_SPEED
            _gm().fx.play_sfx("jump", -10.0)
    else:
        velocity_y -= GRAVITY * delta
    player.velocity.y = velocity_y
    player.move_and_slide()
    _animate_player(movement, delta)
    var progress := clampf(-player.position.z / 162.0, 0.0, 1.0)
    status.text = "RE:BOUND  |  ARROWS / SPACE  |  COURSE %d%%  |  CHECKPOINT %d  |  R: RETRY" % [int(progress * 100.0), checkpoint_index]
    if player.position.z < -159.0 and player.position.y < -1.8:
        final_fall = true
        final_fall_time = 0.0
        _gm().fx.buildup(7.0)
    elif player.position.y < -10.0:
        _respawn()

func _process(delta: float) -> void:
    if introducing or not camera or not player:
        return
    var target := player.global_position + Vector3(0, 3.8, 8.5)
    camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
    camera.look_at(player.global_position + Vector3(0, 0.8, -4.0), Vector3.UP)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and not introducing and not completed:
        _respawn()

func _respawn() -> void:
    final_fall = false
    final_fall_time = 0.0
    velocity_y = 0.0
    player.velocity = Vector3.ZERO
    player.global_position = checkpoint
    camera.global_position = checkpoint + Vector3(0, 3.8, 8.5)
    model.rotation = Vector3.ZERO
    _gm().fx.play_sfx("break", -12.0)

func _mat(color: Color, glow := false) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.6
    if glow:
        result.emission_enabled = true
        result.emission = color
        result.emission_energy_multiplier = 0.8
    return result

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow := false) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _mat(color, glow)
    parent.add_child(visual)
    return visual

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    return _mesh(parent, shape, pos, color)

func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    return _mesh(parent, shape, pos, color)

func _create_world() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("0b0925")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("b397ff")
    environment.ambient_light_energy = 0.8
    world.environment = environment
    add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40, -25, 0)
    light.light_color = Color("ffc4e9")
    add_child(light)
    for i in PLATFORM_COUNT:
        var x := 0.0 if i == 0 or i % 6 == 0 else sin(float(i) * 1.1) * 1.8
        var pos := Vector3(x, 0.0, -float(i) * 6.0)
        var size := Vector3(6, 0.45, 4.5)
        if i == 0:
            size = Vector3(7, 0.45, 7)
        var platform := AnimatableBody3D.new()
        platform.sync_to_physics = false
        platform.position = pos
        platform.name = "Platform_%02d" % i
        add_child(platform)
        _box(platform, size, Vector3.ZERO, Color("5032ad") if i % 2 == 0 else Color("8954ef"))
        _box(platform, Vector3(size.x, 0.07, 0.14), Vector3(0, 0.26, size.z * 0.5), Color("ff9e42"))
        _box(platform, Vector3(size.x, 0.07, 0.14), Vector3(0, 0.26, -size.z * 0.5), Color("ff4fd8"))
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        collider.shape = box
        platform.add_child(collider)
        if i > 3 and i % 6 == 3:
            moving.append({"node": platform, "kind": "slide", "origin": pos, "axis": Vector3(1.1, 0, 0), "speed": 0.8, "phase": float(i)})
        if i > 2 and i % 6 == 2:
            _add_hazard(pos + Vector3(0, 0.7, 0), false)
        if i > 4 and i % 6 == 5:
            _add_hazard(pos + Vector3(0, 0.6, 0), true)
        if i > 0 and i % 6 == 0:
            _add_checkpoint(pos, i / 6)
    # End island is intentionally beyond a normal jump. No floor exists below.
    var end := StaticBody3D.new()
    end.position = Vector3(0, 0, FINAL_Z)
    add_child(end)
    _box(end, Vector3(6, 0.45, 5), Vector3.ZERO, Color("8954ef"))
    var col := CollisionShape3D.new()
    var end_shape := BoxShape3D.new()
    end_shape.size = Vector3(6, 0.45, 5)
    col.shape = end_shape
    end.add_child(col)
    trophy = Area3D.new()
    trophy.position = Vector3(0, 1.7, FINAL_Z)
    add_child(trophy)
    var trophy_col := CollisionShape3D.new()
    var trophy_shape := SphereShape3D.new()
    trophy_shape.radius = 1.0
    trophy_col.shape = trophy_shape
    trophy.add_child(trophy_col)
    var cup := CylinderMesh.new()
    cup.top_radius = 0.6
    cup.bottom_radius = 0.2
    cup.height = 0.7
    _mesh(trophy, cup, Vector3(0, 0.25, 0), Color("ffe36e"), true)
    _box(trophy, Vector3(0.15, 0.5, 0.15), Vector3(0, -0.25, 0), Color("ffe36e"))
    _box(trophy, Vector3(0.7, 0.15, 0.7), Vector3(0, -0.55, 0), Color("ff9e42"))
    trophy.body_entered.connect(_on_trophy)
    var message := Label3D.new()
    message.text = "ONE LAST LEAP"
    message.position = Vector3(0, 3.8, -161)
    message.font_size = 54
    message.pixel_size = 0.009
    add_child(message)

func _add_checkpoint(pos: Vector3, index: int) -> void:
    var trigger := Area3D.new()
    trigger.position = pos + Vector3(0, 1, 0)
    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(5, 2.5, 3.5)
    col.shape = box
    trigger.add_child(col)
    add_child(trigger)
    var beacon := CylinderMesh.new()
    beacon.top_radius = 0.12
    beacon.bottom_radius = 0.12
    beacon.height = 2.0
    _mesh(trigger, beacon, Vector3(-2.5, 0, 0), Color("ffe36e"), true)
    trigger.body_entered.connect(func(body: Node3D):
        if body == player and index > checkpoint_index:
            checkpoint_index = index
            checkpoint = pos + Vector3(0, 1.4, 1.0)
            _gm().fx.play_sfx("jump", -9.0)
    )

func _add_hazard(pos: Vector3, spinning: bool) -> void:
    var hazard := Area3D.new()
    hazard.position = pos
    hazard.collision_layer = 0
    hazard.collision_mask = 1
    add_child(hazard)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(4.5, 0.3, 0.35) if spinning else Vector3(0.6, 1.0, 0.65)
    col.shape = shape
    hazard.add_child(col)
    _box(hazard, shape.size, Vector3.ZERO, Color("ff4f6e"))
    moving.append({"node": hazard, "kind": "rotate" if spinning else "slide", "origin": pos, "axis": Vector3(2.8, 0, 0), "speed": 1.5, "phase": 0.0})
    hazard.body_entered.connect(func(body: Node3D):
        if body == player and not final_fall and not completed:
            call_deferred("_respawn")
    )

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.position = spawn_position
    player.floor_snap_length = 0.3
    add_child(player)
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.32
    shape.height = 1.75
    col.shape = shape
    player.add_child(col)
    model = Node3D.new()
    player.add_child(model)
    # Rounded spacesuit, helmet, visor, backpack, articulated arms/legs.
    var torso := CapsuleMesh.new()
    torso.radius = 0.3
    torso.height = 0.8
    _mesh(model, torso, Vector3(0, -0.05, 0), Color("ff9e42"))
    _sphere(model, 0.4, Vector3(0, 0.57, 0), Color("f7e8ff"))
    var visor := _sphere(model, 0.32, Vector3(0, 0.59, -0.2), Color("20133f"))
    visor.scale = Vector3(1, 0.6, 0.55)
    for x: float in [-0.11, 0.11]:
        _sphere(model, 0.045, Vector3(x, 0.6, -0.375), Color("ffe36e"))
    _box(model, Vector3(0.3, 0.38, 0.17), Vector3(0, 0, 0.3), Color("5032ad"))
    _box(model, Vector3(0.23, 0.17, 0.08), Vector3(0, 0.04, -0.29), Color("ffe36e"))
    for i in 4:
        var pivot := Node3D.new()
        var arm := i < 2
        var side := -1.0 if i % 2 == 0 else 1.0
        pivot.position = Vector3(side * (0.39 if arm else 0.15), 0.12 if arm else -0.37, 0)
        model.add_child(pivot)
        limbs.append(pivot)
        var capsule := CapsuleMesh.new()
        capsule.radius = 0.105 if arm else 0.13
        capsule.height = 0.48
        _mesh(pivot, capsule, Vector3(0, -0.2, 0), Color("f7e8ff") if arm else Color("8954ef"))
        _sphere(pivot, 0.12, Vector3(0, -0.42, 0), Color("ff9e42"))
        if not arm:
            _box(pivot, Vector3(0.24, 0.14, 0.35), Vector3(0, -0.45, -0.07), Color("f7e8ff"))

func _animate_player(movement: Vector3, delta: float) -> void:
    var amount := movement.length()
    if amount > 0.05:
        model.rotation.y = lerp_angle(model.rotation.y, atan2(-movement.x, -movement.z), 1.0 - exp(-12.0 * delta))
    for i in limbs.size():
        limbs[i].rotation.x = sin(elapsed * 11.0 + (0.0 if i in [0, 3] else PI)) * 0.55 * amount if player.is_on_floor() else (-0.6 if i < 2 else 0.3)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 65.0
    camera.position = spawn_position + Vector3(0, 3.8, 8.5)
    add_child(camera)
    camera.look_at(spawn_position + Vector3(0, 0.8, -4), Vector3.UP)

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    status = Label.new()
    status.position = Vector2(18, 16)
    status.add_theme_color_override("font_color", Color("f7e8ff"))
    status.add_theme_font_size_override("font_size", 17)
    status.text = "A NEW DIMENSION"
    layer.add_child(status)

func _on_trophy(body: Node3D) -> void:
    if body == player and not completed:
        completed = true
        _return_to_pong()

func _return_to_pong() -> void:
    _gm().fx.reveal()
    _gm().final_pong = true
    _gm().go_to_chapter(0)

func _intro_reveal() -> void:
    _gm().fx.play_music()
    _gm().fx.buildup(4.0)
    camera.position = spawn_position + Vector3(0, 1, 14)
    camera.look_at(spawn_position + Vector3(0, 1, 0), Vector3.UP)
    if _gm().transition_image:
        reveal_panel = MeshInstance3D.new()
        var quad := QuadMesh.new()
        var height := 20.0 * tan(deg_to_rad(camera.fov * 0.5))
        quad.size = Vector2(height * get_viewport().get_visible_rect().size.aspect(), height)
        reveal_panel.mesh = quad
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.albedo_texture = _gm().transition_image
        reveal_panel.material_override = material
        reveal_panel.position = spawn_position + Vector3(0, 1, 4)
        add_child(reveal_panel)
        _gm().transition_image = null
    var tween := create_tween()
    tween.tween_method(_reveal_frame, 0.0, 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished
    if is_instance_valid(reveal_panel):
        reveal_panel.queue_free()
    introducing = false
    _gm().fx.reveal()

func _reveal_frame(progress: float) -> void:
    camera.position = spawn_position + Vector3(sin(progress * PI) * 11.0, lerpf(1.0, 3.8, progress), lerpf(14.0, 8.5, progress))
    camera.look_at(spawn_position + Vector3(0, 1, lerpf(0.0, -4.0, progress)), Vector3.UP)
    if is_instance_valid(reveal_panel):
        (reveal_panel.material_override as StandardMaterial3D).albedo_color.a = 1.0 - smoothstep(0.08, 0.7, progress)

func _gm() -> Node:
    return get_node("/root/GameManager")
