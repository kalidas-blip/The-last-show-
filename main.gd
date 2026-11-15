extends Node3D
# THE LAST SHOW - first-person carnival horror. Flow, story, scares, hiding. The world itself lives in level.gd.
const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float fear = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0, 0.0, 0.0);
uniform float glitch = 0.0;
uniform float tm = 0.0;
float hsh(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float d = dot(c, c);
	uv.x += glitch * (hsh(vec2(floor(uv.y * 36.0), floor(tm * 18.0))) - 0.5) * 0.09;
	vec2 off = c * (0.012 + fear * 0.02 + glitch * 0.05);
	vec3 col;
	col.r = texture(scr, uv + off).r;
	col.g = texture(scr, uv).g;
	col.b = texture(scr, uv - off).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(1.0, 0.92, 0.9), 0.2 + fear * 0.35);
	col *= 1.0 - smoothstep(0.1, 0.6, d) * (0.8 + fear * 0.5);
	col += (hsh(SCREEN_UV * 900.0 + tm) - 0.5) * 0.06;
	col = mix(col, flash_col, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""
var lv = null
var player = null
var clown = null
var ui = null
var post: ShaderMaterial
var env: Environment
var hb: AudioStreamPlayer
var amb: AudioStreamPlayer
var cine: Camera3D
var patrol_pts: Array = []
var statues: Array = []
var win_done := [false, false]
var car_state := 0
var car_snd: AudioStreamPlayer3D = null
var state := "loading"
var busy := false
var busy_scare := false
var paused := false
var prompt := ""
var target = null
var objective := ""
var msg := ""
var msg_t := 0.0
var kill_t := 0.0
var end_t := 0.0
var destroyed := 0
var has_knife := false
var has_key := false
var final_stage := false
var gate_open := false
var lamps_on := true
var black_hold := false
var scare_t := 24.0
var amb_t := 12.0
var lock_msg_t := 0.0
var respawn_t := -1.0
var phone_t := 0.0
var phone_done := false
var last_alert := -10.0
var laughed := false
var last_cp := Vector3.ZERO
var fear := 0.0
var flash_a := 0.0
var flash_c := Color(1, 0, 0)
var glitch := 0.0
var bars := 0.0
var t := 0.0
var hiding := false
var hide_idx := -1
var hide_seen := false
var silence := false
var anomaly_cd := 10.0
var last_scare := -1
var trick_t := 9.0
var near_cry := false

# ---------------------------------------------------------------- setup
func _ready() -> void:
	randomize()
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_SHADER
	post = ShaderMaterial.new()
	post.shader = sh
	cr.material = post
	pl.add_child(cr)
	var ul := CanvasLayer.new()
	ul.layer = 3
	add_child(ul)
	ui = (load("res://ui.gd") as GDScript).new()
	ui.g = self
	ul.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	build_all()
	await get_tree().physics_frame
	await get_tree().physics_frame
	state = "menu"

func make_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.26, 0.4)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.09, 0.14)
	env.fog_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.9)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)

func build_all() -> void:
	make_env()
	lv = (load("res://level.gd") as GDScript).new()
	add_child(lv)
	lv.build()
	patrol_pts = lv.patrol_pts
	player = (load("res://player.gd") as GDScript).new()
	player.g = self
	player.ui = ui
	add_child(player)
	player.global_position = lv.spawn
	last_cp = lv.spawn
	build_dust()
	build_rain()
	clown = (load("res://clown.gd") as GDScript).new()
	clown.g = self
	clown.player = player
	add_child(clown)
	clown.deactivate()
	for spot in lv.statue_spots:
		var gh = ghost_at(spot[0])
		gh.tint(true)
		statue_pose(gh, 0)
		statues.append({"node": gh, "mode": spot[1], "stage": 0, "unseen": 0.0, "cool": 0.0})
	amb = Sfx.loop2d("ambience", -4.0)
	hb = Sfx.loop2d("heart", -60.0)
	objective = "Find the knife"

func build_dust() -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 4
	sm.rings = 2
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.0, 0.95, 0.8, 0.35)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = pm
	p.mesh = sm
	p.amount = 120
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14.0, 3.0, 14.0)
	p.direction = Vector3(0.3, 0.1, 0.2)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	p.position = Vector3(0.0, 1.8, 0.0)
	player.add_child(p)

func build_rain() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.55, 0.012)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.7, 0.8, 1.0, 0.28)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = pm
	p.mesh = bm
	p.amount = 500
	p.lifetime = 0.9
	p.preprocess = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18.0, 0.5, 18.0)
	p.direction = Vector3(0.1, -1.0, 0.0)
	p.spread = 2.0
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.position = Vector3(0.0, 12.0, 0.0)
	player.add_child(p)

# ---------------------------------------------------------------- frame loop
func _process(delta: float) -> void:
	t += delta
	if state == "loading":
		return
	lv.update(delta, t, player.global_position)
	lv.lamps_update(delta, t, lamps_on)
	for h in lv.hearts:
		if h.alive:
			var sp: AudioStreamPlayer3D = h.snd
			var ph := fmod(sp.get_playback_position(), 0.9)
			var k := exp(-ph * 12.0) * 0.28
			if ph > 0.27:
				k += exp(-(ph - 0.27) * 14.0) * 0.18
			var bd: Node3D = h.body
			bd.scale = Vector3(1.0 + k * 0.55, 1.0 + k * 0.9, 1.0 + k * 0.55)
			bd.rotation.y += delta * 0.6
			var gm = bd.get_meta("glow")
			gm.albedo_color = Color(1.0, 0.05, 0.05, clampf(k * 1.4, 0.0, 0.5))
			h.light.light_energy = 2.2 + k * 6.0
			var hp: Vector3 = h.pos
			h.node.position = Vector3(hp.x, hp.y + sin(t * 1.5) * 0.05, hp.z)
	if black_hold:
		flash_a = 1.0
		flash_c = Color.BLACK
	else:
		flash_a = maxf(0.0, flash_a - delta * 2.2)
	glitch = maxf(0.0, glitch - delta * 2.5)
	post.set_shader_parameter("fear", fear)
	post.set_shader_parameter("flash", flash_a)
	post.set_shader_parameter("flash_col", Vector3(flash_c.r, flash_c.g, flash_c.b))
	post.set_shader_parameter("glitch", glitch)
	post.set_shader_parameter("tm", fmod(t, 100.0))
	msg_t -= delta
	kill_t -= delta
	bars = move_toward(bars, 1.0 if busy else 0.0, delta * 1.6)
	if not has_knife:
		lv.knife_node.rotation.y += delta * 0.9
		lv.knife_node.position = Vector3(lv.knife_at.x, lv.knife_at.y + sin(t * 2.0) * 0.06, lv.knife_at.z)
	lv.gate_lock.rotation.z = sin(t * 2.0) * 0.03
	if state == "menu":
		player.yaw += delta * 0.07
		player.pitch = 0.05
		return
	if state == "end":
		end_t += delta
		if end_t > 5.0 and not laughed:
			laughed = true
			Sfx.play("laugh", 4.0, 0.55)
			flash_c = Color(0.6, 0.0, 0.0)
			flash_a = 0.5
		return
	if state != "play":
		return
	update_fear(delta)
	update_prompt()
	update_jacks()
	update_statues(delta)
	update_windows()
	update_carousel()
	update_checkpoints()
	update_anomalies(delta)
	update_cry(delta)
	director(delta)
	if not phone_done and not has_knife:
		phone_t += delta
		if phone_t > 30.0:
			phone_done = true
			phone_scare()
	amb_t -= delta
	if amb_t < 0.0 and not silence:
		amb_t = randf_range(9.0, 20.0)
		var a := randf() * TAU
		var p: Vector3 = player.global_position + Vector3(sin(a), 0.0, cos(a)) * randf_range(18.0, 34.0)
		var roll := randf()
		if roll < 0.3:
			Sfx.play3d("laugh", p, -8.0, randf_range(0.6, 1.4))
		elif roll < 0.45:
			Sfx.play3d("pop", p, -4.0, randf_range(0.6, 1.0))
		elif roll < 0.6:
			Sfx.play3d("chain", p, -6.0, randf_range(0.7, 1.1))
		elif roll < 0.75:
			Sfx.play3d("drip", p, -2.0, randf_range(0.7, 1.2))
		else:
			pop_balloon()
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0 and not final_stage and has_knife:
			var far: Vector3 = patrol_pts[0]
			for q in patrol_pts:
				if q.distance_to(player.global_position) > far.distance_to(player.global_position):
					far = q
			clown.activate(far, "patrol")
	lock_msg_t -= delta
	if not has_key and lock_msg_t <= 0.0 and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(0.0, lv.gate_z)) < 8.0:
		lock_msg_t = 12.0
		say("The gate is chained shut.", 3.0)
	if gate_open and player.global_position.z < lv.gate_z - 3.0:
		ending()

func update_checkpoints() -> void:
	for cp in lv.checkpoints:
		if player.global_position.distance_to(cp) < 9.0 and cp != last_cp:
			last_cp = cp
			say("Checkpoint", 1.5)

func update_fear(delta: float) -> void:
	var target_f := 0.0
	if clown.state in ["chase", "search", "patrol", "stun", "investigate"]:
		var d: float = clown.global_position.distance_to(player.global_position)
		target_f = clampf(1.0 - d / 24.0, 0.0, 1.0)
		if clown.state == "chase":
			target_f = maxf(target_f, 0.35)
			if d < 7.0:
				player.shake_amt = maxf(player.shake_amt, (1.0 - d / 7.0) * 0.5)
	if hiding:
		target_f = maxf(target_f, 0.3)
	fear = lerpf(fear, target_f, minf(1.0, delta * 2.0))
	player.fear = fear
	hb.volume_db = -60.0 if silence else linear_to_db(maxf(fear, 0.0005)) + 4.0
	hb.pitch_scale = 0.85 + fear * 0.8

func say(text: String, secs: float = 3.5) -> void:
	msg = text
	msg_t = secs + 1.0

func consider(p: Vector3, r: float, dotmin: float, label: String, tg) -> void:
	if prompt != "":
		return
	var d: Vector3 = p - player.cam.global_position
	if d.length() < r and d.normalized().dot(-player.cam.global_transform.basis.z) > dotmin:
		prompt = label
		target = tg

func update_prompt() -> void:
	prompt = ""
	target = null
	if busy:
		return
	if hiding:
		prompt = "LEAVE"
		target = "unhide"
		return
	if not has_knife:
		consider(lv.knife_node.global_position + Vector3(0.0, 0.1, 0.0), 3.4, 0.4, "TAKE", "knife")
	else:
		for h in lv.hearts:
			if h.alive:
				consider(h.pos, 3.5, 0.55, "STAB", h)
	if final_stage and not has_key and clown.state == "cry":
		consider(clown.global_position + Vector3(0.0, 1.0, 0.0), 3.6, 0.45, "KILL", "clown")
	if has_key and not gate_open:
		consider(Vector3(0.0, 1.5, lv.gate_z + 0.5), 5.5, 0.2, "OPEN", "gate")
	if prompt == "" and nearest_hide() >= 0 and clown.state != "caught":
		prompt = "HIDE"
		target = "hide"

func interact() -> void:
	if state != "play" or busy or prompt == "":
		return
	var tg = target
	if tg is String:
		if tg == "knife":
			take_knife()
		elif tg == "clown":
			execute_clown()
		elif tg == "gate":
			open_gate()
		elif tg == "hide":
			enter_hide()
		elif tg == "unhide":
			leave_hide()
	elif tg is Dictionary:
		kill_heart(tg)

func update_jacks() -> void:
	for j in lv.jacks:
		var d: float = player.global_position.distance_to(j.pos)
		if j.st == 0 and d < 9.0:
			j.st = 1
			j.snd = Sfx.loop3d("musicbox", j.head, -6.0, 5.0)
		elif j.st == 1 and d < 2.4:
			j.st = 2
			if j.snd != null:
				j.snd.stop()
			Sfx.play("spring", 2.0)
			Sfx.play("sting", 1.0)
			jolt(0.8)
			var lt := create_tween()
			lt.tween_property(j.lid, "rotation_degrees:x", -110.0, 0.08)
			var ht := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ht.tween_property(j.head, "position:y", 1.1, 0.14)
		elif j.st == 2:
			j.head.rotation = Vector3(0.0, 0.0, sin(t * 8.0) * 0.16)

# ---------------------------------------------------------------- helpers
func wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout

func slowmo(scale: float, real_sec: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(real_sec, true, false, true).timeout
	Engine.time_scale = 1.0

func jolt(k: float, c: Color = Color(1.0, 0.05, 0.05)) -> void:
	flash_a = clampf(0.65 * k, 0.0, 1.0)
	flash_c = c
	glitch = clampf(0.8 * k, 0.0, 1.0)
	player.jolt(k)
	Sfx.buzz(int(120.0 * k))

func player_fwd() -> Vector3:
	var f: Vector3 = -player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func looking_at(p: Vector3, dotmin: float) -> bool:
	var d: Vector3 = (p - player.cam.global_position).normalized()
	return d.dot(-player.cam.global_transform.basis.z) > dotmin

func find_spot(center: Vector3, dist: float, dir: Vector3, cone: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	for k in 14:
		var a := atan2(dir.x, dir.z) + randf_range(-cone, cone)
		var p := center + Vector3(sin(a), 0.0, cos(a)) * dist
		if absf(p.x) > 96.0 or absf(p.z) > 96.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(center + Vector3(0.0, 1.4, 0.0), p + Vector3(0.0, 1.4, 0.0), 1)
		q.exclude = [player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return p
	return center + dir * 3.0

func ghost_at(p: Vector3):
	var gh = (load("res://clown.gd") as GDScript).new()
	gh.ghost = true
	lv.add_child(gh)
	gh.global_position = p
	return gh

func flicker_lamps(sec: float) -> void:
	var left := sec
	while left > 0.0:
		lamps_on = randf() > 0.45
		var dt := randf_range(0.05, 0.2)
		await wait(dt)
		left -= dt
	lamps_on = true

func blackout(sec: float) -> void:
	lamps_on = false
	player.flash_on = false
	player.flash.visible = false
	create_tween().tween_property(env, "ambient_light_energy", 0.12, 0.4)
	await wait(sec)
	lamps_on = true
	player.flash_on = true
	player.flash.visible = true
	Sfx.play("click", -2.0)
	create_tween().tween_property(env, "ambient_light_energy", 0.5, 0.3)

func particles(pos: Vector3, col: Color, amount: int, vmin: float, vmax: float, grav: Vector3, size: float, life: float) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = pm
	p.mesh = sm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	var gr := Gradient.new()
	gr.colors = PackedColorArray([col, Color(col.r, col.g, col.b, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = gr
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)

func ring(pos: Vector3, col: Color, size: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

func pop_balloon() -> void:
	for e in lv.balloons:
		var n: Node3D = e[0]
		var d := n.global_position.distance_to(player.global_position)
		if n.visible and d > 6.0 and d < 26.0:
			n.visible = false
			Sfx.play3d("pop", n.global_position, 2.0, randf_range(0.8, 1.1))
			particles(n.global_position, Color(1.0, 0.3, 0.3), 8, 1.0, 3.0, Vector3(0.0, -3.0, 0.0), 0.04, 0.8)
			return

func cine_shake(k: float) -> void:
	if cine == null:
		return
	var tw := create_tween()
	for i in 6:
		tw.tween_property(cine, "h_offset", randf_range(-1.0, 1.0) * 0.3 * k * (1.0 - i / 6.0), 0.04)
	tw.tween_property(cine, "h_offset", 0.0, 0.05)

func heart_blood(pos: Vector3, k: float) -> void:
	var dirv: Vector3 = player.global_position - pos
	dirv.y = 0.0
	dirv = (dirv.normalized() * 0.8 + Vector3(0.0, 0.5, 0.0)).normalized()
	lv.blood_spray(pos, dirv, int(34.0 * k), 6.5 * k)
	lv.splat_floor(Vector3(pos.x, 0.0, pos.z), 1.2 * k)

func impact(pos: Vector3, k: float) -> void:
	Sfx.play("stab", 4.0, randf_range(0.9, 1.05))
	Sfx.play("squelch", 2.0, randf_range(0.8, 1.1))
	if k > 1.2:
		Sfx.play("crunch", 3.0)
	jolt(0.9 * k, Color(1.0, 0.1, 0.1))
	ui.splat(int(3.0 * k) + 1)
	heart_blood(pos, k)
	particles(pos, Color(0.65, 0.0, 0.02), int(30.0 * k), 2.0, 6.0 * k, Vector3(0.0, -9.0, 0.0), 0.05, 0.9)
	ring(pos, Color(1.0, 0.2, 0.1, 0.9), 3.0 * k, 0.6)

func arterial(pos: Vector3, n: int) -> void:
	for i in n:
		await wait(0.17)
		lv.blood_spray(pos, Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)), 16, 8.0)
		Sfx.play("squelch", -6.0, randf_range(0.9, 1.3))

# ---------------------------------------------------------------- hiding
func nearest_hide() -> int:
	var best := -1
	var bd := 3.0
	for i in lv.hide_spots.size():
		var hp: Vector3 = lv.hide_spots[i]["pos"]
		var fc: Vector3 = lv.hide_spots[i]["face"]
		var off: Vector3 = player.global_position - hp
		var d := Vector2(off.x, off.z).length()
		if d < bd and off.dot(fc) > 0.2:
			bd = d
			best = i
	return best

func enter_hide() -> void:
	var i := nearest_hide()
	if i < 0:
		return
	hiding = true
	hide_idx = i
	hide_seen = clown.state == "chase" and clown.sees_now
	player.enter_hide(lv.hide_spots[i]["pos"], lv.hide_spots[i]["face"])
	Sfx.play("slam", -12.0, 1.3)
	if hide_seen:
		say("He saw you. Don't move.", 3.0)

func leave_hide() -> void:
	hiding = false
	hide_idx = -1
	player.exit_hide()
	Sfx.play("slam", -14.0, 1.4)

func pull_from_hide() -> void:
	hiding = false
	hide_idx = -1
	player.force_exit_hide()
	player_caught()

# ---------------------------------------------------------------- story beats
func take_knife() -> void:
	has_knife = true
	player.has_knife = true
	player.vm.visible = true
	lv.knife_node.visible = false
	Sfx.play("shing", 2.0)
	Sfx.buzz(40)
	objective = "Destroy the clown's 5 hearts. Listen for the heartbeats."
	say("Read the plaques. He hid his hearts where the laughter was loudest.", 5.0)
	knife_scare()

func knife_scare() -> void:
	busy_scare = true
	await wait(3.0)
	if state != "play":
		busy_scare = false
		return
	Sfx.play("riser", -2.0)
	blackout(3.4)
	Sfx.play3d("laugh", player.global_position - player_fwd() * 7.0, -4.0, 0.6)
	await wait(3.5)
	if state != "play" or busy:
		busy_scare = false
		return
	var pos := find_spot(player.global_position, 9.0, player_fwd(), 0.35)
	clown.activate(pos, "chase")
	clown.face_dir(player.global_position - pos)
	Sfx.play("sting", 4.0)
	jolt(1.2)
	busy_scare = false

func clown_alert() -> void:
	if t - last_alert < 6.0:
		return
	last_alert = t
	Sfx.play3d("laugh", clown.global_position, 3.0, randf_range(0.7, 0.9))
	jolt(0.4)

func player_caught() -> void:
	if state != "play" or busy or final_stage:
		return
	if hiding:
		hiding = false
		hide_idx = -1
		player.force_exit_hide()
	state = "dead"
	busy = true
	clown.state = "caught"
	player.locked = true
	var fwd := player_fwd()
	clown.global_position = player.global_position + fwd * 1.1
	clown.face_dir(-fwd)
	clown.eye_on(3.0)
	clown.morph_to = 1.0
	player.look_at_point(clown.global_position + Vector3(0.0, 2.0, 0.0), 0.1)
	player.fov_override = 100.0
	Sfx.play("sting", 8.0)
	Sfx.play("scream", 6.0)
	jolt(1.6)
	ui.splat(22)
	Sfx.buzz(400)
	await wait(1.7)
	black_hold = true
	await wait(0.4)
	state = "dead_wait"

func respawn() -> void:
	Engine.time_scale = 1.0
	black_hold = false
	flash_a = 1.0
	flash_c = Color.BLACK
	player.global_position = last_cp
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0
	player.fov_override = -1.0
	player.locked = false
	player.hidden = false
	player.stamina = 1.0
	player.flash_on = true
	player.flash.visible = true
	clown.eye_on(0.25)
	clown.deactivate()
	lamps_on = true
	busy = false
	busy_scare = false
	hiding = false
	silence = false
	state = "play"
	respawn_t = 8.0
	scare_t = 16.0
	say("Run. Hide. Find the hearts.", 3.0)

func kill_heart(h: Dictionary) -> void:
	busy = true
	h.alive = false
	player.locked = true
	player.vm_busy = true
	clown.hold(true)
	var pos: Vector3 = h.pos
	var dirv: Vector3 = pos - player.global_position
	dirv.y = 0.0
	dirv = dirv.normalized()
	var stand := Vector3(pos.x, player.global_position.y, pos.z) - dirv * 1.5
	player.look_at_point(pos, 0.5)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(player, "global_position", stand, 0.5)
	await wait(0.55)
	var vm: Node3D = player.vm
	var w := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	w.tween_property(vm, "position", Vector3(0.1, 0.05, -0.4), 0.45)
	w.tween_property(vm, "rotation_degrees", Vector3(70.0, 0.0, 0.0), 0.45)
	Sfx.play("riser", -6.0)
	await wait(0.7)
	var s1 := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	s1.tween_property(vm, "position", Vector3(0.0, -0.12, -0.9), 0.16)
	s1.tween_property(vm, "rotation_degrees", Vector3(-35.0, 0.0, 0.0), 0.16)
	await wait(0.17)
	impact(pos, 1.0)
	slowmo(0.3, 0.45)
	await wait(0.3)
	var s2a := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	s2a.tween_property(vm, "position", Vector3(0.1, 0.0, -0.45), 0.25)
	s2a.tween_property(vm, "rotation_degrees", Vector3(65.0, 0.0, 20.0), 0.25)
	await wait(0.3)
	var s2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	s2.tween_property(vm, "position", Vector3(0.0, -0.14, -0.95), 0.14)
	s2.tween_property(vm, "rotation_degrees", Vector3(-40.0, 0.0, -25.0), 0.14)
	await wait(0.15)
	impact(pos, 1.8)
	Sfx.play("boom", 3.0)
	Sfx.play("scream", -2.0, 0.7)
	Sfx.play("crunch", 2.0)
	h.snd.stop()
	h.light.light_energy = 9.0
	lv.blood_pool(Vector3(pos.x, 0.0, pos.z), 1.5, 2.5)
	arterial(pos, 5)
	particles(pos, Color(1.6, 0.6, 0.15), 40, 3.0, 9.0, Vector3(0.0, 2.5, 0.0), 0.05, 1.4)
	particles(pos, Color(0.7, 0.0, 0.02), 60, 2.0, 7.0, Vector3(0.0, -9.0, 0.0), 0.06, 1.0)
	for i in 3:
		ring(pos, Color(1.0, 0.25, 0.1, 0.9), 7.0 + i * 3.0, 0.9)
		await wait(0.16)
	var shrink := create_tween().set_parallel(true)
	shrink.tween_property(h.node, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	shrink.tween_property(h.light, "light_energy", 0.0, 0.9)
	await wait(0.9)
	h.node.queue_free()
	var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	back.tween_property(vm, "position", player.vm_base, 0.5)
	back.tween_property(vm, "rotation_degrees", player.vm_rest, 0.5)
	await wait(0.6)
	destroyed += 1
	clown.aggression = destroyed
	player.locked = false
	player.vm_busy = false
	busy = false
	clown.hold(false)
	if destroyed >= 5:
		final_sequence()
	else:
		objective = "Hearts destroyed: %d / 5" % destroyed
		clown_rage()

func clown_rage() -> void:
	busy_scare = true
	Sfx.play("scream", 0.0, 0.8)
	flicker_lamps(2.0)
	await wait(1.7)
	if state != "play" or busy:
		busy_scare = false
		return
	var pos := find_spot(player.global_position, 13.0, player_fwd(), 0.7)
	clown.bonus = destroyed * 0.35
	clown.activate(pos, "chase")
	clown.stun(1.0)
	Sfx.play("sting", 2.0)
	jolt(0.9)
	busy_scare = false

func final_sequence() -> void:
	busy_scare = true
	Sfx.play("scream", 4.0, 0.7)
	jolt(1.0)
	flicker_lamps(3.0)
	await wait(1.6)
	clown.deactivate()
	var best: Vector3 = lv.kneel_pts[0]
	for p in lv.kneel_pts:
		if p.distance_to(player.global_position) > best.distance_to(player.global_position):
			best = p
	await wait(1.4)
	clown.activate(best, "cry")
	final_stage = true
	kill_t = 5.0
	Sfx.play("boom", -4.0)
	glitch = 0.6
	objective = "Follow the crying. Find the clown."
	busy_scare = false

func shot(pos: Vector3, tgt: Vector3, fov: float) -> void:
	cine.global_position = pos
	cine.look_at(tgt, Vector3.UP)
	cine.fov = fov

func _orbit(v: float, center: Vector3, radius: float, a0: float) -> void:
	if cine == null:
		return
	var a := a0 + v * 1.4
	cine.global_position = center + Vector3(sin(a) * radius, 1.4 + v * 0.7, cos(a) * radius)
	cine.look_at(center + Vector3(0.0, 1.2, 0.0), Vector3.UP)

func make_cine_knife() -> Node3D:
	var k := Node3D.new()
	add_child(k)
	var km: Node3D = lv.knife_model(k)
	km.rotation.z = PI * 0.5
	lv.omni(k, Vector3(0.0, 0.2, 0.0), Color(1.0, 0.95, 0.85), 1.5, 4.0)
	k.scale = Vector3.ONE * 2.6
	k.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	return k

func make_key() -> Node3D:
	var k := Node3D.new()
	add_child(k)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.11
	var ri := MeshInstance3D.new()
	ri.mesh = tm
	ri.material_override = lv.mats["gold"]
	ri.position = Vector3(0.0, 0.22, 0.0)
	ri.rotation_degrees.x = 90.0
	k.add_child(ri)
	lv.pillar(k, 0.025, 0.4, Vector3.ZERO, lv.mats["gold"], false)
	lv.box(k, Vector3(0.1, 0.05, 0.03), Vector3(0.06, -0.15, 0.0), lv.mats["gold"], 0.0, false)
	lv.box(k, Vector3(0.07, 0.05, 0.03), Vector3(0.045, -0.07, 0.0), lv.mats["gold"], 0.0, false)
	lv.omni(k, Vector3.ZERO, Color(1.0, 0.8, 0.2), 2.5, 5.0)
	k.scale = Vector3.ONE * 1.6
	return k

func execute_clown() -> void:
	busy = true
	player.locked = true
	player.vm.visible = false
	kill_t = 0.0
	objective = ""
	var K: Vector3 = clown.global_position
	var f: Vector3 = player.global_position - K
	f.y = 0.0
	f = f.normalized()
	var r := f.cross(Vector3.UP)
	clown.face_dir(f)
	cine = Camera3D.new()
	add_child(cine)
	cine.make_current()
	shot(K + r * 2.6 + Vector3(0.0, 0.5, 0.0) + f * 5.0, K + Vector3(0.0, 1.0, 0.0), 60.0)
	var d1 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d1.tween_property(cine, "global_position", K + r * 1.3 + Vector3(0.0, 0.8, 0.0) + f * 3.2, 2.6)
	await wait(2.5)
	shot(K + r * 0.3 + Vector3(0.0, 1.35, 0.0) + f * 1.6, K + Vector3(0.0, 1.4, 0.0) + f * 0.2, 36.0)
	clown.silence_cry()
	clown.lift_head()
	clown.eye_on(3.0)
	Sfx.play("riser", 0.0)
	var d2 := create_tween().set_trans(Tween.TRANS_SINE)
	d2.tween_property(cine, "global_position", K + r * 0.1 + Vector3(0.0, 1.38, 0.0) + f * 1.0, 2.2)
	await wait(1.6)
	Sfx.play3d("whisper", K + Vector3(0.0, 1.4, 0.0), -2.0, 0.8)
	clown.morph_to = 0.35
	await wait(0.9)
	var ck := make_cine_knife()
	shot(K - r * 0.4 + Vector3(0.0, 0.7, 0.0) + f * 2.4, K + Vector3(0.0, 2.0, 0.0), 45.0)
	ck.global_position = K + r * 0.5 + Vector3(0.0, 0.9, 0.0) + f * 1.0
	var d3 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	d3.tween_property(ck, "global_position", K + r * 0.1 + Vector3(0.0, 3.0, 0.0) + f * 0.3, 1.2)
	await wait(1.5)
	shot(K + r * 1.8 + Vector3(0.0, 0.9, 0.0) + f * 1.0, K + Vector3(0.0, 1.2, 0.0), 48.0)
	var chest := K + Vector3(0.0, 1.15, 0.0) + f * 0.25
	ck.global_position = chest + Vector3(0.0, 2.0, 0.0)
	var d4 := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	d4.tween_property(ck, "global_position", chest + Vector3(0.0, 0.62, 0.0), 0.16)
	await wait(0.17)
	Sfx.play("stab", 6.0, 0.8)
	Sfx.play("squelch", 5.0)
	Sfx.play("boom", 5.0)
	Sfx.play("scream", 2.0, 0.75)
	jolt(1.6, Color(1.0, 0.1, 0.1))
	cine_shake(1.8)
	ui.splat(26)
	var spray: Vector3 = (r * 0.5 + f * 0.9 + Vector3(0.0, 0.5, 0.0)).normalized()
	lv.blood_spray(chest, spray, 70, 8.0)
	lv.blood_pool(Vector3(K.x, 0.0, K.z), 1.6, 3.0)
	slowmo(0.2, 0.9)
	await wait(0.5)
	shot(K - r * 1.5 + Vector3(0.0, 1.2, 0.0) + f * 1.2, chest, 42.0)
	var rip := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	rip.tween_property(ck, "global_position", chest + Vector3(0.0, 1.05, 0.1), 0.9)
	clown.morph_to = 1.0
	for i in 4:
		await wait(0.2)
		Sfx.play("squelch", 3.0, randf_range(0.8, 1.2))
		lv.blood_spray(chest + Vector3(0.0, 0.2 * i, 0.0), (f + Vector3(0.0, 0.6, 0.0)).normalized(), 28, 7.0)
		cine_shake(0.8)
	Sfx.play("crunch", 4.0)
	Sfx.play("scream", 3.0, 0.6)
	lv.blood_spray(K + Vector3(0.0, 1.7, 0.0) + f * 0.3, f, 40, 6.0)
	ui.splat(18)
	await wait(0.5)
	var hbody: Node3D = lv.heart_mesh(self)
	hbody.global_position = chest
	hbody.scale = Vector3.ONE * 1.5
	lv.omni(hbody, Vector3.ZERO, Color(1.0, 0.05, 0.08), 3.0, 6.0)
	var hk := make_key()
	hbody.add_child(hk)
	hk.scale = Vector3.ONE * 0.5
	shot(chest + Vector3(0.0, 0.7, 0.0) + f * 1.3 + r * 0.4, chest + Vector3(0.0, 0.7, 0.0), 34.0)
	var up := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	up.tween_property(hbody, "global_position", chest + Vector3(0.0, 0.75, 0.25), 1.5)
	up.tween_property(hbody, "scale", Vector3.ONE * 2.1, 1.5)
	var gm = hbody.get_meta("glow")
	for i in 7:
		await wait(0.2)
		Sfx.play("squelch", -2.0, 0.7)
		gm.albedo_color = Color(1.0, 0.05, 0.05, 0.8)
		hbody.scale = hbody.scale * 1.12
		await wait(0.09)
		gm.albedo_color = Color(1.0, 0.05, 0.05, 0.0)
		hbody.scale = hbody.scale / 1.12
		lv.blood_spray(hbody.global_position, Vector3.DOWN + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4)), 8, 2.5)
	clown.collapse(1.4)
	ck.queue_free()
	await wait(0.4)
	Sfx.play("boom", 6.0)
	jolt(1.4, Color(1.0, 0.85, 0.5))
	ring(hbody.global_position, Color(1.0, 0.5, 0.15, 0.95), 12.0, 1.2)
	ring(hbody.global_position, Color(1.0, 0.1, 0.05, 0.9), 8.0, 0.9)
	particles(hbody.global_position, Color(1.6, 0.7, 0.2), 80, 3.0, 9.0, Vector3(0.0, 3.0, 0.0), 0.05, 1.8)
	lv.blood_spray(hbody.global_position, Vector3.UP, 60, 9.0)
	var key := make_key()
	key.global_position = hbody.global_position
	hbody.queue_free()
	var orb := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	orb.tween_method(_orbit.bind(K, 3.8, 0.6), 0.0, 1.0, 4.0)
	var kt := create_tween().set_parallel(true)
	kt.tween_property(key, "global_position", chest + Vector3(0.0, 1.3, 0.0), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kt.tween_property(key, "rotation:y", TAU * 2.0, 1.6)
	Sfx.play("keys", 0.0)
	lv.blood_pool(Vector3(K.x, 0.0, K.z), 3.0, 3.5)
	await wait(1.4)
	clown.dissolve()
	particles(K + Vector3(0.0, 0.6, 0.0), Color(0.25, 0.25, 0.28), 70, 1.0, 5.0, Vector3(0.0, 2.0, 0.0), 0.08, 2.0)
	await wait(1.6)
	create_tween().tween_property(key, "global_position", cine.global_position, 0.5).set_ease(Tween.EASE_IN)
	await wait(0.5)
	key.queue_free()
	cine.queue_free()
	cine = null
	player.cam.make_current()
	player.vm.visible = true
	clown.deactivate()
	has_key = true
	objective = "Escape through the main gate"
	say("GATE KEY OBTAINED", 4.0)
	flicker_lamps(1.5)
	player.locked = false
	busy = false

func open_gate() -> void:
	gate_open = true
	Sfx.play("keys", 0.0)
	await wait(0.9)
	Sfx.play("gate", 3.0)
	lv.gate_lock.visible = false
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lv.gate_l, "rotation_degrees:y", 100.0, 3.8)
	tw.tween_property(lv.gate_r, "rotation_degrees:y", -100.0, 3.8)
	lv.gate_light.light_color = Color(0.2, 1.0, 0.3)
	objective = "RUN! Get out!"
	jolt(0.5)
	gate_scare()

func gate_scare() -> void:
	busy_scare = true
	await wait(2.2)
	if state != "play":
		busy_scare = false
		return
	blackout(2.6)
	Sfx.play("riser", -2.0)
	var gh = ghost_at(Vector3(0.0, 0.0, lv.gate_z - 15.0))
	gh.face_dir(Vector3(0.0, 0.0, 1.0))
	gh.freeze_pose("roar", 0.5)
	await wait(2.9)
	Sfx.play("sting", 3.0)
	jolt(0.8)
	await wait(0.8)
	Sfx.play3d("laugh", gh.global_position, 3.0, 0.7)
	gh.queue_free()
	busy_scare = false

func ending() -> void:
	if state != "play":
		return
	state = "end"
	end_t = 0.0
	player.locked = true
	flash_c = Color.WHITE
	flash_a = 1.0

# ---------------------------------------------------------------- directing the scares
func director(delta: float) -> void:
	if busy or busy_scare or hiding or silence:
		return
	scare_t -= delta
	if scare_t > 0.0:
		return
	if clown.state == "chase" or clown.state == "investigate":
		scare_t = 6.0
		return
	scare_t = maxf(9.0, randf_range(14.0, 30.0) - destroyed * 2.5)
	var pick := randi() % 11
	if pick == last_scare:
		pick = (pick + 3) % 11
	last_scare = pick
	match pick:
		0:
			scare_front()
		1:
			scare_behind()
		2:
			scare_apparition()
		3:
			scare_dash()
		4:
			scare_flicker()
		5:
			scare_flashwalk()
		6:
			silence_event()
		7:
			hallucinate()
		8:
			scare_fake()
		9:
			scare_stalker()
		_:
			scare_fake()

func scare_front() -> void:
	busy_scare = true
	Sfx.play3d("laugh", player.global_position - player_fwd() * 5.0, -6.0, 0.7)
	await wait(1.1)
	if state != "play" or busy or hiding:
		busy_scare = false
		return
	var fwd := player_fwd()
	var gh = ghost_at(find_spot(player.global_position, 9.0, fwd, 0.15))
	gh.face_dir(player.global_position - gh.global_position)
	gh.run_anim = true
	gh.morph_to = 0.9
	Sfx.play("sting", 3.0)
	jolt(1.0)
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).tween_property(gh, "global_position", player.global_position + fwd * 1.3, 0.22)
	await wait(0.5)
	gh.queue_free()
	busy_scare = false

func scare_behind() -> void:
	busy_scare = true
	Sfx.play3d("breath", player.global_position - player_fwd() * 1.2, 0.0, 0.9, 3.0)
	await wait(1.6)
	if state != "play" or busy or hiding:
		busy_scare = false
		return
	var back := -player_fwd()
	var gh = ghost_at(player.global_position + back * 2.0)
	gh.face_dir(-back)
	gh.morph_to = 1.0
	Sfx.play("sting", 3.0)
	jolt(1.1)
	Sfx.play3d("laugh", gh.global_position, 3.0, 1.2)
	await wait(0.7)
	gh.queue_free()
	busy_scare = false

func scare_apparition() -> void:
	busy_scare = true
	var p := find_spot(player.global_position, randf_range(18.0, 25.0), player_fwd(), 0.6)
	if p.distance_to(player.global_position) < 10.0:
		busy_scare = false
		return
	var gh = ghost_at(p)
	gh.freeze_pose("idle", 0.0)
	var seen := 0.0
	var life := 0.0
	while is_instance_valid(gh) and state == "play" and not busy:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		life += dt
		gh.face_dir(player.global_position - gh.global_position)
		if looking_at(gh.global_position + Vector3(0.0, 1.4, 0.0), 0.92):
			seen += dt
		if seen > 1.3 or life > 16.0 or gh.global_position.distance_to(player.global_position) < 10.0:
			break
	if is_instance_valid(gh):
		Sfx.play3d("laugh", gh.global_position, 0.0, 1.1)
		flicker_lamps(0.8)
		gh.queue_free()
	busy_scare = false

func scare_stalker() -> void:
	busy_scare = true
	var p := find_spot(player.global_position, 28.0, player_fwd(), 0.8)
	var gh = ghost_at(p)
	statue_pose(gh, 0)
	var unseen := 0.0
	var moves := 0
	while is_instance_valid(gh) and state == "play" and not busy and moves < 4:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		if looking_at(gh.global_position + Vector3(0.0, 1.4, 0.0), 0.8):
			unseen = 0.0
		else:
			unseen += dt
			if unseen > 0.9:
				unseen = 0.0
				moves += 1
				var d: float = gh.global_position.distance_to(player.global_position)
				var dirv: Vector3 = player.global_position - gh.global_position
				dirv.y = 0.0
				dirv = dirv.normalized()
				var step := clampf(d - 6.0, 0.0, 8.0)
				gh.global_position = gh.global_position + dirv * step
				gh.face_dir(dirv)
				statue_pose(gh, moves)
				Sfx.play3d("scrape", gh.global_position, -6.0, randf_range(0.8, 1.2))
	if state == "play" and not busy:
		Sfx.play3d("laugh", player.global_position - player_fwd() * 3.0, 2.0, 1.0)
		jolt(0.5)
	if is_instance_valid(gh):
		gh.queue_free()
	busy_scare = false

func scare_dash() -> void:
	busy_scare = true
	var fwd := player_fwd()
	var side := fwd.cross(Vector3.UP)
	var c: Vector3 = player.global_position + fwd * 13.0
	var a := c - side * 15.0
	var b := c + side * 15.0
	var gh = ghost_at(a)
	gh.run_anim = true
	gh.morph_to = 0.3
	gh.face_dir(b - a)
	Sfx.play3d("laugh", a, 0.0, 1.0)
	create_tween().tween_property(gh, "global_position", b, 1.5)
	await wait(1.55)
	gh.queue_free()
	busy_scare = false

func scare_flicker() -> void:
	busy_scare = true
	Sfx.play3d("laugh", player.global_position + player_fwd() * 10.0, -4.0, 0.6)
	await flicker_lamps(2.2)
	busy_scare = false

func scare_flashwalk() -> void:
	busy_scare = true
	var fwd := player_fwd()
	var gh = ghost_at(find_spot(player.global_position, 16.0, fwd, 0.3))
	gh.freeze_pose("idle", 0.0)
	gh.face_dir(player.global_position - gh.global_position)
	Sfx.play("riser", -4.0)
	var ok := true
	for step in [10.0, 5.5, 2.0]:
		await wait(1.0)
		if state != "play" or busy or hiding:
			ok = false
			break
		player.flash_on = false
		player.flash.visible = false
		await wait(0.2)
		var np: Vector3 = player.global_position + player_fwd() * step
		gh.global_position = Vector3(np.x, 0.0, np.z)
		gh.face_dir(player.global_position - gh.global_position)
		player.flash_on = true
		player.flash.visible = true
		Sfx.play("click", -2.0)
	player.flash_on = true
	player.flash.visible = true
	if ok:
		gh.morph_to = 1.0
		Sfx.play("sting", 4.0)
		jolt(1.2)
		await wait(0.45)
	gh.queue_free()
	busy_scare = false

func silence_event() -> void:
	busy_scare = true
	silence = true
	create_tween().tween_property(amb, "volume_db", -60.0, 1.4)
	await wait(randf_range(6.0, 9.0))
	if state != "play":
		silence = false
		busy_scare = false
		return
	silence = false
	create_tween().tween_property(amb, "volume_db", -4.0, 0.15)
	if randf() < 0.55:
		await wait(randf_range(0.4, 1.4))
		if state == "play" and not busy and not hiding:
			await scare_behind()
	busy_scare = false

func hallucinate() -> void:
	busy_scare = true
	var k := randi() % 4
	if k == 0:
		var back := -player_fwd()
		for i in 6:
			Sfx.play3d("step", player.global_position + back * (9.0 - i * 1.4), 1.0, 0.65, 5.0)
			await wait(0.5)
		await wait(1.0)
		Sfx.play3d("breath", player.global_position + back * 0.7, 2.0, 0.9, 2.0)
	elif k == 1:
		var side := player_fwd().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		Sfx.play3d("whisper", player.global_position + side * 1.0, 4.0, randf_range(0.8, 1.1), 3.0)
	elif k == 2:
		var kp: Vector3 = player.global_position + player_fwd() * 6.0 + player_fwd().cross(Vector3.UP) * 3.0
		Sfx.play3d("knock", kp, 3.0)
		await wait(2.0)
		Sfx.play3d("knock", kp, 3.0)
	else:
		Sfx.play3d("breath", player.global_position - player_fwd() * 0.6, 3.0, 0.9, 2.0)
	busy_scare = false

func scare_fake() -> void:
	busy_scare = true
	Sfx.play("riser", -6.0)
	await wait(2.4)
	if state == "play":
		if randf() < 0.5:
			Sfx.play("pop", 0.0)
			jolt(0.25)
		else:
			Sfx.play3d("slam", player.global_position + player_fwd() * 14.0, 0.0, 0.9)
	busy_scare = false

# ---------------------------------------------------------------- watchers, windows, carousel, anomalies
func statue_pose(gh, i: int) -> void:
	var poses := [["idle", 0.0], ["roar", 0.5], ["attack", 0.35], ["run", 0.15], ["lunge", 0.2]]
	var p: Array = poses[i % poses.size()]
	gh.freeze_pose(p[0], p[1])

func update_statues(delta: float) -> void:
	for s in statues:
		var gh = s.node
		if not is_instance_valid(gh):
			continue
		var d: float = gh.global_position.distance_to(player.global_position)
		s.cool = maxf(0.0, s.cool - delta)
		if d > 45.0:
			continue
		if looking_at(gh.global_position + Vector3(0.0, 1.4, 0.0), 0.78) and d < 40.0:
			s.unseen = 0.0
		else:
			s.unseen += delta
			if s.unseen > 0.6 and s.cool <= 0.0 and d < 28.0:
				s.unseen = 0.0
				s.cool = 1.2
				s.stage += 1
				var dirv: Vector3 = player.global_position - gh.global_position
				dirv.y = 0.0
				dirv = dirv.normalized()
				gh.face_dir(dirv)
				statue_pose(gh, s.stage)
				if s.mode == "walker":
					var step := minf(d - 5.0, 4.5)
					if step > 0.5:
						var np: Vector3 = gh.global_position + dirv * step
						gh.global_position = Vector3(np.x, 0.0, np.z)
						Sfx.play3d("scrape", gh.global_position, -4.0, randf_range(0.7, 1.1))
					elif s.stage >= 4 and not busy and not hiding:
						statue_attack(s)

func statue_attack(s: Dictionary) -> void:
	var gh = s.node
	statues.erase(s)
	gh.tint(false)
	gh.unfreeze()
	gh.run_anim = true
	gh.morph_to = 1.0
	Sfx.play("sting", 4.0)
	jolt(1.2)
	var fwd := player_fwd()
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).tween_property(gh, "global_position", player.global_position + fwd * 1.4, 0.45)
	await wait(0.9)
	gh.queue_free()

func update_windows() -> void:
	for i in lv.windows.size():
		if win_done[i]:
			continue
		var w: Array = lv.windows[i]
		var wp: Vector3 = w[0]
		if player.global_position.distance_to(wp) < 4.2 and looking_at(wp + Vector3(0.0, 1.5, 0.0), 0.2):
			win_done[i] = true
			window_pop(wp, w[1])

func window_pop(wp: Vector3, facing: Vector3) -> void:
	var gh = ghost_at(wp)
	gh.face_dir(facing)
	gh.morph_to = 1.0
	Sfx.play("slam", 1.0, 1.4)
	Sfx.play("sting", 2.0)
	jolt(0.9)
	await wait(0.55)
	gh.queue_free()

func update_carousel() -> void:
	var d: float = player.global_position.distance_to(lv.carousel.global_position)
	if car_state == 0 and d < 34.0:
		car_state = 1
		car_snd = Sfx.loop3d("musicbox", lv.carousel, -3.0, 14.0)
	elif car_state == 1 and d < 12.0:
		car_state = 2
		carousel_scare()

func carousel_scare() -> void:
	busy_scare = true
	if car_snd != null:
		car_snd.stop()
	lv.carousel_spin = false
	Sfx.play3d("slam", lv.carousel.global_position, -4.0, 0.6, 12.0)
	await wait(2.2)
	if state == "play" and not busy and not hiding:
		await scare_behind()
	lv.carousel_spin = true
	busy_scare = false

func update_anomalies(delta: float) -> void:
	anomaly_cd -= delta
	for a in lv.anomalies:
		var n = a.node
		var d: float = player.global_position.distance_to(a.pos)
		if a.shown:
			if d > 42.0:
				n.visible = false
				a.shown = false
		elif anomaly_cd <= 0.0 and d < 22.0 and d > 7.0 and not looking_at(a.pos + Vector3(0.0, 1.0, 0.0), 0.15):
			a.shown = true
			n.visible = true
			anomaly_cd = randf_range(18.0, 34.0)
			Sfx.play3d("drip", a.pos, -2.0)

func update_cry(delta: float) -> void:
	if not final_stage or has_key or busy or clown.state != "cry":
		return
	var d: float = clown.global_position.distance_to(player.global_position)
	trick_t -= delta
	if trick_t <= 0.0 and d > 20.0 and not near_cry:
		trick_t = randf_range(14.0, 22.0)
		cry_trick()
	if d < 9.0 and not near_cry:
		near_cry = true
		near_cry_scare()

func cry_trick() -> void:
	busy_scare = true
	if clown.cry_snd != null:
		clown.cry_snd.stop()
	var a := randf() * TAU
	Sfx.play3d("laugh", player.global_position + Vector3(sin(a), 0.0, cos(a)) * 16.0, 0.0, 0.8)
	await wait(1.3)
	Sfx.play3d("step", player.global_position - player_fwd() * 5.0, 0.0, 0.6, 5.0)
	await wait(3.0)
	if clown.cry_snd != null and clown.state == "cry":
		clown.cry_snd.play()
	busy_scare = false

func near_cry_scare() -> void:
	if clown.cry_snd != null:
		clown.cry_snd.stop()
	await wait(1.6)
	if clown.state == "cry" and not busy:
		clown.lift_head()
		clown.eye_on(2.0)
		Sfx.play3d("whisper", clown.global_position + Vector3(0.0, 1.4, 0.0), 0.0, 0.8)

func phone_scare() -> void:
	busy_scare = true
	for i in 4:
		var snd := Sfx.play3d("ring", lv.phone_pos, 6.0, 1.0, 10.0)
		var el := 0.0
		while el < 3.4:
			await get_tree().process_frame
			el += get_process_delta_time()
			if state != "play":
				busy_scare = false
				return
			if player.global_position.distance_to(lv.phone_pos) < 6.0:
				snd.stop()
				Sfx.play3d("whisper", player.global_position - player_fwd() * 2.5, 4.0)
				await wait(1.4)
				if state == "play" and not busy:
					await scare_behind()
				busy_scare = false
				return
	busy_scare = false

# ---------------------------------------------------------------- flow
func start_game() -> void:
	state = "play"
	player.locked = false
	player.yaw = 0.0
	player.pitch = 0.0
	player.global_position = lv.spawn
	flash_c = Color.BLACK
	flash_a = 1.0
	Sfx.play("boom", -8.0)
	say("The Last Show is open tonight...", 4.5)
	scare_t = 26.0

func set_pause(on: bool) -> void:
	paused = on
	get_tree().paused = on

func tap() -> void:
	if paused:
		set_pause(false)
		return
	if state == "menu":
		start_game()
	elif state == "dead_wait":
		respawn()
	elif state == "end" and end_t > 9.0:
		Engine.time_scale = 1.0
		amb.queue_free()
		hb.queue_free()
		get_tree().paused = false
		get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == "play" and not paused:
			set_pause(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "menu":
			get_tree().quit()
		elif state == "play":
			set_pause(not paused)
