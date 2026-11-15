extends CharacterBody3D
# The clown: procedural model, hunting AI (sight + hearing + nav), and cinematic poses.
var g = null
var player = null
var ghost := false
var state := "dormant"
var held_state := ""
var visual: Node3D
var rig := {}
var agent: NavigationAgent3D
var music: AudioStreamPlayer3D
var cry_snd: AudioStreamPlayer3D
var eye: OmniLight3D
var speed := 3.5
var bonus := 0.0
var walk_t := 0.0
var tt := 0.0
var last_known := Vector3.ZERO
var patrol_target := Vector3.ZERO
var lost_t := 0.0
var wait_t := 0.0
var lunge_t := 0.0
var lunge_cd := 6.0
var stun_t := 0.0
var step_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var nudge_t := 0.0
var nudge_dir := Vector3.ZERO
var run_anim := false
var sees_now := false
var aggression := 0
var phase := "go"
var planned := false
var look_t := 0.0
var go_t := 0.0
var hide_queue: Array = []
var hide_target := -1
var hide_wait := 0.0
var hide_chance := 0.35
var checked := {}
var hunch_t := 25.0
var pose_frozen := false
var pose_anim := "idle"
var dead := false
var tint_mat: StandardMaterial3D = null

func mat(c: Color, r: float = 0.7, em: Color = Color.BLACK, ee: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	if ee > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = ee
	return m

func part(par: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	return mi

func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	return s

func cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c

func bx(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

const MODEL_HEIGHT := 2.3
const MODEL_FLIP := false
var model_loaded := false
var anim_player: AnimationPlayer = null
var anims := {}
var cur_anim := ""
var forced_anim := ""
var morphs: Array = []
var morph_val := 0.0
var morph_to := -1.0
var cry_anim := true
var snap_t := 2.0
var snap_v := 0.0

func build() -> void:
	visual = Node3D.new()
	add_child(visual)
	if ResourceLoader.exists("res://clown_model.glb"):
		model_loaded = load_model("res://clown_model.glb")
	if model_loaded:
		eye = OmniLight3D.new()
		eye.position = Vector3(0.0, 2.05, 0.5)
		eye.light_color = Color(1.0, 0.8, 0.3)
		eye.omni_range = 4.0
		eye.light_energy = 0.25
		visual.add_child(eye)
		return
	build_procedural()

func load_model(path: String) -> bool:
	var ps = load(path)
	if not (ps is PackedScene):
		return false
	var inst: Node3D = ps.instantiate()
	visual.add_child(inst)
	var bb := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		if first:
			bb = a
			first = false
		else:
			bb = bb.merge(a)
		for bn in ["split", "wide"]:
			var idx := mi.find_blend_shape_by_name(bn)
			if idx >= 0:
				morphs.append([mi, idx])
	if not first and bb.size.y > 0.01:
		var sc := MODEL_HEIGHT / bb.size.y
		inst.scale = Vector3.ONE * sc
		inst.position = Vector3(0.0, -bb.position.y * sc, 0.0)
	if MODEL_FLIP:
		inst.rotation.y = PI
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		anim_player = aps[0] as AnimationPlayer
		setup_model_anims()
	return true

func setup_model_anims() -> void:
	var kw := {"idle": ["idle", "stand", "breath"], "walk": ["walk", "stalk", "creep"], "run": ["run", "sprint", "chase"], "lunge": ["lunge", "pounce"], "roar": ["roar", "scream", "rage", "taunt", "shout"], "attack": ["attack", "scare", "bite"], "cry": ["cry", "kneel", "sob", "sit"], "lookup": ["lookup", "look_up", "raise"]}
	var names := anim_player.get_animation_list()
	for key in kw:
		for nm in names:
			var low := String(nm).to_lower()
			for w in kw[key]:
				if low.contains(w) and not anims.has(key):
					anims[key] = String(nm)
	if names.size() > 0:
		for key in ["idle", "walk", "run"]:
			if not anims.has(key):
				anims[key] = String(names[0])
	for nm in names:
		var an := anim_player.get_animation(nm)
		if an != null:
			an.loop_mode = Animation.LOOP_LINEAR

func build_procedural() -> void:
	var skin := mat(Color(0.9, 0.88, 0.8), 0.55)
	var red := mat(Color(0.72, 0.04, 0.06), 0.5)
	var suit := mat(Color(0.28, 0.1, 0.34), 0.8)
	var suit2 := mat(Color(0.8, 0.65, 0.12), 0.8)
	var white := mat(Color(0.82, 0.8, 0.74), 0.8)
	var dark := mat(Color(0.02, 0.0, 0.02), 1.0)
	var glow := mat(Color(0.9, 1.0, 0.3), 0.3, Color(0.8, 1.0, 0.2), 3.0)
	var torso := Node3D.new()
	torso.position = Vector3(0.0, 1.1, 0.0)
	visual.add_child(torso)
	rig["torso"] = torso
	part(torso, cyl(0.3, 0.42, 0.95), suit, Vector3(0.0, 0.48, 0.0))
	part(torso, sph(0.45), suit, Vector3(0.0, 0.35, 0.05), Vector3(1.0, 0.9, 0.85))
	for i in 3:
		part(torso, sph(0.06), red, Vector3(0.0, 0.25 + i * 0.22, 0.43 - i * 0.05))
	var ruff := TorusMesh.new()
	ruff.inner_radius = 0.16
	ruff.outer_radius = 0.44
	part(torso, ruff, white, Vector3(0.0, 0.98, 0.0), Vector3(1.0, 0.6, 1.0))
	var head := Node3D.new()
	head.position = Vector3(0.0, 1.0, 0.05)
	torso.add_child(head)
	rig["head"] = head
	part(head, sph(0.3), skin, Vector3.ZERO, Vector3(1.0, 1.18, 1.0))
	part(head, sph(0.2), red, Vector3(-0.36, 0.1, -0.02))
	part(head, sph(0.2), red, Vector3(0.36, 0.1, -0.02))
	part(head, sph(0.16), red, Vector3(0.0, 0.38, -0.05))
	for s in [-1.0, 1.0]:
		part(head, sph(0.085), dark, Vector3(s * 0.12, 0.08, 0.255), Vector3(1.0, 1.4, 0.5))
		part(head, sph(0.03), glow, Vector3(s * 0.12, 0.08, 0.292))
		var brow := part(head, bx(0.16, 0.025, 0.03), dark, Vector3(s * 0.12, 0.2, 0.27))
		brow.rotation.z = s * 0.4
	part(head, sph(0.075), mat(Color(0.8, 0.05, 0.05), 0.4, Color(0.6, 0.0, 0.0), 0.5), Vector3(0.0, -0.02, 0.31))
	for i in range(-3, 4):
		var x := i * 0.05
		var y := -0.2 + 0.008 * i * i
		var zz := 0.3 * sqrt(maxf(0.05, 1.0 - pow(x / 0.3, 2.0) - pow(y / 0.354, 2.0))) + 0.005
		part(head, bx(0.05, 0.09, 0.015), dark, Vector3(x, y - 0.045, zz - 0.004))
		part(head, bx(0.03, 0.045, 0.012), white, Vector3(x, y - 0.02, zz + 0.004))
		part(head, bx(0.056, 0.03, 0.02), red, Vector3(x, y, zz + 0.006))
		part(head, bx(0.056, 0.026, 0.02), red, Vector3(x, y - 0.1, zz + 0.004))
	eye = OmniLight3D.new()
	eye.position = Vector3(0.0, 0.05, 0.45)
	eye.light_color = Color(0.7, 1.0, 0.2)
	eye.omni_range = 4.0
	eye.light_energy = 0.25
	head.add_child(eye)
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * 0.2, 1.1, 0.0)
		visual.add_child(hip)
		part(hip, cyl(0.15, 0.13, 0.55), suit2, Vector3(0.0, -0.275, 0.0))
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -0.55, 0.0)
		hip.add_child(knee)
		part(knee, cyl(0.13, 0.1, 0.55), suit2, Vector3(0.0, -0.275, 0.0))
		part(knee, bx(0.3, 0.17, 0.75), red, Vector3(0.0, -0.58, 0.18))
		rig["hipL" if s < 0.0 else "hipR"] = hip
		rig["kneeL" if s < 0.0 else "kneeR"] = knee
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.52, 0.85, 0.0)
		torso.add_child(sh)
		part(sh, cyl(0.1, 0.08, 1.15), suit, Vector3(0.0, -0.575, 0.0))
		part(sh, sph(0.16), white, Vector3(0.0, -1.2, 0.0))
		for f in [-1.0, 0.0, 1.0]:
			var fg := part(sh, bx(0.03, 0.22, 0.03), white, Vector3(f * 0.06, -1.38, 0.0))
			fg.rotation.z = f * 0.2
		sh.rotation.z = s * 0.1
		rig["shL" if s < 0.0 else "shR"] = sh

func _ready() -> void:
	build()
	if ghost:
		return
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.3
	cs.shape = cap
	cs.position.y = 1.15
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.2
	agent.target_desired_distance = 1.5
	agent.radius = 0.7
	agent.height = 2.2
	add_child(agent)
	music = Sfx.loop3d("musicbox", self, -2.0, 9.0)
	music.max_distance = 70.0
	music.stop()

func face_dir(d: Vector3) -> void:
	visual.rotation.y = atan2(d.x, d.z)

func eye_on(e: float) -> void:
	eye.light_energy = e

func activate(pos: Vector3, st: String = "chase") -> void:
	global_position = pos
	velocity = Vector3.ZERO
	state = st
	held_state = ""
	forced_anim = ""
	morph_to = -1.0
	cry_anim = true
	lost_t = 0.0
	lunge_cd = randf_range(5.0, 9.0)
	pose_frozen = false
	dead = false
	phase = "go"
	planned = false
	hide_target = -1
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE
	last_known = player.global_position
	face_dir(player.global_position - pos)
	visible = true
	if st == "cry":
		set_cry()
	else:
		music.play()

func deactivate() -> void:
	state = "dormant"
	pose_frozen = false
	dead = false
	held_state = ""
	visible = false
	velocity = Vector3.ZERO
	global_position = Vector3(0.0, -100.0, 0.0)
	if music != null:
		music.stop()
	if cry_snd != null:
		cry_snd.queue_free()
		cry_snd = null

func hold(on: bool) -> void:
	if on:
		if state == "dormant" or state == "cry":
			return
		held_state = state
		state = "frozen"
		music.stream_paused = true
	elif held_state != "":
		state = held_state
		held_state = ""
		music.stream_paused = false

func stun(sec: float) -> void:
	state = "stun"
	stun_t = sec
	Sfx.play3d("scream", global_position, 2.0, 0.85)

func set_cry() -> void:
	state = "cry"
	music.stop()
	kneel(true, 0.1)
	cry_snd = Sfx.loop3d("sob", self, 10.0, 12.0)
	cry_snd.max_distance = 150.0

func silence_cry() -> void:
	cry_anim = false
	if cry_snd != null:
		cry_snd.queue_free()
		cry_snd = null

func kneel(on: bool, dur: float = 1.2) -> void:
	if model_loaded:
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "position:y", -0.55 if on else 0.0, dur)
	for k in ["hipL", "hipR"]:
		tw.tween_property(rig[k], "rotation:x", 0.0, dur)
	for k in ["kneeL", "kneeR"]:
		tw.tween_property(rig[k], "rotation:x", 1.5 if on else 0.0, dur)
	tw.tween_property(rig["torso"], "rotation:x", 0.45 if on else 0.0, dur)
	tw.tween_property(rig["head"], "rotation:x", 0.9 if on else 0.0, dur)
	for k in ["shL", "shR"]:
		tw.tween_property(rig[k], "rotation:x", -0.35 if on else 0.0, dur)

func lift_head() -> void:
	if model_loaded:
		forced_anim = "lookup"
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rig["head"], "rotation:x", -0.15, 1.3)
	tw.tween_property(rig["torso"], "rotation:x", 0.1, 1.3)

func dissolve() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(visual, "scale", Vector3(0.02, 0.02, 0.02), 1.6).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "position:y", visual.position.y + 0.6, 1.6)

func nearest_patrol_to(p: Vector3) -> Vector3:
	var pts: Array = g.patrol_pts
	var best: Vector3 = pts[0]
	for q in pts:
		if Vector3(q).distance_to(p) < best.distance_to(p):
			best = q
	return best

func pick_patrol() -> void:
	var pts: Array = g.patrol_pts
	var ppos: Vector3 = player.global_position
	var best: Vector3 = pts[randi() % pts.size()]
	var bias: float = 0.3 + aggression * 0.1
	if randf() < bias:
		var sorted: Array = pts.duplicate()
		sorted.sort_custom(func(a, b): return Vector3(a).distance_to(ppos) < Vector3(b).distance_to(ppos))
		var pick: int = randi() % mini(3, sorted.size())
		best = sorted[pick]
		if best.distance_to(global_position) < 8.0 and sorted.size() > 3:
			best = sorted[3]
	patrol_target = best

func can_see(dist: float) -> bool:
	if player.hidden:
		return false
	var rng: float = (30.0 if player.flash_on else 11.0) + aggression * 1.5
	if player.sprinting:
		rng += 6.0
	if dist > rng:
		return false
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var fwd := Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	if dist > 4.0 and fwd.dot(to.normalized()) < 0.2:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.9, 0.0), player.global_position + Vector3(0.0, 1.4, 0.0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player

func move_to(target: Vector3, spd: float, delta: float) -> void:
	agent.target_position = target
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if agent.is_navigation_finished() or dir.length() < 0.05:
		dir = target - global_position
		dir.y = 0.0
	if nudge_t > 0.0:
		nudge_t -= delta
		dir = nudge_dir
	if dir.length() > 0.05:
		dir = dir.normalized()
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	stuck_t += delta
	if stuck_t > 0.7:
		stuck_t = 0.0
		if global_position.distance_to(last_pos) < 0.3 and spd > 0.0:
			nudge_t = 0.5
			nudge_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		last_pos = global_position
	step_t += spd * delta
	if step_t > 2.6:
		step_t = 0.0
		Sfx.play3d("step", global_position, 3.0, 0.55, 5.0)

func begin_search(at: Vector3) -> void:
	state = "search"
	phase = "go"
	last_known = at
	look_t = 0.0
	go_t = 0.0
	planned = false
	hide_queue.clear()
	hide_target = -1

func begin_cabinet(idx: int, chance: float) -> void:
	state = "search"
	phase = "cabinet"
	hide_target = idx
	hide_chance = chance
	hide_wait = 0.0
	go_t = 0.0
	planned = true
	hide_queue.clear()

func plan_search() -> void:
	hide_queue.clear()
	var spots: Array = g.lv.hide_spots
	var cand: Array = []
	for i in spots.size():
		var hp: Vector3 = spots[i]["pos"]
		if hp.distance_to(last_known) < 13.0 and tt - float(checked.get(i, -99.0)) > 25.0:
			cand.append(i)
	cand.sort_custom(func(a, b): return Vector3(spots[a]["pos"]).distance_to(last_known) < Vector3(spots[b]["pos"]).distance_to(last_known))
	for i in mini(3, cand.size()):
		hide_queue.append(cand[i])
	planned = true

func do_search(delta: float) -> void:
	go_t += delta
	if go_t > 18.0 and phase != "look":
		state = "patrol"
		pick_patrol()
		return
	if phase == "go":
		if global_position.distance_to(last_known) < 2.0:
			phase = "look"
			look_t = 0.0
		else:
			move_to(last_known, 2.7, delta)
	elif phase == "look":
		velocity.x = 0.0
		velocity.z = 0.0
		look_t += delta
		visual.rotation.y += delta * 1.2
		if not planned:
			plan_search()
		if look_t > 2.2:
			if hide_queue.size() > 0:
				hide_target = int(hide_queue.pop_front())
				hide_chance = 0.35 + aggression * 0.06
				hide_wait = 0.0
				go_t = 0.0
				phase = "cabinet"
			else:
				state = "patrol"
				pick_patrol()
	elif phase == "cabinet":
		var spots: Array = g.lv.hide_spots
		var sp: Dictionary = spots[hide_target]
		var hp: Vector3 = sp["pos"]
		var fc: Vector3 = sp["face"]
		var front: Vector3 = hp + fc * 1.5
		var flat := Vector2(global_position.x - front.x, global_position.z - front.z).length()
		if flat > 1.0 and hide_wait < 0.01:
			move_to(front, 2.9, delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			hide_wait += delta
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-fc.x, -fc.z), minf(1.0, delta * 6.0))
			if hide_wait > 2.6:
				checked[hide_target] = tt
				var inside: bool = g.hiding and g.hide_idx == hide_target
				hide_target = -1
				phase = "look"
				look_t = 1.2
				go_t = 0.0
				if inside and randf() < hide_chance:
					g.pull_from_hide()

func _physics_process(delta: float) -> void:
	if ghost or state == "dormant":
		animate(delta)
		return
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	if state == "cry" or state == "frozen" or state == "caught":
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		animate(delta)
		return
	var ppos: Vector3 = player.global_position
	var dist := global_position.distance_to(ppos)
	var sees := can_see(dist)
	sees_now = sees
	var hearing: float = float(player.noise) * (1.0 + aggression * 0.12)
	var hears: bool = dist < hearing
	hunch_t -= delta
	if state == "stun":
		stun_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if stun_t <= 0.0:
			state = "chase"
	elif sees or (hears and dist < 6.0):
		if state != "chase":
			state = "chase"
			g.clown_alert()
		last_known = ppos
		lost_t = 0.0
	elif hears:
		if state == "chase":
			last_known = ppos
			lost_t = 0.0
		elif state == "investigate":
			last_known = last_known.lerp(ppos, minf(1.0, delta * 0.8))
		elif not (state == "search" and phase == "cabinet"):
			state = "investigate"
			last_known = ppos + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
			Sfx.play3d("whisper", global_position + Vector3(0.0, 1.6, 0.0), -2.0, 0.9, 6.0)
	elif state == "chase":
		lost_t += delta
		if lost_t > 5.0:
			begin_search(last_known)
	if g.hiding and g.hide_seen and state == "chase":
		g.hide_seen = false
		begin_cabinet(int(g.hide_idx), 0.85)
	if state == "chase":
		var spd: float = speed + bonus
		lunge_cd -= delta
		if lunge_t > 0.0:
			lunge_t -= delta
			spd *= 1.28
		elif lunge_cd <= 0.0 and sees and dist < 14.0 and dist > 5.0:
			lunge_t = 1.0
			lunge_cd = randf_range(7.0, 12.0)
			Sfx.play3d("laugh", global_position, 3.0, 1.25)
		var tgt: Vector3 = last_known
		if sees:
			var pv: Vector3 = player.velocity
			pv.y = 0.0
			tgt = ppos + pv * 0.45
		move_to(tgt, spd, delta)
		if dist < 1.3 and not player.hidden:
			g.player_caught()
	elif state == "investigate":
		if global_position.distance_to(last_known) < 2.0:
			begin_search(last_known)
		else:
			move_to(last_known, 3.0, delta)
	elif state == "search":
		do_search(delta)
	elif state == "patrol":
		if global_position.distance_to(patrol_target) < 2.5 or patrol_target == Vector3.ZERO:
			pick_patrol()
		if hunch_t <= 0.0:
			hunch_t = maxf(8.0, randf_range(22.0, 38.0) - aggression * 3.0)
			if randf() < 0.45 + aggression * 0.1:
				patrol_target = nearest_patrol_to(ppos)
		move_to(patrol_target, 2.4 + aggression * 0.1, delta)
	move_and_slide()
	animate(delta)

func tx(n: Node3D, v: float, k: float) -> void:
	n.rotation.x = lerpf(n.rotation.x, v, k)

func set_morph(v: float) -> void:
	for e in morphs:
		var mi: MeshInstance3D = e[0]
		mi.set_blend_shape_value(int(e[1]), v)

func animate_model(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	var want := "idle"
	var mt := 0.0
	if state == "stun":
		want = "roar"
		mt = 1.0
	elif state == "caught":
		want = "attack"
		mt = 1.0
	elif state == "cry":
		want = "cry"
	elif lunge_t > 0.0:
		want = "lunge"
		mt = 0.55
	elif sp > 4.0 or run_anim:
		want = "run"
		mt = 0.15
	elif sp > 0.4:
		want = "walk"
	if forced_anim != "":
		want = forced_anim
	if morph_to >= 0.0:
		mt = morph_to
	morph_val = move_toward(morph_val, mt, delta * 5.0)
	set_morph(morph_val)
	if pose_frozen or dead:
		return
	if anim_player == null:
		return
	var chain := {"run": ["run", "walk", "idle"], "walk": ["walk", "run", "idle"], "lunge": ["lunge", "run", "walk", "idle"], "roar": ["roar", "attack", "idle"], "attack": ["attack", "roar", "run", "idle"], "cry": ["cry", "idle"], "lookup": ["lookup", "cry", "idle"], "idle": ["idle", "walk"]}
	for key in chain[want]:
		if anims.has(key):
			if anims[key] != cur_anim:
				cur_anim = anims[key]
				anim_player.play(cur_anim, 0.25)
			if want == "walk":
				anim_player.speed_scale = clampf(sp / 2.4, 0.7, 1.6)
			elif want == "run":
				anim_player.speed_scale = clampf(sp / 4.2, 0.8, 1.5)
			else:
				anim_player.speed_scale = 1.0
			return

func animate(delta: float) -> void:
	tt += delta
	if model_loaded:
		animate_model(delta)
		return
	if pose_frozen or dead:
		return
	var hd: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	if state == "cry":
		visual.rotation.z = sin(tt * 24.0) * 0.014
		if cry_anim:
			hd.rotation.x = 0.9 + sin(tt * 5.0) * 0.06
			torso.rotation.x = 0.45 + sin(tt * 5.0) * 0.03
		return
	var k := minf(1.0, delta * 10.0)
	var hl: Node3D = rig["hipL"]
	var hr: Node3D = rig["hipR"]
	var kl: Node3D = rig["kneeL"]
	var kr: Node3D = rig["kneeR"]
	var sl: Node3D = rig["shL"]
	var sr: Node3D = rig["shR"]
	visual.rotation.z = 0.0
	torso.scale = Vector3(1.0, 1.0 + sin(tt * 2.0) * 0.015, 1.0)
	if state == "stun":
		tx(sl, -2.8, k)
		tx(sr, -2.8, k)
		tx(torso, -0.35, k)
		tx(hd, -0.7, k)
		visual.rotation.z = sin(tt * 45.0) * 0.05
		return
	if state == "caught":
		tx(sl, -1.6, k)
		tx(sr, -1.6, k)
		tx(torso, 0.3, k)
		tx(hd, 0.1, k)
		visual.rotation.z = sin(tt * 38.0) * 0.04
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var aggressive := state == "chase" or run_anim
	var lunging := lunge_t > 0.0
	if sp > 0.4 or run_anim:
		var rate := 5.0
		if lunging:
			rate = 12.0
		elif aggressive:
			rate = 8.5
		elif state == "patrol":
			rate = 4.2
		walk_t += delta * rate
		var sw := sin(walk_t)
		var amp := 0.9 if lunging else 0.7
		hl.rotation.x = sw * amp
		hr.rotation.x = -sw * amp
		kl.rotation.x = maxf(0.0, sin(walk_t + 1.6)) * 1.1
		kr.rotation.x = maxf(0.0, sin(walk_t + 1.6 + PI)) * 1.1
		if lunging:
			tx(torso, 0.8, k)
			tx(sl, -1.7, k)
			tx(sr, -1.7, k)
			tx(hd, -0.45, k)
		elif aggressive:
			tx(torso, 0.36, k)
			tx(sl, -1.1 + sin(tt * 12.0) * 0.12, k)
			tx(sr, -1.1 - sin(tt * 12.0) * 0.12, k)
			tx(hd, 0.08, k)
		elif state == "patrol":
			tx(torso, 0.25, k)
			tx(sl, -sw * 0.35, k)
			tx(sr, 0.4 + sin(tt * 3.0) * 0.05, k)
			tx(hd, 0.12, k)
		else:
			tx(torso, 0.2, k)
			tx(sl, -sw * 0.5, k)
			tx(sr, sw * 0.5, k)
			tx(hd, 0.08, k)
		hd.rotation.y = lerpf(hd.rotation.y, 0.0, k)
	else:
		for n in [hl, hr, kl, kr]:
			tx(n, 0.0, k)
		tx(torso, 0.05, k)
		tx(sl, sin(tt * 1.2) * 0.06, k)
		tx(sr, -sin(tt * 1.2) * 0.06, k)
		tx(hd, 0.08 + sin(tt * 0.5) * 0.05, k)
		if state == "search":
			hd.rotation.y = sin(tt * 1.7) * 0.9
		else:
			snap_t -= delta
			if snap_t <= 0.0:
				snap_t = randf_range(1.2, 3.5)
				snap_v = randf_range(-0.9, 0.9)
			hd.rotation.y = lerpf(hd.rotation.y, snap_v, minf(1.0, delta * 16.0))
			snap_v = lerpf(snap_v, 0.0, minf(1.0, delta * 0.6))
	hd.rotation.z = sin(tt * 0.9) * 0.12
	if state == "chase" or state == "patrol" or state == "search":
		eye.light_energy = 0.3 + (0.5 * (0.6 + 0.4 * sin(tt * 18.0)) if aggressive else 0.0)

# ---------------------------------------------------------------- ghosts, statues, death
func tint(on: bool) -> void:
	if tint_mat == null:
		tint_mat = StandardMaterial3D.new()
		tint_mat.albedo_color = Color(0.62, 0.64, 0.7, 0.62)
		tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint_mat.roughness = 1.0
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if on:
			mi.material_overlay = tint_mat
		else:
			mi.material_overlay = null

func apply_proc_pose(a: String) -> void:
	if rig.is_empty():
		return
	var torso: Node3D = rig["torso"]
	var hd: Node3D = rig["head"]
	var hl: Node3D = rig["hipL"]
	var hr: Node3D = rig["hipR"]
	var kl: Node3D = rig["kneeL"]
	var kr: Node3D = rig["kneeR"]
	var sl: Node3D = rig["shL"]
	var sr: Node3D = rig["shR"]
	for n in [hl, hr, kl, kr, sl, sr, torso, hd]:
		n.rotation.x = 0.0
	if a == "roar":
		sl.rotation.x = -2.8
		sr.rotation.x = -2.8
		torso.rotation.x = -0.35
		hd.rotation.x = -0.7
	elif a == "attack":
		sl.rotation.x = -1.6
		sr.rotation.x = -1.6
		torso.rotation.x = 0.3
	elif a == "run":
		hl.rotation.x = 0.7
		hr.rotation.x = -0.7
		kr.rotation.x = 1.0
		torso.rotation.x = 0.36
		sl.rotation.x = -1.1
		sr.rotation.x = -1.1
	elif a == "lunge":
		torso.rotation.x = 0.8
		sl.rotation.x = -1.7
		sr.rotation.x = -1.7
		hd.rotation.x = -0.45
		hl.rotation.x = 0.9
		hr.rotation.x = -0.6

func freeze_pose(a: String, t: float = 0.0) -> void:
	pose_frozen = true
	pose_anim = a
	run_anim = false
	if model_loaded and anim_player != null:
		var key: String = a
		if not anims.has(key):
			key = "idle"
		if anims.has(key):
			cur_anim = String(anims[key])
			anim_player.play(cur_anim)
			var an: Animation = anim_player.get_animation(cur_anim)
			anim_player.seek(minf(t, an.length * 0.95), true)
			anim_player.pause()
	elif not model_loaded:
		apply_proc_pose(a)

func unfreeze() -> void:
	pose_frozen = false
	cur_anim = ""
	if anim_player != null:
		anim_player.play()

func collapse(sec: float) -> void:
	dead = true
	if anim_player != null:
		anim_player.pause()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "rotation:x", -1.45, sec)
	tw.tween_property(visual, "position:y", visual.position.y - 0.25, sec)
	if eye != null:
		eye.light_energy = 0.0
