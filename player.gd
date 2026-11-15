extends CharacterBody3D
# First-person controller: weighted movement, touch look, floating joystick, sprint, flashlight, knife viewmodel, hiding.
const WALK := 3.0
const SPRINT := 5.7
var g = null
var ui = null
var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var vm: Node3D
var col: CollisionShape3D
var vm_base := Vector3(0.3, -0.27, -0.55)
var vm_rest := Vector3(6.0, -14.0, 0.0)
var vm_busy := false
var yaw := 0.0
var pitch := 0.0
var stamina := 1.0
var tired := false
var rest_t := 0.0
var sprinting := false
var locked := true
var hidden := false
var hide_yaw := 0.0
var hide_back := Vector3.ZERO
var hide_flash_was := true
var noise := 0.0
var noise_ui := 0.0
var step_d := 0.0
var bob_t := 0.0
var shake_amt := 0.0
var fov_kick := 0.0
var fov_override := -1.0
var flash_on := true
var flick_t := 0.0
var fear := 0.0
var has_knife := false
var fl: Node3D
var sway := Vector2.ZERO
var prev_yaw := 0.0
var prev_pitch := 0.0
var br_t := 0.0
var hvel := Vector3.ZERO
var look_v := Vector2.ZERO
var air_t := 0.0
var land_dip := 0.0
var step_dip := 0.0
var lean := 0.0
var breath_t := 0.0

func _ready() -> void:
	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 160.0
	cam.fov = 75.0
	head.add_child(cam)
	cam.make_current()
	flash = SpotLight3D.new()
	flash.spot_range = 34.0
	flash.spot_angle = 32.0
	flash.spot_attenuation = 0.8
	flash.light_energy = 5.5
	flash.light_color = Color(1.0, 0.95, 0.82)
	flash.shadow_enabled = true
	fl = Node3D.new()
	fl.position = Vector3(-0.3, -0.26, -0.5)
	cam.add_child(fl)
	flash.position = Vector3(0.0, 0.02, -0.22)
	fl.add_child(flash)
	vm = Node3D.new()
	vm.position = vm_base
	vm.rotation_degrees = vm_rest
	vm.visible = false
	cam.add_child(vm)
	var kn = null
	if g != null and g.lv != null:
		kn = g.lv.knife_model(vm)
	if kn != null:
		kn.position = Vector3(0.0, 0.0, 0.0)
		kn.scale = Vector3.ONE * 0.7
		kn.rotation_degrees = Vector3(0.0, 0.0, 20.0)
	build_hands()

func piece(par: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)

func build_hands() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.1, 0.1, 0.12)
	metal.metallic = 0.8
	metal.roughness = 0.4
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(1.0, 0.95, 0.8)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.95, 0.7)
	lens.emission_energy_multiplier = 2.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.58, 0.5)
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.12, 0.1, 0.12)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.032
	tube.bottom_radius = 0.032
	tube.height = 0.24
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05
	cap.bottom_radius = 0.034
	cap.height = 0.07
	var disc := CylinderMesh.new()
	disc.top_radius = 0.042
	disc.bottom_radius = 0.042
	disc.height = 0.01
	var hand := SphereMesh.new()
	hand.radius = 0.05
	hand.height = 0.1
	var arm := BoxMesh.new()
	arm.size = Vector3(0.09, 0.09, 0.5)
	var half := Vector3(PI * 0.5, 0.0, 0.0)
	piece(fl, tube, metal, Vector3(0.0, 0.0, -0.02), half)
	piece(fl, cap, metal, Vector3(0.0, 0.0, -0.17), half)
	piece(fl, disc, lens, Vector3(0.0, 0.0, -0.21), half)
	piece(fl, hand, skin, Vector3(0.01, -0.05, 0.04))
	piece(fl, arm, sleeve, Vector3(0.03, -0.1, 0.32), Vector3(-0.25, 0.0, 0.0))
	piece(vm, hand, skin, Vector3(0.0, -0.025, 0.1))
	piece(vm, arm, sleeve, Vector3(0.0, -0.06, 0.38), Vector3(-0.12, 0.0, 0.0))

func toggle_flash() -> void:
	if hidden or locked:
		return
	flash_on = not flash_on
	flash.visible = flash_on
	Sfx.play("click", -4.0)

func jolt(k: float) -> void:
	shake_amt = maxf(shake_amt, 1.4 * k)
	fov_kick = 16.0 * k

func look_at_point(p: Vector3, dur: float) -> void:
	var d := p - head.global_position
	var yt := atan2(-d.x, -d.z)
	var pt := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_look_step.bind(yaw, yt, pitch, pt), 0.0, 1.0, dur)

func _look_step(v: float, y0: float, yt: float, p0: float, pt: float) -> void:
	yaw = lerp_angle(y0, yt, v)
	pitch = lerpf(p0, pt, v)

# ---------------------------------------------------------------- hiding
func enter_hide(pos: Vector3, face: Vector3) -> void:
	hidden = true
	locked = true
	hide_back = global_position
	hide_flash_was = flash_on
	flash_on = false
	flash.visible = false
	fl.visible = false
	vm.visible = false
	col.set_deferred("disabled", true)
	hvel = Vector3.ZERO
	velocity = Vector3.ZERO
	sprinting = false
	global_position = Vector3(pos.x, pos.y, pos.z)
	hide_yaw = atan2(-face.x, -face.z)
	yaw = hide_yaw
	pitch = 0.0

func exit_hide() -> void:
	hidden = false
	locked = false
	col.set_deferred("disabled", false)
	global_position = hide_back
	velocity = Vector3.ZERO
	flash_on = hide_flash_was
	flash.visible = flash_on
	fl.visible = true
	vm.visible = has_knife

func force_exit_hide() -> void:
	exit_hide()

# ---------------------------------------------------------------- per-frame
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
		air_t += delta
	else:
		if air_t > 0.3:
			land_dip = clampf(air_t * 0.25, 0.05, 0.2)
			Sfx.play("step", -6.0, 0.7)
		air_t = 0.0
		velocity.y = -0.5
	var mv := Vector2.ZERO
	var lk := Vector2.ZERO
	if ui != null:
		lk = ui.take_look()
		if not locked:
			mv = ui.move
	if not locked or hidden:
		look_v = look_v.lerp(lk, 0.75)
		yaw -= look_v.x * 0.0042
		pitch = clampf(pitch - look_v.y * 0.0042, -1.45, 1.45)
		if hidden:
			yaw = hide_yaw + clampf(wrapf(yaw - hide_yaw, -PI, PI), -0.6, 0.6)
			pitch = clampf(pitch, -0.3, 0.3)
	else:
		look_v = Vector2.ZERO
	rotation.y = yaw
	head.rotation.x = pitch
	noise = 0.0
	var spd := WALK
	var amt := mv.length()
	if locked:
		sprinting = false
	else:
		var want: bool = ui != null and ui.sprint and amt > 0.15 and not tired
		if want and stamina > 0.0:
			sprinting = true
			stamina -= delta * 0.2
			rest_t = 0.0
			spd = SPRINT
			if stamina <= 0.0:
				stamina = 0.0
				tired = true
		else:
			sprinting = false
			rest_t += delta
			if rest_t > 1.0:
				stamina = minf(1.0, stamina + delta * 0.14)
			if tired and stamina > 0.3:
				tired = false
		if tired:
			spd = WALK * 0.85
	var dir := transform.basis * Vector3(mv.x, 0.0, mv.y)
	dir = dir.limit_length(1.0)
	var acc := 12.0 if dir.length() > 0.05 else 16.0
	if locked:
		hvel = hvel.move_toward(Vector3.ZERO, 30.0 * delta)
	else:
		hvel = hvel.move_toward(dir * spd, acc * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	if not locked and amt > 0.15:
		noise = 16.0 if sprinting else 5.5
		if is_on_floor():
			step_d += hvel.length() * delta
			if step_d > (2.1 if sprinting else 1.6):
				step_d = 0.0
				step_dip = 0.035 if sprinting else 0.02
				Sfx.play("step", -9.0 if sprinting else -15.0, randf_range(0.85, 1.15))
	if hidden:
		noise = 0.0
	noise_ui = lerpf(noise_ui, noise, minf(1.0, delta * 8.0))
	move_and_slide()
	var speed_k := minf(hvel.length() / SPRINT, 1.0)
	bob_t += delta * (2.0 + hvel.length() * 1.5)
	br_t += delta
	land_dip = lerpf(land_dip, 0.0, minf(1.0, delta * 7.0))
	step_dip = lerpf(step_dip, 0.0, minf(1.0, delta * 12.0))
	var breathe := sin(br_t * 1.4) * (0.014 if tired else 0.005)
	head.position.y = 1.6 + sin(bob_t) * 0.045 * speed_k - land_dip - step_dip + breathe
	if hidden:
		head.position.y = 1.45 + breathe
	if tired and not locked:
		breath_t -= delta
		if breath_t <= 0.0:
			breath_t = 2.4
			Sfx.play("breath", -12.0, 1.1)
	var dyaw := wrapf(yaw - prev_yaw, -PI, PI)
	var dpit := pitch - prev_pitch
	prev_yaw = yaw
	prev_pitch = pitch
	sway = sway.lerp(Vector2(dyaw, dpit), minf(1.0, delta * 10.0))
	fl.rotation = Vector3(-sway.y * 3.0, -sway.x * 3.0, 0.0)
	lean = lerpf(lean, -mv.x * 0.02, minf(1.0, delta * 6.0))
	shake_amt = maxf(0.0, shake_amt - delta * 1.8)
	cam.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake_amt * 0.05
	cam.rotation.z = lean + cos(bob_t * 0.5) * 0.012 * speed_k + sin(Time.get_ticks_msec() * 0.01) * 0.004 * fear
	fov_kick = lerpf(fov_kick, 0.0, minf(1.0, delta * 6.0))
	var target := 75.0 - fear * 5.0 + fov_kick + (4.0 if sprinting else 0.0)
	if fov_override > 0.0:
		target = fov_override
	cam.fov = lerpf(cam.fov, target, minf(1.0, delta * (18.0 if fov_override > 0.0 else 8.0)))
	if flash_on and not hidden:
		flick_t -= delta
		if flick_t > 0.0:
			flash.visible = false
		else:
			flash.visible = true
			if randf() < fear * 0.012:
				flick_t = randf_range(0.05, 0.25)
	if has_knife and not vm_busy and not hidden:
		vm.position = vm_base + Vector3(sin(bob_t * 0.5) * 0.012, sin(bob_t) * 0.016 * speed_k + sin(br_t * 1.4) * 0.003, 0.0) + Vector3(-sway.x * 0.6, sway.y * 0.6, 0.0)
