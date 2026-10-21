extends Node3D

# Football 3D Starter: a small, original, touch-controlled football prototype.
# Move by dragging the left side of the screen; use the buttons on the right.

var player: CharacterBody3D
var ball: RigidBody3D
var opponent: CharacterBody3D
var camera_3d: Camera3D
var score_label: Label
var message_label: Label
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_active := false
var score := 0
var opponent_score := 0
var time_left := 90.0
var ended := false
var ball_start := Vector3(0, 0.55, 3.0)
var player_start := Vector3(0, 0.9, 4.0)
var opponent_start := Vector3(0, 0.9, -3.0)

func _ready() -> void:
    _build_field()
    _build_player()
    _build_opponent()
    _build_ball()
    _build_camera()
    _build_lighting()
    _build_ui()
    _reset_positions()

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _add_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi

func _build_field() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "Pitch"
    var plane := PlaneMesh.new()
    plane.size = Vector2(18, 30)
    ground.mesh = plane
    ground.position.y = 0
    ground.material_override = _mat(Color(0.07, 0.42, 0.18))
    add_child(ground)

    # Alternating grass stripes
    for i in range(6):
        var stripe := MeshInstance3D.new()
        var stripe_mesh := BoxMesh.new()
        stripe_mesh.size = Vector3(18, 0.015, 2.5)
        stripe.mesh = stripe_mesh
        stripe.position = Vector3(0, 0.012, -12.5 + i * 5)
        stripe.material_override = _mat(Color(0.09, 0.47, 0.20) if i % 2 == 0 else Color(0.06, 0.39, 0.16))
        add_child(stripe)

    var white := Color(0.92, 0.96, 0.91)
    # Boundary and halfway lines
    _add_box(self, "TouchlineLeft", Vector3(0.09, 0.035, 30), Vector3(-8.8, 0.035, 0), white)
    _add_box(self, "TouchlineRight", Vector3(0.09, 0.035, 30), Vector3(8.8, 0.035, 0), white)
    _add_box(self, "GoalLineNorth", Vector3(17.6, 0.035, 0.09), Vector3(0, 0.035, -14.8), white)
    _add_box(self, "GoalLineSouth", Vector3(17.6, 0.035, 0.09), Vector3(0, 0.035, 14.8), white)
    _add_box(self, "HalfwayLine", Vector3(17.6, 0.035, 0.07), Vector3(0, 0.04, 0), white)
    # Penalty boxes
    for z in [-11.7, 11.7]:
        _add_box(self, "PenaltyTop", Vector3(8.5, 0.035, 0.07), Vector3(0, 0.04, z), white)
        for x in [-4.25, 4.25]:
            _add_box(self, "PenaltySide", Vector3(0.07, 0.035, 3.1), Vector3(x, 0.04, z + (1.55 if z < 0 else -1.55)), white)
    # Goals
    for z in [-14.4, 14.4]:
        for x in [-2.0, 2.0]:
            _add_box(self, "GoalPost", Vector3(0.12, 1.7, 0.12), Vector3(x, 0.85, z), Color(0.95, 0.95, 0.95))
        _add_box(self, "GoalBar", Vector3(4.0, 0.12, 0.12), Vector3(0, 1.7, z), Color(0.95, 0.95, 0.95))

    # Center circle approximated with small white segments
    for i in range(40):
        var a := TAU * float(i) / 40.0
        var dot := MeshInstance3D.new()
        var dm := BoxMesh.new()
        dm.size = Vector3(0.12, 0.025, 0.12)
        dot.mesh = dm
        dot.position = Vector3(cos(a) * 2.0, 0.04, sin(a) * 2.0)
        dot.material_override = _mat(white)
        add_child(dot)

func _make_character(name: String, jersey: Color, number: String) -> CharacterBody3D:
    var body := CharacterBody3D.new()
    body.name = name
    var capsule := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = 0.38
    cm.height = 1.45
    capsule.mesh = cm
    capsule.position.y = 0.9
    capsule.material_override = _mat(jersey, 0.45)
    body.add_child(capsule)
    var head := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.23
    sm.height = 0.46
    head.mesh = sm
    head.position.y = 1.78
    head.material_override = _mat(Color(0.77, 0.54, 0.38))
    body.add_child(head)
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.6
    collider.shape = shape
    collider.position.y = 0.85
    body.add_child(collider)
    add_child(body)
    return body

func _build_player() -> void:
    player = _make_character("Player10", Color(0.85, 0.08, 0.15), "10")

func _build_opponent() -> void:
    opponent = _make_character("Opponent", Color(0.92, 0.92, 0.92), "2")

func _build_ball() -> void:
    ball = RigidBody3D.new()
    ball.name = "Football"
    ball.mass = 0.45
    ball.gravity_scale = 1.0
    ball.linear_damp = 0.7
    ball.angular_damp = 0.7
    var sphere := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.28
    mesh.height = 0.56
    sphere.mesh = mesh
    sphere.material_override = _mat(Color(0.98, 0.98, 0.94), 0.35)
    ball.add_child(sphere)
    var collider := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.28
    collider.shape = shape
    ball.add_child(collider)
    add_child(ball)

func _build_camera() -> void:
    camera_3d = Camera3D.new()
    camera_3d.name = "FollowCamera"
    camera_3d.position = Vector3(0, 13, 12)
    camera_3d.rotation_degrees = Vector3(-42, 0, 0)
    camera_3d.current = true
    add_child(camera_3d)

func _build_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.25
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.72, 0.78, 0.85)
    e.ambient_light_energy = 0.65
    env.environment = e
    add_child(env)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.015, 0.07, 0.035, 0.78)
    panel.position = Vector2(12, 12)
    panel.size = Vector2(320, 76)
    layer.add_child(panel)

    score_label = Label.new()
    score_label.text = "Football 3D   |   0 - 0   |   90"
    score_label.position = Vector2(24, 22)
    score_label.add_theme_font_size_override("font_size", 23)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(score_label)

    message_label = Label.new()
    message_label.text = "اسحب يسار الشاشة للتحرك"
    message_label.position = Vector2(24, 48)
    message_label.add_theme_font_size_override("font_size", 15)
    message_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.83))
    panel.add_child(message_label)

    var shoot := Button.new()
    shoot.text = "تسديد"
    shoot.custom_minimum_size = Vector2(112, 72)
    shoot.position = Vector2(-132, -102)
    shoot.anchor_left = 1.0
    shoot.anchor_right = 1.0
    shoot.anchor_top = 1.0
    shoot.anchor_bottom = 1.0
    shoot.add_theme_font_size_override("font_size", 22)
    shoot.pressed.connect(_shoot)
    layer.add_child(shoot)

    var pass_btn := Button.new()
    pass_btn.text = "تمرير"
    pass_btn.custom_minimum_size = Vector2(94, 62)
    pass_btn.position = Vector2(-238, -88)
    pass_btn.anchor_left = 1.0
    pass_btn.anchor_right = 1.0
    pass_btn.anchor_top = 1.0
    pass_btn.anchor_bottom = 1.0
    pass_btn.add_theme_font_size_override("font_size", 18)
    pass_btn.pressed.connect(_pass)
    layer.add_child(pass_btn)

func _reset_positions() -> void:
    player.global_position = player_start
    opponent.global_position = opponent_start
    ball.global_position = ball_start
    ball.linear_velocity = Vector3.ZERO
    ball.angular_velocity = Vector3.ZERO

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.58:
            joystick_active = true
            joystick_origin = event.position
            joystick_vector = Vector2.ZERO
        elif not event.pressed:
            joystick_active = false
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and joystick_active:
        var delta: Vector2 = event.position - joystick_origin
        joystick_vector = delta.limit_length(90.0) / 90.0
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_W or event.keycode == KEY_UP:
            joystick_vector.y = -1
        elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
            joystick_vector.y = 1
        elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
            joystick_vector.x = -1
        elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
            joystick_vector.x = 1
        elif event.keycode == KEY_SPACE:
            _shoot()

func _physics_process(delta: float) -> void:
    if ended:
        return
    time_left -= delta
    if time_left <= 0:
        time_left = 0
        ended = true
        message_label.text = "انتهت المباراة! أعد تشغيل اللعبة للمحاولة مجددًا"
    score_label.text = "Football 3D   |   %d - %d   |   %d" % [score, opponent_score, int(time_left)]

    var move := Vector3(joystick_vector.x, 0, joystick_vector.y)
    if move.length() > 1:
        move = move.normalized()
    player.velocity.x = move.x * 5.4
    player.velocity.z = move.z * 5.4
    player.velocity.y = 0
    player.move_and_slide()
    player.global_position.x = clampf(player.global_position.x, -8.0, 8.0)
    player.global_position.z = clampf(player.global_position.z, -13.8, 13.8)

    # Opponent slowly presses toward the ball
    var to_ball := ball.global_position - opponent.global_position
    to_ball.y = 0
    if to_ball.length() > 0.8:
        opponent.velocity.x = to_ball.normalized().x * 2.3
        opponent.velocity.z = to_ball.normalized().z * 2.3
    else:
        opponent.velocity = Vector3.ZERO
    opponent.velocity.y = 0
    opponent.move_and_slide()
    opponent.global_position.x = clampf(opponent.global_position.x, -8.0, 8.0)
    opponent.global_position.z = clampf(opponent.global_position.z, -13.8, 13.8)

    # Gentle camera follow centered on the player's half
    var target := player.global_position + Vector3(0, 12, 10)
    camera_3d.global_position = camera_3d.global_position.lerp(target, delta * 2.0)
    camera_3d.look_at(player.global_position + Vector3(0, 0, -2), Vector3.UP)

    # Keep ball within pitch
    if ball.global_position.y < -3:
        _reset_positions()
    if ball.global_position.z < -14.6 and absf(ball.global_position.x) < 2.0:
        score += 1
        message_label.text = "جوووول! 🎉"
        _reset_positions()
    elif ball.global_position.z > 14.6 and absf(ball.global_position.x) < 2.0:
        opponent_score += 1
        message_label.text = "الخصم سجّل!"
        _reset_positions()

func _shoot() -> void:
    if ended:
        return
    var direction := Vector3(joystick_vector.x, 0.15, joystick_vector.y)
    if direction.length() < 0.25:
        direction = Vector3(0, 0.18, -1)
    direction = direction.normalized()
    var distance := ball.global_position.distance_to(player.global_position)
    if distance > 3.0:
        message_label.text = "قرّب اللاعب من الكرة أولًا"
        return
    ball.sleeping = false
    ball.apply_central_impulse(direction * 8.5 + Vector3(0, 1.0, 0))
    message_label.text = "تسديدة!"

func _pass() -> void:
    if ended:
        return
    var distance := ball.global_position.distance_to(player.global_position)
    if distance > 3.0:
        message_label.text = "قرّب اللاعب من الكرة أولًا"
        return
    var direction := Vector3(joystick_vector.x, 0.08, joystick_vector.y)
    if direction.length() < 0.25:
        direction = Vector3(0, 0.05, -1)
    ball.sleeping = false
    ball.apply_central_impulse(direction.normalized() * 4.2)
    message_label.text = "تمريرة!"
