extends Node3D

var camera: Camera3D
var yaw := 0.0
var pitch := -0.22
var mouse_sensitivity := 0.003
var move_speed := 18.0
var mouse_look := false
var status: Label

func _ready() -> void:
    _build_environment()
    _build_world()
    _build_camera()
    _build_ui()

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.06, 0.10, 0.17)
    sky_mat.sky_horizon_color = Color(0.58, 0.63, 0.65)
    sky_mat.ground_bottom_color = Color(0.025, 0.035, 0.035)
    sky_mat.ground_horizon_color = Color(0.30, 0.34, 0.32)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.55, 0.59, 0.57)
    env.fog_density = 0.0025
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 250.0
    add_child(sun)

func _material(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func _mesh_instance(mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    add_child(node)
    return node

func _build_world() -> void:
    var ground := PlaneMesh.new()
    ground.size = Vector2(420, 420)
    ground.subdivide_width = 40
    ground.subdivide_depth = 40
    _mesh_instance(ground, Vector3.ZERO, _material(Color(0.105, 0.20, 0.105), 1.0))

    var path := BoxMesh.new()
    path.size = Vector3(10, 0.12, 170)
    _mesh_instance(path, Vector3(0, 0.07, -5), _material(Color(0.26, 0.22, 0.16), 1.0))

    var water := PlaneMesh.new()
    water.size = Vector2(110, 70)
    var wm := _material(Color(0.035, 0.20, 0.28, 0.88), 0.12, 0.05)
    wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mesh_instance(water, Vector3(68, 0.18, -30), wm)

    for x in range(-9, 10):
        for z in range(-9, 10):
            if abs(x) < 2 or (x > 2 and z < 1 and z > -6):
                continue
            if (x * 13 + z * 7) % 3 == 0:
                _tree(Vector3(x * 10.0 + sin(z) * 2.0, 0, z * 10.0))

    _ruin(Vector3(-28, 0, -35))
    _ruin(Vector3(31, 0, 45))

func _tree(pos: Vector3) -> void:
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.45
    trunk.bottom_radius = 0.75
    trunk.height = 5.5
    _mesh_instance(trunk, pos + Vector3(0, 2.75, 0), _material(Color(0.19, 0.105, 0.045), 1.0))
    for i in range(3):
        var crown := SphereMesh.new()
        crown.radius = 2.5 - i * 0.35
        crown.height = (2.5 - i * 0.35) * 2.0
        _mesh_instance(crown, pos + Vector3((i-1)*0.6, 5.4 + i*0.8, (i%2)*0.5), _material(Color(0.055, 0.22 + i*0.025, 0.07), 0.95))

func _ruin(pos: Vector3) -> void:
    var stone := _material(Color(0.26, 0.27, 0.25), 0.95)
    for i in range(5):
        var pillar := BoxMesh.new()
        pillar.size = Vector3(2.2, 5.0 + (i%2)*2.0, 2.2)
        _mesh_instance(pillar, pos + Vector3(i*4.2, pillar.size.y/2.0, 0), stone)
    var lintel := BoxMesh.new()
    lintel.size = Vector3(19, 1.6, 2.4)
    _mesh_instance(lintel, pos + Vector3(8.4, 7.0, 0), stone)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 10, 24)
    camera.fov = 72
    camera.current = true
    add_child(camera)
    _apply_camera_rotation()

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.position = Vector2(18, 18)
    panel.size = Vector2(430, 82)
    panel.color = Color(0.015, 0.018, 0.022, 0.78)
    layer.add_child(panel)
    status = Label.new()
    status.position = Vector2(18, 12)
    status.text = "CIPHERED SOULS — REALISTIC RENDERER\nWASD move • Shift sprint • Q/E down/up • Hold RMB + mouse to look"
    panel.add_child(status)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        mouse_look = event.pressed
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_look else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and mouse_look:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
        _apply_camera_rotation()
    elif event is InputEventKey and event.keycode == KEY_ESCAPE:
        mouse_look = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _apply_camera_rotation() -> void:
    if camera:
        camera.rotation = Vector3(pitch, yaw, 0)

func _process(delta: float) -> void:
    if not camera:
        return
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis := camera.global_transform.basis
    var forward := -basis.z
    forward.y = 0
    forward = forward.normalized()
    var right := basis.x
    right.y = 0
    right = right.normalized()
    var dir := right * input.x + forward * -input.y
    if Input.is_action_pressed("move_up"):
        dir.y += 1
    if Input.is_action_pressed("move_down"):
        dir.y -= 1
    if dir.length() > 0:
        dir = dir.normalized()
    var speed := move_speed * (2.5 if Input.is_action_pressed("sprint") else 1.0)
    camera.position += dir * speed * delta
    camera.position.y = max(camera.position.y, 1.0)
    status.text = "CIPHERED SOULS — REALISTIC RENDERER\nWASD move • Shift sprint • Q/E down/up • Hold RMB + mouse to look   |   %.1f, %.1f, %.1f" % [camera.position.x, camera.position.y, camera.position.z]
