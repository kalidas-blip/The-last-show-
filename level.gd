extends Node3D
# World builder for THE LAST SHOW: 200x200 carnival in clear zones, reference-style props, blood decals, ambient animation.
const SPAWN := Vector3(-3.0, 0.1, 90.0)
const KNIFE_AT := Vector3(8.0, 1.04, 87.0)
const GATE_Z := -99.0
const HEART_AT := [Vector3(72.5, 1.25, 36.0), Vector3(53.5, 1.25, -4.0), Vector3(-48.0, 1.7, -6.0), Vector3(-32.0, 1.75, -62.0), Vector3(-62.5, 1.35, 40.0)]
const KNEEL_AT := [Vector3(-88.0, 0.0, -82.0), Vector3(86.0, 0.0, -86.0), Vector3(-90.0, 0.0, 56.0), Vector3(88.0, 0.0, 76.0), Vector3(72.0, 0.0, -92.0), Vector3(-92.0, 0.0, 6.0)]
const PATROL := [Vector3(0.0, 0.0, 70.0), Vector3(0.0, 0.0, 40.0), Vector3(0.0, 0.0, 12.0), Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, -50.0), Vector3(0.0, 0.0, -80.0), Vector3(-30.0, 0.0, -4.0), Vector3(-30.0, 0.0, 34.0), Vector3(-58.0, 0.0, 8.0), Vector3(-60.0, 0.0, -22.0), Vector3(30.0, 0.0, 12.0), Vector3(32.0, 0.0, -34.0), Vector3(60.0, 0.0, 10.0), Vector3(85.0, 0.0, 34.0), Vector3(-45.0, 0.0, -50.0), Vector3(35.0, 0.0, -58.0), Vector3(-58.0, 0.0, -68.0)]
const JACKS := [Vector3(-9.0, 0.0, 66.0), Vector3(14.0, 0.0, 22.0), Vector3(-22.0, 0.0, -30.0)]
const LAMP_POS := [Vector3(-8.0, 0.0, 70.0), Vector3(8.0, 0.0, 54.0), Vector3(-8.0, 0.0, 38.0), Vector3(8.0, 0.0, 22.0), Vector3(-8.0, 0.0, 6.0), Vector3(8.0, 0.0, -10.0), Vector3(-8.0, 0.0, -26.0), Vector3(8.0, 0.0, -42.0), Vector3(8.0, 0.0, -60.0), Vector3(-8.0, 0.0, -76.0), Vector3(8.0, 0.0, -88.0), Vector3(-30.0, 0.0, -10.0), Vector3(-30.0, 0.0, 28.0), Vector3(32.0, 0.0, 18.0), Vector3(32.0, 0.0, -30.0), Vector3(-58.0, 0.0, 16.0), Vector3(60.0, 0.0, 18.0)]
const CHECKPOINTS := [Vector3(0.0, 0.1, 64.0), Vector3(0.0, 0.1, 18.0), Vector3(-34.0, 0.1, 2.0), Vector3(36.0, 0.1, 14.0), Vector3(4.0, 0.1, -48.0), Vector3(0.0, 0.1, -84.0)]
const STALL_E := [64.0, 48.0, 32.0, -24.0]
const STALL_W := [56.0, 40.0, 24.0, -32.0]
var mats := {}
var nav: NavigationRegion3D
var hearts: Array = []
var lamps: Array = []
var jacks: Array = []
var windows: Array = []
var statue_spots: Array = []
var sways: Array = []
var horses: Array = []
var balloons: Array = []
var wheel_cabs: Array = []
var blood_mats: Array = []
var splats: Array = []
var drops: Array = []
var hide_spots: Array = []
var anomalies: Array = []
var wheel: Node3D
var carousel: Node3D
var sky: Node3D
var gate_l: Node3D
var gate_r: Node3D
var gate_lock: Node3D
var gate_light: OmniLight3D
var knife_node: Node3D
var phone_pos := Vector3(-15.0, 1.4, 88.0)
var carousel_pos := Vector3(-48.0, 0.0, -6.0)
var spawn := SPAWN
var knife_at := KNIFE_AT
var gate_z := GATE_Z
var kneel_pts: Array = KNEEL_AT
var patrol_pts: Array = PATROL
var checkpoints: Array = CHECKPOINTS
var carousel_spin := true

# ---------------------------------------------------------------- materials
func mk(col: Color, rough: float = 0.9, tex: String = "", tri: bool = true, scl: float = 0.25, em: Color = Color.BLACK, ee: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if tex != "":
		m.albedo_texture = load("res://%s.jpg" % tex)
		if ResourceLoader.exists("res://%s_n.jpg" % tex):
			m.normal_enabled = true
			m.normal_texture = load("res://%s_n.jpg" % tex)
			m.normal_scale = 1.2
		if tri:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(scl, scl, scl)
	if ee > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = ee
	return m

func make_mats() -> void:
	mats["dirt"] = mk(Color(0.92, 0.92, 0.92), 1.0, "dirt", true, 0.16)
	mats["path"] = mk(Color(0.9, 0.9, 0.9), 0.85, "path", true, 0.18)
	mats["board"] = mk(Color(0.72, 0.7, 0.68), 0.75, "planks", true, 0.3)
	mats["wood"] = mk(Color(0.85, 0.8, 0.75), 0.9, "planks", true, 0.25)
	mats["metal"] = mk(Color(0.9, 0.9, 0.9), 0.55, "metal", true, 0.3)
	mats["paint"] = mk(Color(0.95, 0.95, 0.95), 0.85, "paint", true, 0.2)
	mats["brick"] = mk(Color(0.9, 0.9, 0.9), 0.95, "brick", true, 0.22)
	mats["hay"] = mk(Color(0.95, 0.95, 0.95), 1.0, "hay", true, 0.5)
	mats["rope"] = mk(Color(0.5, 0.42, 0.3), 1.0)
	mats["stone"] = mk(Color(0.55, 0.56, 0.6), 0.95, "path", true, 0.3)
	mats["tent"] = mk(Color(0.95, 0.95, 0.95), 0.9, "tent", true, 0.12)
	mats["tent"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["tent_uv"] = mk(Color(0.95, 0.95, 0.95), 0.9, "tent", false)
	mats["tent_uv"].uv1_scale = Vector3(6.0, 1.0, 1.0)
	mats["tent_uv"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["tent_roof"] = mk(Color(1.0, 0.78, 0.6), 0.9, "tent", false)
	mats["tent_roof"].uv1_scale = Vector3(8.0, 1.0, 1.0)
	mats["tent_roof"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["tent_o"] = mk(Color(1.0, 0.7, 0.5), 0.9, "tent", true, 0.15)
	mats["tent_y"] = mk(Color(1.0, 0.95, 0.55), 0.9, "tent", true, 0.15)
	mats["tent_c"] = mk(Color(0.95, 0.92, 0.78), 0.9, "tent", true, 0.15)
	for k in ["tent_o", "tent_y", "tent_c"]:
		mats[k].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["bark"] = mk(Color(0.1, 0.08, 0.06), 1.0)
	mats["dark"] = mk(Color(0.03, 0.03, 0.04), 0.9)
	mats["steel"] = mk(Color(0.8, 0.82, 0.86), 0.25, "", false, 0.25, Color(0.7, 0.75, 0.8), 0.5)
	mats["steel"].metallic = 0.9
	mats["red"] = mk(Color(0.65, 0.05, 0.07), 0.45)
	mats["white"] = mk(Color(0.88, 0.86, 0.8), 0.6)
	mats["gold"] = mk(Color(1.0, 0.8, 0.2), 0.3, "", false, 0.25, Color(1.0, 0.7, 0.1), 2.5)
	mats["bulb"] = mk(Color(1.0, 0.85, 0.5), 0.4, "", false, 0.25, Color(1.0, 0.75, 0.35), 1.5)
	mats["glass"] = mk(Color(0.6, 0.8, 0.9, 0.18), 0.1)
	mats["glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["water"] = mk(Color(0.02, 0.05, 0.05, 0.92), 0.05)
	mats["water"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["water"].metallic = 0.3
	mats["poster"] = mk(Color(0.9, 0.9, 0.9), 0.8, "", false)
	mats["poster"].albedo_texture = load("res://poster.png")
	mats["poster"].emission_enabled = true
	mats["poster"].emission_texture = load("res://poster.png")
	mats["poster"].emission_energy_multiplier = 0.55
	mats["poster"].cull_mode = BaseMaterial3D.CULL_DISABLED
	var hues := [Color(0.55, 0.12, 0.14), Color(0.75, 0.62, 0.15), Color(0.2, 0.3, 0.6), Color(0.35, 0.15, 0.45), Color(0.15, 0.45, 0.4), Color(0.7, 0.4, 0.15)]
	for i in hues.size():
		mats["c%d" % i] = mk(hues[i], 0.7)

# ---------------------------------------------------------------- primitives
func deco(mi: MeshInstance3D, far: float = 92.0) -> void:
	mi.visibility_range_end = far
	mi.visibility_range_end_margin = 6.0

func box(par: Node, size: Vector3, pos: Vector3, m: Material, rot: float = 0.0, solid: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot
	deco(mi)
	par.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func pillar(par: Node, r: float, h: float, pos: Vector3, m: Material, solid: bool = true, rb: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if rb < 0.0 else rb
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	deco(mi)
	par.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r, cm.bottom_radius)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func ball(par: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco(mi)
	par.add_child(mi)
	return mi

func lbl(text: String, pos: Vector3, rot_y: float, size: int, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Sfx.font
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0)
	l.double_sided = true
	l.shaded = false
	l.position = pos
	l.rotation.y = rot_y
	l.visibility_range_end = 80.0
	add_child(l)

func omni(par: Node, pos: Vector3, col: Color, energy: float, rng: float, flicker: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.position = pos
	par.add_child(l)
	if flicker:
		lamps.append({"light": l, "mat": null, "base": energy, "faulty": true, "ph": randf() * 10.0, "pos": l.position, "bulb": null, "bpos": Vector3.ZERO})
	return l

func quad(pos: Vector3, rot: Vector3, size: Vector2, m: Material) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco(mi)
	add_child(mi)
	return mi

func sway(n: Node3D, amp: float, spd: float) -> void:
	sways.append([n, n.rotation, amp, spd, randf() * TAU])

func rope(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 5
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco(mi)
	add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := dir.cross(ref).normalized()
	var z := x.cross(dir)
	mi.basis = Basis(x, dir, z)

# ---------------------------------------------------------------- structures
func building(c: Vector3, w: float, d: float, h: float, door: String, m: Material, gap: float = 3.8) -> void:
	var th := 0.4
	for side in ["n", "s", "w", "e"]:
		var horiz: bool = side == "n" or side == "s"
		var span := w if horiz else d
		var pos := Vector3(0.0, h * 0.5, 0.0)
		if side == "n":
			pos += Vector3(0.0, 0.0, -d * 0.5)
		elif side == "s":
			pos += Vector3(0.0, 0.0, d * 0.5)
		elif side == "w":
			pos += Vector3(-w * 0.5, 0.0, 0.0)
		else:
			pos += Vector3(w * 0.5, 0.0, 0.0)
		pos += c
		if side == door:
			var seg := (span - gap) * 0.5
			var off := (gap + seg) * 0.5
			for sgn in [-1.0, 1.0]:
				if horiz:
					box(nav, Vector3(seg, h, th), pos + Vector3(sgn * off, 0.0, 0.0), m)
				else:
					box(nav, Vector3(th, h, seg), pos + Vector3(0.0, 0.0, sgn * off), m)
			if horiz:
				box(self, Vector3(gap, h - 3.0, th), pos + Vector3(0.0, 1.5, 0.0), m, 0.0, false)
			else:
				box(self, Vector3(th, h - 3.0, gap), pos + Vector3(0.0, 1.5, 0.0), m, 0.0, false)
		elif horiz:
			box(nav, Vector3(span, h, th), pos, m)
		else:
			box(nav, Vector3(th, h, span), pos, m)
	box(self, Vector3(w + 1.0, 0.4, d + 1.0), c + Vector3(0.0, h + 0.2, 0.0), mats["wood"], 0.0, false)
	box(self, Vector3(w + 1.4, 0.25, 0.5), c + Vector3(0.0, h + 0.5, -d * 0.5 - 0.3), mats["dark"], 0.0, false)

func lamp(p: Vector3, faulty: bool) -> void:
	pillar(nav, 0.32, 0.5, p + Vector3(0.0, 0.25, 0.0), mats["metal"], true, 0.45)
	pillar(self, 0.1, 4.6, p + Vector3(0.0, 2.6, 0.0), mats["metal"], false)
	pillar(self, 0.17, 0.25, p + Vector3(0.0, 1.0, 0.0), mats["metal"], false)
	pillar(self, 0.15, 0.2, p + Vector3(0.0, 3.9, 0.0), mats["metal"], false)
	var bm := mk(Color(1.0, 0.85, 0.5), 0.4, "", false, 0.25, Color(1.0, 0.75, 0.35), 1.5)
	var bulb := ball(self, 0.3, p + Vector3(0.0, 5.0, 0.0), bm)
	var cap := pillar(self, 0.0, 0.35, p + Vector3(0.0, 5.45, 0.0), mats["metal"], false, 0.5)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var a := k * TAU / 4.0
		pillar(self, 0.02, 0.7, p + Vector3(cos(a) * 0.32, 5.0, sin(a) * 0.32), mats["metal"], false)
	var l := omni(self, p + Vector3(0.0, 4.8, 0.0), Color(1.0, 0.72, 0.42), 1.7, 15.0)
	l.omni_attenuation = 1.4
	lamps.append({"light": l, "mat": bm, "base": 1.7, "faulty": faulty, "ph": randf() * 10.0, "pos": l.position, "bulb": bulb, "bpos": bulb.position})

func stall(p: Vector3, yaw: float, tint: Color, label: String, goods: int) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	nav.add_child(s)
	var m := mk(tint, 0.9, "planks", true, 0.25)
	box(s, Vector3(4.6, 3.0, 0.2), Vector3(0.0, 1.5, -1.0), m)
	box(s, Vector3(0.2, 3.0, 2.2), Vector3(-2.2, 1.5, 0.0), m)
	box(s, Vector3(0.2, 3.0, 2.2), Vector3(2.2, 1.5, 0.0), m)
	box(s, Vector3(4.6, 1.0, 0.6), Vector3(0.0, 0.5, 1.0), m)
	box(s, Vector3(4.2, 0.1, 0.5), Vector3(0.0, 1.55, -0.7), mats["wood"], 0.0, false)
	for k in 7:
		var sm: Material = mats["red"] if k % 2 == 0 else mats["white"]
		var st := box(s, Vector3(0.75, 0.1, 3.2), Vector3(-2.25 + k * 0.75, 3.15 - 0.02 * k, 0.45), sm, 0.0, false)
		st.rotation.x = -0.18
		ball(s, 0.12, Vector3(-2.25 + k * 0.75, 2.78, 2.0), sm)
	box(s, Vector3(3.6, 0.7, 0.12), Vector3(0.0, 3.7, 1.8), mats["dark"], 0.0, false)
	var ll := Label3D.new()
	ll.text = label
	ll.font = Sfx.font
	ll.font_size = 56
	ll.pixel_size = 0.01
	ll.modulate = Color(0.85, 0.7, 0.2)
	ll.outline_size = 10
	ll.shaded = false
	ll.double_sided = true
	ll.position = Vector3(0.0, 3.7, 1.9)
	ll.visibility_range_end = 70.0
	s.add_child(ll)
	if goods == 0:
		for r in 3:
			for k in 3 - r:
				pillar(s, 0.11, 0.3, Vector3(-1.2 + k * 0.26 + r * 0.13, 1.7 + r * 0.3, 0.0), mats["metal"], false)
	elif goods == 1:
		for k in 5:
			ball(s, 0.2, Vector3(-1.8 + k * 0.9, 1.78, 0.0), mats["white"])
			ball(s, 0.03, Vector3(-1.8 + k * 0.9 + 0.07, 1.82, 0.18), mats["dark"])
			ball(s, 0.03, Vector3(-1.8 + k * 0.9 - 0.07, 1.82, 0.18), mats["dark"])
	else:
		for k in 4:
			box(s, Vector3(0.4, 0.4, 0.4), Vector3(-1.5 + k * 1.0, 1.75, 0.0), mats["c%d" % k], 0.0, false)
	ball(s, 0.1, Vector3(-1.4, 2.7, 0.9), mats["bulb"])
	ball(s, 0.1, Vector3(1.4, 2.7, 0.9), mats["bulb"])

func bench(p: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	add_child(s)
	var col := box(nav, Vector3(2.0, 0.9, 0.6), p + Vector3(0.0, 0.45, 0.0), mats["wood"], yaw)
	col.visible = false
	box(s, Vector3(2.0, 0.12, 0.55), Vector3(0.0, 0.5, 0.0), mats["wood"], 0.0, false)
	box(s, Vector3(2.0, 0.5, 0.1), Vector3(0.0, 0.85, -0.25), mats["wood"], 0.0, false)
	box(s, Vector3(0.1, 0.5, 0.5), Vector3(-0.85, 0.25, 0.0), mats["metal"], 0.0, false)
	box(s, Vector3(0.1, 0.5, 0.5), Vector3(0.85, 0.25, 0.0), mats["metal"], 0.0, false)

func trash(p: Vector3) -> void:
	pillar(nav, 0.4, 0.9, p + Vector3(0.0, 0.45, 0.0), mats["metal"], true, 0.34)
	var lid := box(self, Vector3(0.9, 0.08, 0.9), p + Vector3(0.1, 0.95, 0.0), mats["dark"], 0.0, false)
	lid.rotation.z = 0.3

func crate_pile(p: Vector3, n: int) -> void:
	for k in n:
		var s := 1.0 + 0.1 * (k % 2)
		box(nav, Vector3(s, s, s), p + Vector3(k * 1.05, s * 0.5, 0.0), mats["wood"], 0.0 if k % 2 == 0 else 0.15)
	if n > 2:
		box(nav, Vector3(0.95, 0.95, 0.95), p + Vector3(0.5, 1.45, 0.0), mats["wood"], 0.2)
	pillar(nav, 0.45, 1.0, p + Vector3(n * 1.05 + 0.5, 0.5, 0.2), mats["tent"])

func tree(p: Vector3, solid: bool = true, far: float = 92.0) -> void:
	var h := randf_range(4.5, 7.5)
	var tr := pillar(nav if solid else self, 0.17, h, p + Vector3(0.0, h * 0.5, 0.0), mats["bark"], solid, 0.42)
	tr.visibility_range_end = far
	var nb := 6 if solid else 3
	for i in nb:
		var by := h * randf_range(0.45, 0.95)
		var bl := randf_range(1.4, 2.6)
		var b := pillar(self, 0.045, bl, p + Vector3(0.0, by, 0.0), mats["bark"], false)
		b.rotation = Vector3(0.0, randf() * TAU, randf_range(0.7, 1.3))
		b.visibility_range_end = far
		if solid:
			sway(b, 0.05, randf_range(0.7, 1.4))
		var tw := pillar(self, 0.025, 0.9, p + Vector3(0.0, by + 0.5, 0.0), mats["bark"], false)
		tw.rotation = Vector3(0.0, randf() * TAU, randf_range(0.2, 1.0))
		tw.visibility_range_end = far

# ---------------------------------------------------------------- build
func build() -> void:
	make_mats()
	init_blood()
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.6)
	NavigationServer3D.map_set_cell_height(map, 0.6)
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.6
	nm.cell_height = 0.6
	nm.agent_radius = 0.9
	nm.agent_height = 2.4
	nm.agent_max_climb = 0.6
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = nm
	add_child(nav)
	build_ground()
	build_roads()
	build_fence()
	build_exit_gate()
	build_forest()
	build_entrance()
	build_midway()
	build_plaza()
	build_west()
	build_east()
	build_north()
	build_lamps()
	build_jacks()
	build_hearts()
	build_knife()
	build_piles()
	build_ambient()
	build_sky()
	build_banners()
	build_hay_and_ropes()
	build_small_tents()
	build_circus_props()
	build_string_lights()
	build_puddles()
	build_hides()
	build_lore()
	build_anomalies()
	nav.bake_navigation_mesh(false)

func build_ground() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(240.0, 1.0, 240.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	nav.add_child(sb)
	var pm := PlaneMesh.new()
	pm.size = Vector2(13.0, 13.0)
	for ix in 18:
		for iz in 18:
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mats["dirt"]
			mi.position = Vector3(-110.5 + ix * 13.0, 0.0, -110.5 + iz * 13.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			deco(mi, 100.0)
			add_child(mi)

func strip_m(c: Vector3, sx: float, sz: float, y: float, m: Material) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(sx, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(c.x, y, c.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco(mi, 105.0)
	add_child(mi)

func strip(c: Vector3, sx: float, sz: float, y: float) -> void:
	strip_m(c, sx, sz, y, mats["path"])

func build_roads() -> void:
	strip_m(Vector3(0.0, 0.0, 0.0), 12.0, 196.0, 0.02, mats["board"])
	for sx in [-6.1, 6.1]:
		box(self, Vector3(0.3, 0.25, 196.0), Vector3(sx, 0.12, 0.0), mats["wood"], 0.0, false)
	strip(Vector3(0.0, 0.0, 88.0), 40.0, 14.0, 0.027)
	strip(Vector3(-40.0, 0.0, 0.0), 68.0, 6.0, 0.021)
	strip(Vector3(36.0, 0.0, 12.0), 60.0, 6.0, 0.021)
	strip(Vector3(-36.0, 0.0, 40.0), 60.0, 6.0, 0.022)
	strip(Vector3(30.0, 0.0, 40.0), 48.0, 6.0, 0.022)
	strip(Vector3(34.0, 0.0, -24.0), 56.0, 6.0, 0.023)
	strip(Vector3(-38.0, 0.0, -44.0), 60.0, 6.0, 0.024)
	strip(Vector3(30.0, 0.0, -70.0), 48.0, 6.0, 0.025)
	var disc := CylinderMesh.new()
	disc.top_radius = 15.0
	disc.bottom_radius = 15.0
	disc.height = 0.02
	var di := MeshInstance3D.new()
	di.mesh = disc
	di.material_override = mats["path"]
	di.position = Vector3(0.0, 0.03, 0.0)
	di.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deco(di, 105.0)
	add_child(di)

func build_fence() -> void:
	var h := 4.8
	box(nav, Vector3(204.0, h, 0.6), Vector3(0.0, h * 0.5, 100.0), mats["wood"])
	box(nav, Vector3(0.6, h, 204.0), Vector3(-100.0, h * 0.5, 0.0), mats["wood"])
	box(nav, Vector3(0.6, h, 204.0), Vector3(100.0, h * 0.5, 0.0), mats["wood"])
	box(nav, Vector3(96.0, h, 0.6), Vector3(-53.0, h * 0.5, -100.0), mats["wood"])
	box(nav, Vector3(96.0, h, 0.6), Vector3(53.0, h * 0.5, -100.0), mats["wood"])
	for i in range(-96, 100, 8):
		box(self, Vector3(0.9, 5.8, 0.9), Vector3(-99.5, 2.9, i), mats["wood"], 0.0, false)
		box(self, Vector3(0.9, 5.8, 0.9), Vector3(99.5, 2.9, i), mats["wood"], 0.0, false)
		box(self, Vector3(0.9, 5.8, 0.9), Vector3(i, 2.9, 99.5), mats["wood"], 0.0, false)
		if absf(i) > 8:
			box(self, Vector3(0.9, 5.8, 0.9), Vector3(i, 2.9, -99.5), mats["wood"], 0.0, false)
	box(nav, Vector3(4.2, 4.4, 0.3), Vector3(-2.1, 2.2, 99.4), mats["metal"])
	box(nav, Vector3(4.2, 4.4, 0.3), Vector3(2.1, 2.2, 99.4), mats["metal"])
	box(self, Vector3(4.6, 0.2, 0.3), Vector3(0.0, 2.0, 99.2), mats["steel"], 0.0, false)
	lbl("CLOSED", Vector3(0.0, 5.6, 98.9), PI, 100, Color(0.7, 0.1, 0.1))

func build_exit_gate() -> void:
	box(nav, Vector3(1.4, 8.0, 1.4), Vector3(-4.8, 4.0, GATE_Z - 0.6), mats["brick"])
	box(nav, Vector3(1.4, 8.0, 1.4), Vector3(4.8, 4.0, GATE_Z - 0.6), mats["brick"])
	box(self, Vector3(11.0, 1.4, 1.4), Vector3(0.0, 7.6, GATE_Z - 0.6), mats["wood"], 0.0, false)
	lbl("EXIT", Vector3(0.0, 7.6, GATE_Z + 0.2), 0.0, 130, Color(0.8, 0.1, 0.1))
	gate_l = Node3D.new()
	gate_l.position = Vector3(-4.0, 0.0, GATE_Z)
	add_child(gate_l)
	box(gate_l, Vector3(4.0, 4.4, 0.3), Vector3(2.0, 2.2, 0.0), mats["metal"])
	gate_r = Node3D.new()
	gate_r.position = Vector3(4.0, 0.0, GATE_Z)
	add_child(gate_r)
	box(gate_r, Vector3(4.0, 4.4, 0.3), Vector3(-2.0, 2.2, 0.0), mats["metal"])
	gate_lock = Node3D.new()
	gate_lock.position = Vector3(0.0, 2.0, GATE_Z + 0.3)
	add_child(gate_lock)
	box(gate_lock, Vector3(3.0, 0.18, 0.18), Vector3.ZERO, mats["metal"], 0.0, false)
	box(gate_lock, Vector3(0.45, 0.55, 0.25), Vector3(0.0, -0.3, 0.0), mats["gold"], 0.0, false)
	gate_light = omni(self, Vector3(0.0, 2.8, GATE_Z + 3.0), Color(0.9, 0.1, 0.1), 1.6, 9.0)

func build_forest() -> void:
	for i in 64:
		var side := i % 4
		var u := randf_range(-125.0, 125.0)
		var off := randf_range(106.0, 122.0)
		var p := Vector3(u, 0.0, off)
		if side == 1:
			p = Vector3(u, 0.0, -off)
		elif side == 2:
			p = Vector3(off, 0.0, u)
		elif side == 3:
			p = Vector3(-off, 0.0, u)
		tree(p, false, 120.0)

# ---------------------------------------------------------------- zones
func build_entrance() -> void:
	box(nav, Vector3(0.9, 8.0, 0.9), Vector3(-8.0, 4.0, 76.0), mats["brick"])
	box(nav, Vector3(0.9, 8.0, 0.9), Vector3(8.0, 4.0, 76.0), mats["brick"])
	box(self, Vector3(17.8, 2.4, 0.9), Vector3(0.0, 8.4, 76.0), mats["wood"], 0.0, false)
	lbl("THE LAST SHOW", Vector3(0.0, 8.7, 76.55), 0.0, 150, Color(0.85, 0.08, 0.08))
	lbl("NO LAUGHING", Vector3(0.0, 7.5, 76.55), 0.0, 80, Color(0.8, 0.75, 0.6))
	for i in 16:
		var x := -7.5 + i * 1.0
		var fg := box(self, Vector3(0.5, 0.7, 0.03), Vector3(x, 6.7 - 0.5 * (1.0 - pow(x / 8.0, 2.0)), 76.6), mats["c%d" % (i % 3 * 2)], 0.0, false)
		fg.rotation.z = PI * 0.25
		sway(fg, 0.25, randf_range(1.5, 2.6))
	building(Vector3(-12.0, 0.0, 84.0), 5.0, 4.0, 3.4, "e", mats["brick"], 3.0)
	building(Vector3(12.0, 0.0, 84.0), 5.0, 4.0, 3.4, "w", mats["brick"], 3.0)
	box(nav, Vector3(0.6, 1.0, 2.6), Vector3(-13.6, 0.5, 84.0), mats["wood"])
	box(nav, Vector3(0.6, 1.0, 2.6), Vector3(13.6, 0.5, 84.0), mats["wood"])
	lbl("TICKETS", Vector3(-9.3, 3.1, 84.0), PI * 0.5, 60, Color(0.85, 0.7, 0.2))
	lbl("TICKETS", Vector3(9.3, 3.1, 84.0), -PI * 0.5, 60, Color(0.85, 0.7, 0.2))
	omni(self, Vector3(-12.0, 2.4, 84.0), Color(1.0, 0.6, 0.3), 1.0, 7.0, true)
	omni(self, Vector3(12.0, 2.4, 84.0), Color(1.0, 0.6, 0.3), 1.0, 7.0, true)
	for i in 5:
		var x := -4.0 + 2.0 * i
		pillar(nav, 0.1, 1.1, Vector3(x, 0.55, 80.0), mats["metal"])
		for k in 3:
			box(self, Vector3(0.9, 0.06, 0.06), Vector3(x, 0.95, 80.0), mats["metal"], k * 1.05 + 0.4 * i, false)
	pillar(nav, 0.15, 1.7, Vector3(-15.0, 0.85, 88.0), mats["metal"])
	box(self, Vector3(0.45, 0.6, 0.3), Vector3(-15.0, 1.5, 88.0), mats["dark"], 0.0, false)
	bench(Vector3(-6.0, 0.0, 95.0), 0.0)
	bench(Vector3(6.0, 0.0, 95.0), PI)
	trash(Vector3(-15.0, 0.0, 80.0))
	trash(Vector3(15.0, 0.0, 92.0))
	wall_splat(Vector3(-9.45, 1.6, 86.2), Vector3(1.0, 0.0, 0.0), 1.1)
	wall_splat(Vector3(9.45, 1.4, 82.0), Vector3(-1.0, 0.0, 0.0), 1.3)

func build_midway() -> void:
	var tints := [Color(0.5, 0.2, 0.2), Color(0.2, 0.3, 0.5), Color(0.5, 0.45, 0.2), Color(0.3, 0.5, 0.3), Color(0.5, 0.3, 0.5), Color(0.2, 0.4, 0.45), Color(0.5, 0.35, 0.25), Color(0.4, 0.2, 0.35)]
	var ne := ["RING TOSS", "SHOOT THE CLOWN", "DUNK ME", "DOLL HOUSE"]
	var nw := ["BALLOON POP", "FORTUNES", "SWEET TREATS", "LOST AND FOUND"]
	for i in 4:
		stall(Vector3(11.0, 0.0, STALL_E[i]), -PI * 0.5, tints[i], ne[i], i % 3)
		stall(Vector3(-11.0, 0.0, STALL_W[i]), PI * 0.5, tints[i + 4], nw[i], (i + 1) % 3)
	windows.append([Vector3(11.4, 0.0, 48.0), Vector3(-1.0, 0.0, 0.0)])
	windows.append([Vector3(-11.4, 0.0, 40.0), Vector3(1.0, 0.0, 0.0)])
	trash(Vector3(6.0, 0.0, 50.0))
	trash(Vector3(-6.0, 0.0, 20.0))

func cart(p: Vector3, yaw: float, tint: Material) -> void:
	box(nav, Vector3(1.6, 0.9, 1.0), p + Vector3(0.0, 0.75, 0.0), tint, yaw)
	box(self, Vector3(1.4, 0.8, 0.9), p + Vector3(0.0, 1.6, 0.0), mats["glass"], yaw, false)
	box(self, Vector3(1.8, 0.1, 1.2), p + Vector3(0.0, 2.1, 0.0), mats["white"], yaw, false)
	for s in [-1.0, 1.0]:
		var w := pillar(self, 0.35, 0.12, p + Vector3(0.0, 0.35, s * 0.6), mats["dark"], false)
		w.rotation.x = PI * 0.5

func build_plaza() -> void:
	for i in 16:
		var a := i * TAU / 16.0
		box(nav, Vector3(2.3, 0.9, 0.7), Vector3(sin(a) * 5.5, 0.45, cos(a) * 5.5), mats["stone"], a)
	pillar(self, 5.0, 0.1, Vector3(0.0, 0.05, 0.0), mats["dark"], false)
	pillar(nav, 1.5, 1.25, Vector3(0.0, 0.625, 0.0), mats["stone"], true, 1.9)
	statue_spots.append([Vector3(0.0, 1.25, 0.0), "walker"])
	for i in 4:
		var a := i * TAU / 4.0 + PI * 0.25
		bench(Vector3(sin(a) * 10.0, 0.0, cos(a) * 10.0), a + PI)
	cart(Vector3(-12.0, 0.0, 13.0), 0.6, mats["red"])
	cart(Vector3(12.0, 0.0, -13.0), 2.5, mats["c1"])
	trash(Vector3(12.0, 0.0, 10.0))
	trash(Vector3(-12.0, 0.0, -10.0))

func horse(p: Vector3, a: float, m: Material) -> void:
	var hn := Node3D.new()
	hn.position = p + Vector3(0.0, 1.4, 0.0)
	hn.rotation.y = -a + PI * 0.5
	carousel.add_child(hn)
	box(hn, Vector3(0.5, 0.7, 1.5), Vector3.ZERO, m, 0.0, false)
	var neck := box(hn, Vector3(0.3, 0.85, 0.35), Vector3(0.0, 0.55, 0.7), m, 0.0, false)
	neck.rotation.x = 0.45
	var hd := box(hn, Vector3(0.28, 0.34, 0.75), Vector3(0.0, 0.95, 1.12), m, 0.0, false)
	hd.rotation.x = -0.35
	box(hn, Vector3(0.12, 0.22, 0.08), Vector3(0.0, 1.22, 0.8), mats["dark"], 0.0, false)
	ball(hn, 0.045, Vector3(0.12, 1.02, 1.28), mats["gold"])
	ball(hn, 0.045, Vector3(-0.12, 1.02, 1.28), mats["gold"])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pillar(hn, 0.07, 0.9, Vector3(sx * 0.18, -0.7, sz * 0.55), m, false)
	var tl := box(hn, Vector3(0.1, 0.7, 0.2), Vector3(0.0, -0.1, -0.85), mats["dark"], 0.0, false)
	tl.rotation.x = 0.3
	pillar(carousel, 0.05, 4.2, Vector3(p.x, 2.2, p.z), mats["gold"], false)
	horses.append([hn, hn.position.y, randf() * TAU])

func bumper_car(p: Vector3, yaw: float, ci: int) -> void:
	box(nav, Vector3(1.6, 0.6, 1.2), p + Vector3(0.0, 0.45, 0.0), mats["c%d" % ci], yaw)
	var dome := ball(self, 0.5, p + Vector3(0.0, 0.85, 0.0), mats["c%d" % ci])
	dome.scale = Vector3(1.0, 0.7, 0.9)
	pillar(self, 0.03, 5.0, p + Vector3(-0.5, 3.2, 0.0), mats["metal"], false)
	ball(self, 0.09, p + Vector3(0.65, 0.5, 0.0), mats["bulb"])

func build_west() -> void:
	var c := carousel_pos
	carousel = Node3D.new()
	carousel.position = c
	add_child(carousel)
	var plat := pillar(carousel, 7.2, 0.12, Vector3(0.0, 0.06, 0.0), mats["wood"], false)
	plat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar(carousel, 0.35, 5.0, Vector3(0.0, 2.5, 0.0), mats["gold"], false)
	for i in 8:
		var a := i * TAU / 8.0
		horse(Vector3(cos(a) * 4.8, 0.0, sin(a) * 4.8), a, mats["c%d" % (i % 6)])
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 8.0
	cone.height = 2.8
	var cm := MeshInstance3D.new()
	cm.mesh = cone
	cm.material_override = mats["tent_uv"]
	cm.position = Vector3(0.0, 6.2, 0.0)
	carousel.add_child(cm)
	pillar(carousel, 8.0, 0.7, Vector3(0.0, 4.6, 0.0), mats["tent_uv"], false)
	for i in 14:
		var a2 := i * TAU / 14.0
		ball(carousel, 0.12, Vector3(cos(a2) * 7.9, 4.2, sin(a2) * 7.9), mats["bulb"])
	omni(self, c + Vector3(0.0, 4.0, 0.0), Color(1.0, 0.5, 0.3), 1.4, 12.0, true)
	building(Vector3(-60.0, 0.0, 40.0), 10.0, 9.0, 4.0, "e", mats["paint"], 3.8)
	box(nav, Vector3(1.4, 0.9, 1.4), Vector3(-62.5, 0.45, 40.0), mats["wood"])
	box(self, Vector3(0.2, 3.4, 2.4), Vector3(-64.6, 1.7, 36.5), mats["red"], 0.0, false)
	box(self, Vector3(0.2, 3.4, 2.4), Vector3(-64.6, 1.7, 43.5), mats["red"], 0.0, false)
	lbl("FORTUNE", Vector3(-54.8, 3.6, 40.0), PI * 0.5, 80, Color(0.4, 0.6, 1.0))
	omni(self, Vector3(-60.0, 2.6, 40.0), Color(0.3, 0.5, 1.0), 1.6, 9.0, true)
	box(nav, Vector3(3.0, 0.5, 2.6), Vector3(-44.0, 0.25, 28.0), mats["wood"])
	for s in [-1.0, 1.0]:
		box(self, Vector3(0.08, 2.6, 2.4), Vector3(-44.0 + s * 1.3, 1.8, 28.0), mats["glass"], 0.0, false)
		box(self, Vector3(2.6, 2.6, 0.08), Vector3(-44.0, 1.8, 28.0 + s * 1.2), mats["glass"], 0.0, false)
	box(self, Vector3(2.4, 1.8, 2.2), Vector3(-44.0, 1.4, 28.0), mats["water"], 0.0, false)
	box(self, Vector3(1.0, 0.1, 0.6), Vector3(-44.0, 3.2, 28.0), mats["wood"], 0.0, false)
	var tgt := pillar(self, 0.5, 0.1, Vector3(-46.2, 1.4, 28.0), mats["red"], false)
	tgt.rotation.z = PI * 0.5
	lbl("DUNK THE CLOWN", Vector3(-44.0, 4.4, 28.0), PI * 0.5, 50, Color(0.85, 0.7, 0.2))
	pillar(self, 9.0, 0.06, Vector3(-76.0, 0.04, 14.0), mats["water"], false)
	var pond := pillar(nav, 9.3, 1.0, Vector3(-76.0, 0.5, 14.0), mats["dark"])
	pond.visible = false
	box(self, Vector3(3.0, 0.15, 11.0), Vector3(-67.0, 0.65, 14.0), mats["wood"], PI * 0.5, false)
	for k in 4:
		pillar(self, 0.12, 1.0, Vector3(-71.0 + k * 2.4, 0.2, 12.4), mats["wood"], false)
		pillar(self, 0.12, 1.0, Vector3(-71.0 + k * 2.4, 0.2, 15.6), mats["wood"], false)
	var boat := box(self, Vector3(3.2, 0.5, 1.2), Vector3(-79.0, 0.15, 10.0), mats["wood"], 0.5, false)
	boat.rotation.z = 0.08
	for k in 22:
		var a3 := k * TAU / 22.0
		var rd := pillar(self, 0.025, randf_range(1.2, 2.2), Vector3(-76.0 + cos(a3) * 8.7, 0.8, 14.0 + sin(a3) * 8.7), mats["bark"], false)
		rd.rotation.z = randf_range(-0.2, 0.2)
		sway(rd, 0.1, randf_range(0.8, 1.6))
	box(self, Vector3(24.0, 0.1, 16.0), Vector3(-72.0, 0.06, -44.0), mats["path"], 0.0, false)
	for s in [-1.0, 1.0]:
		for t2 in [-1.0, 1.0]:
			box(nav, Vector3(0.5, 6.0, 0.5), Vector3(-72.0 + s * 11.8, 3.0, -44.0 + t2 * 7.8), mats["metal"])
	box(self, Vector3(26.0, 0.4, 18.0), Vector3(-72.0, 6.2, -44.0), mats["metal"], 0.0, false)
	box(nav, Vector3(24.0, 0.9, 0.3), Vector3(-72.0, 0.45, -51.8), mats["metal"])
	box(nav, Vector3(24.0, 0.9, 0.3), Vector3(-72.0, 0.45, -36.2), mats["metal"])
	box(nav, Vector3(0.3, 0.9, 16.0), Vector3(-83.8, 0.45, -44.0), mats["metal"])
	box(nav, Vector3(0.3, 0.9, 5.2), Vector3(-60.2, 0.45, -49.0), mats["metal"])
	box(nav, Vector3(0.3, 0.9, 5.2), Vector3(-60.2, 0.45, -39.0), mats["metal"])
	for i in 7:
		var a4 := i * TAU / 7.0
		var r4 := 4.0 if i % 2 == 0 else 6.5
		bumper_car(Vector3(-72.0 + cos(a4) * r4, 0.0, -44.0 + sin(a4) * r4), a4 * 2.0, i % 6)
	omni(self, Vector3(-72.0, 5.0, -44.0), Color(0.4, 0.6, 1.0), 1.5, 14.0, true)
	lbl("BUMPER CARS", Vector3(-60.0, 7.0, -44.0), PI * 0.5, 90, Color(0.85, 0.7, 0.2))

func ferris(c: Vector3) -> void:
	var root := Node3D.new()
	root.position = c
	add_child(root)
	wheel = Node3D.new()
	wheel.position = Vector3(0.0, 15.5, 0.0)
	root.add_child(wheel)
	for zz in [-1.1, 1.1]:
		var tm := TorusMesh.new()
		tm.inner_radius = 13.6
		tm.outer_radius = 14.0
		tm.rings = 48
		tm.ring_segments = 8
		var rim := MeshInstance3D.new()
		rim.mesh = tm
		rim.material_override = mats["metal"]
		rim.rotation_degrees.x = 90.0
		rim.position.z = zz
		deco(rim, 120.0)
		wheel.add_child(rim)
	for i in 12:
		var sp := box(wheel, Vector3(0.16, 27.6, 0.16), Vector3.ZERO, mats["metal"], 0.0, false)
		sp.rotation.z = i * PI / 12.0
		sp.visibility_range_end = 120.0
	ball(wheel, 1.1, Vector3.ZERO, mats["metal"])
	for i in 10:
		var a := i * TAU / 10.0
		var piv := Node3D.new()
		piv.position = Vector3(cos(a) * 14.0, sin(a) * 14.0, 0.0)
		wheel.add_child(piv)
		box(piv, Vector3(2.2, 1.7, 2.6), Vector3(0.0, -1.4, 0.0), mats["c%d" % (i % 6)], 0.0, false)
		box(piv, Vector3(2.5, 0.2, 2.9), Vector3(0.0, -0.45, 0.0), mats["dark"], 0.0, false)
		wheel_cabs.append(piv)
	for i in 24:
		var a2 := i * TAU / 24.0
		ball(wheel, 0.2, Vector3(cos(a2) * 14.1, sin(a2) * 14.1, 1.3), mats["bulb"])
	for sx in [-1.0, 1.0]:
		for sz in [-2.2, 2.2]:
			var leg := box(root, Vector3(0.5, 17.0, 0.5), Vector3(sx * 3.0, 7.75, sz), mats["metal"], 0.0, false)
			leg.rotation.z = sx * 0.37
			leg.visibility_range_end = 120.0
			box(nav, Vector3(1.2, 1.0, 1.2), Vector3(c.x + sx * 6.0, 0.5, c.z + sz), mats["metal"])

func build_east() -> void:
	ferris(Vector3(62.0, 0.0, -24.0))
	lbl("SKY WHEEL", Vector3(50.0, 4.4, -24.0), -PI * 0.5, 90, Color(0.85, 0.7, 0.2))
	building(Vector3(52.0, 0.0, -4.0), 6.0, 6.0, 3.4, "w", mats["metal"], 3.8)
	pillar(nav, 0.5, 0.9, Vector3(53.5, 0.45, -4.0), mats["metal"])
	omni(self, Vector3(52.5, 2.5, -4.0), Color(1.0, 0.3, 0.2), 1.2, 8.0, true)
	var c := Vector3(62.0, 0.0, 40.0)
	building(c, 24.0, 20.0, 9.0, "w", mats["paint"], 4.0)
	box(nav, Vector3(0.5, 5.0, 14.0), Vector3(56.0, 2.5, 37.4), mats["paint"])
	box(nav, Vector3(0.5, 5.0, 14.0), Vector3(62.0, 2.5, 42.6), mats["paint"])
	box(nav, Vector3(0.5, 5.0, 14.0), Vector3(68.0, 2.5, 37.4), mats["paint"])
	statue_spots.append([Vector3(53.0, 0.0, 34.0), "watcher"])
	statue_spots.append([Vector3(59.0, 0.0, 36.0), "watcher"])
	statue_spots.append([Vector3(65.0, 0.0, 46.0), "watcher"])
	for k in 7:
		var tooth := box(self, Vector3(0.9, 1.8, 0.5), Vector3(49.5, 3.9, 40.0 + (k - 3) * 1.3), mats["white"], 0.0, false)
		tooth.rotation.z = randf_range(-0.08, 0.08)
	for k in 5:
		box(self, Vector3(0.7, 1.1, 0.5), Vector3(49.6, 0.55, 33.0 + k * 0.01 + (k % 2) * 14.0 + k * 0.4), mats["white"], 0.0, false)
	box(self, Vector3(0.6, 1.0, 14.0), Vector3(49.5, 3.0, 40.0), mats["red"], 0.0, false)
	for s in [-1.0, 1.0]:
		ball(self, 1.5, Vector3(49.2, 7.0, 40.0 + s * 4.8), mats["bulb"])
		ball(self, 0.55, Vector3(47.9, 7.0, 40.0 + s * 4.8), mats["dark"])
	ball(self, 1.0, Vector3(49.0, 5.9, 40.0), mats["red"])
	lbl("FUNHOUSE", Vector3(49.2, 8.4, 40.0), -PI * 0.5, 100, Color(0.9, 0.7, 0.1))
	omni(self, Vector3(46.0, 2.8, 40.0), Color(1.0, 0.1, 0.1), 1.8, 10.0, true)
	omni(self, Vector3(59.0, 3.5, 40.0), Color(0.6, 0.2, 1.0), 2.0, 11.0)
	omni(self, Vector3(71.0, 3.0, 40.0), Color(1.0, 0.1, 0.1), 2.0, 9.0, true)
	for i in 3:
		wagon(Vector3(84.0, 0.0, 6.0 + i * 8.0))

func wagon(p: Vector3) -> void:
	box(nav, Vector3(2.6, 2.6, 6.0), p + Vector3(0.0, 1.7, 0.0), mats["metal"])
	box(self, Vector3(0.1, 2.0, 5.4), p + Vector3(-1.36, 1.8, 0.0), mats["dark"], 0.0, false)
	for k in 10:
		pillar(self, 0.04, 2.2, p + Vector3(-1.45, 1.8, -2.7 + k * 0.6), mats["steel"], false)
	for s in [-1.0, 1.0]:
		for t2 in [-1.0, 1.0]:
			var w := pillar(self, 0.5, 0.25, p + Vector3(s * 1.0, 0.5, t2 * 2.0), mats["dark"], false)
			w.rotation.z = PI * 0.5
	box(self, Vector3(3.0, 0.2, 6.4), p + Vector3(0.0, 3.1, 0.0), mats["wood"], 0.0, false)

func wreck(p: Vector3, yaw: float, ci: int) -> void:
	box(nav, Vector3(3.6, 1.1, 1.8), p + Vector3(0.0, 0.9, 0.0), mats["c%d" % ci], yaw)
	var cab := box(self, Vector3(1.8, 0.9, 1.6), p + Vector3(0.0, 1.95, 0.0), mats["c%d" % ((ci + 2) % 6)], yaw, false)
	cab.rotation.z = randf_range(-0.12, 0.12)
	for s in [-1.0, 1.0]:
		for t2 in [-1.0, 1.0]:
			if randf() < 0.8:
				var w := pillar(self, 0.4, 0.3, p + Vector3(cos(yaw) * s * 1.2 - sin(yaw) * t2 * 0.9, 0.4, -sin(yaw) * s * 1.2 - cos(yaw) * t2 * 0.9), mats["dark"], false)
				w.rotation.x = PI * 0.5

func build_north() -> void:
	var c := Vector3(-22.0, 0.0, -62.0)
	var n := 26
	var r := 16.0
	for i in n:
		if i == 6 or i == 7:
			continue
		var a := i * TAU / n
		box(nav, Vector3(2.0 * r * sin(PI / n) + 0.15, 6.5, 0.5), c + Vector3(r * sin(a), 3.25, r * cos(a)), mats["tent"], a)
		var trim := box(self, Vector3(1.5, 0.35, 0.2), c + Vector3(r * sin(a), 6.7, r * cos(a)), mats["red" if i % 2 == 0 else "white"], a, false)
		trim.rotation.x = 0.0
	var roof := CylinderMesh.new()
	roof.top_radius = 6.0
	roof.bottom_radius = 17.6
	roof.height = 3.6
	roof.radial_segments = 26
	var rm := MeshInstance3D.new()
	rm.mesh = roof
	rm.material_override = mats["tent_roof"]
	rm.position = c + Vector3(0.0, 8.3, 0.0)
	deco(rm, 130.0)
	add_child(rm)
	var roof2 := CylinderMesh.new()
	roof2.top_radius = 0.3
	roof2.bottom_radius = 6.0
	roof2.height = 5.2
	roof2.radial_segments = 26
	var rm2 := MeshInstance3D.new()
	rm2.mesh = roof2
	rm2.material_override = mats["tent_roof"]
	rm2.position = c + Vector3(0.0, 12.7, 0.0)
	deco(rm2, 130.0)
	add_child(rm2)
	pillar(self, 0.07, 3.0, c + Vector3(0.0, 15.8, 0.0), mats["metal"], false)
	var fl := box(self, Vector3(1.2, 0.7, 0.04), c + Vector3(0.7, 16.5, 0.0), mats["red"], 0.0, false)
	sway(fl, 0.2, 2.0)
	for k in 13:
		var ga := k * TAU / 13.0
		rope(c + Vector3(sin(ga) * 17.2, 7.0, cos(ga) * 17.2), c + Vector3(sin(ga) * 24.0, 0.05, cos(ga) * 24.0), 0.04, mats["rope"])
		pillar(self, 0.08, 0.7, c + Vector3(sin(ga) * 24.0, 0.3, cos(ga) * 24.0), mats["wood"], false)
	var ent := c + Vector3(r + 2.2, 0.0, 0.0)
	box(self, Vector3(4.6, 0.3, 5.6), ent + Vector3(0.0, 4.2, 0.0), mats["red"], 0.0, false)
	box(self, Vector3(0.3, 4.2, 5.6), ent + Vector3(2.2, 2.1, 0.0), mats["red"], 0.0, false)
	for sgn in [-1.0, 1.0]:
		box(nav, Vector3(4.6, 3.8, 0.3), ent + Vector3(0.0, 1.9, sgn * 2.8), mats["red"])
		box(self, Vector3(0.5, 3.4, 1.4), ent + Vector3(-2.0, 1.7, sgn * 1.7), mats["red"], 0.0, false)
	for k in 9:
		ball(self, 0.1, ent + Vector3(-2.35, 4.35, -2.4 + k * 0.6), mats["bulb"])
	lbl("BIG TOP", ent + Vector3(-2.45, 3.6, 0.0), PI * 0.5, 70, Color(0.9, 0.8, 0.5))
	box(nav, Vector3(5.0, 1.2, 10.0), c + Vector3(-11.0, 0.6, 0.0), mats["wood"])
	box(self, Vector3(0.3, 5.0, 12.0), c + Vector3(-13.6, 3.6, 0.0), mats["red"], 0.0, false)
	for row in 3:
		for k in 5:
			bench(c + Vector3(-3.0 + row * 4.0, 0.0, -6.0 + k * 3.0), -PI * 0.5)
	pillar(self, 0.03, 8.0, c + Vector3(2.0, 9.0, -3.0), mats["steel"], false)
	pillar(self, 0.03, 8.0, c + Vector3(2.0, 9.0, 3.0), mats["steel"], false)
	var tbar := pillar(self, 0.04, 6.2, c + Vector3(2.0, 5.1, 0.0), mats["steel"], false)
	tbar.rotation.x = PI * 0.5
	omni(self, c + Vector3(0.0, 4.5, 0.0), Color(1.0, 0.25, 0.2), 1.4, 17.0, true)
	var sp := SpotLight3D.new()
	sp.position = c + Vector3(-4.0, 6.0, 0.0)
	sp.rotation_degrees = Vector3(-70.0, 90.0, 0.0)
	sp.spot_range = 14.0
	sp.spot_angle = 32.0
	sp.light_energy = 3.0
	sp.light_color = Color(1.0, 0.85, 0.6)
	add_child(sp)
	var jc := Vector3(58.0, 0.0, -70.0)
	var wrecks := [Vector3(-6.0, 0.0, -4.0), Vector3(0.0, 0.0, -6.0), Vector3(6.0, 0.0, -3.0), Vector3(-3.0, 0.0, 4.0), Vector3(5.0, 0.0, 5.0)]
	for i in wrecks.size():
		wreck(jc + wrecks[i], i * 1.3 + 0.4, i % 6)
	for p2 in [Vector3(-9.0, 0.0, 5.0), Vector3(9.0, 0.0, -6.0), Vector3(0.0, 0.0, 10.0)]:
		for k in 4:
			pillar(nav if k == 0 else self, 0.55, 0.3, jc + p2 + Vector3(0.0, 0.15 + k * 0.3, 0.0), mats["dark"], k == 0)
	lbl("CLOWN CAR GRAVEYARD", Vector3(44.0, 5.0, -70.0), -PI * 0.5, 70, Color(0.85, 0.7, 0.2))
	var gc := Vector3(-58.0, 0.0, -84.0)
	building(gc, 7.0, 6.0, 3.6, "e", mats["metal"], 3.8)
	box(nav, Vector3(2.4, 1.4, 1.2), gc + Vector3(-1.4, 0.7, 0.0), mats["steel"])
	pillar(self, 0.1, 2.0, gc + Vector3(-1.4, 2.0, 1.0), mats["metal"], false)
	for k in 4:
		var cb := pillar(self, 0.05, 20.0, gc + Vector3(14.0, 0.06, -1.5 + k * 1.0), mats["dark"], false)
		cb.rotation.z = PI * 0.5
	omni(self, gc + Vector3(0.0, 2.8, 0.0), Color(1.0, 0.5, 0.2), 1.4, 9.0, true)
	lbl("POWER", Vector3(-54.4, 3.0, -84.0), PI * 0.5, 70, Color(0.85, 0.7, 0.2))
	var names := ["BOZO", "GIGGLES", "PEANUT", "SPARKY", "TWINKLES", "HONK", "NOODLES", "PATCHES", "JELLY", "POPPY", "DOODLE", "CHUCKLES"]
	for row in 2:
		for k in 6:
			var gx := 14.0 + k * 5.0
			var gz := -84.0 - row * 6.0
			box(nav, Vector3(0.9, 1.3, 0.28), Vector3(gx, 0.65, gz), mats["stone"])
			var tp := ball(self, 0.45, Vector3(gx, 1.3, gz), mats["stone"])
			tp.scale = Vector3(1.0, 0.8, 0.3)
			box(self, Vector3(1.0, 0.25, 2.2), Vector3(gx, 0.12, gz + 1.3), mats["bark"], 0.0, false)
			lbl(names[row * 6 + k], Vector3(gx, 0.95, gz + 0.17), 0.0, 36, Color(0.7, 0.7, 0.65))
	box(nav, Vector3(0.7, 4.0, 0.7), Vector3(10.0, 2.0, -86.0), mats["metal"])
	box(nav, Vector3(0.7, 4.0, 0.7), Vector3(10.0, 2.0, -92.0), mats["metal"])
	lbl("CLOWN CEMETERY", Vector3(10.0, 4.6, -89.0), -PI * 0.5, 60, Color(0.7, 0.1, 0.1))

func build_lamps() -> void:
	for p in LAMP_POS:
		lamp(p, randf() < 0.35)

func build_jacks() -> void:
	for p in JACKS:
		var n := Node3D.new()
		n.position = p
		n.rotation.y = randf() * TAU
		add_child(n)
		box(n, Vector3(0.8, 0.7, 0.8), Vector3(0.0, 0.35, 0.0), mats["c0"], 0.0, false)
		var jb := box(nav, Vector3(0.8, 0.7, 0.8), p + Vector3(0.0, 0.35, 0.0), mats["c0"])
		jb.visible = false
		var lid := Node3D.new()
		lid.position = Vector3(0.0, 0.7, -0.4)
		n.add_child(lid)
		box(lid, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.04, 0.4), mats["c1"], 0.0, false)
		var head := Node3D.new()
		head.position = Vector3(0.0, 0.1, 0.0)
		n.add_child(head)
		pillar(head, 0.04, 0.6, Vector3(0.0, -0.3, 0.0), mats["metal"], false)
		ball(head, 0.26, Vector3(0.0, 0.2, 0.0), mats["white"])
		ball(head, 0.06, Vector3(0.0, 0.18, 0.24), mats["red"])
		ball(head, 0.14, Vector3(-0.24, 0.26, 0.0), mats["red"])
		ball(head, 0.14, Vector3(0.24, 0.26, 0.0), mats["red"])
		ball(head, 0.035, Vector3(-0.09, 0.28, 0.23), mats["gold"])
		ball(head, 0.035, Vector3(0.09, 0.28, 0.23), mats["gold"])
		jacks.append({"pos": p, "lid": lid, "head": head, "st": 0, "snd": null})

func build_hearts() -> void:
	for i in HEART_AT.size():
		var hp: Vector3 = HEART_AT[i]
		var n := Node3D.new()
		n.position = hp
		add_child(n)
		var body := heart_mesh(n)
		var l := omni(n, Vector3(0.0, 0.1, 0.0), Color(1.0, 0.05, 0.08), 2.5, 7.0)
		var sn := Sfx.loop3d("heart", n, 4.0, 4.0)
		sn.max_distance = 50.0
		hearts.append({"node": n, "body": body, "pos": hp, "alive": true, "light": l, "snd": sn})

func build_knife() -> void:
	box(nav, Vector3(1.1, 1.0, 1.1), Vector3(KNIFE_AT.x, 0.5, KNIFE_AT.z), mats["wood"])
	knife_node = Node3D.new()
	knife_node.position = KNIFE_AT
	knife_node.rotation.y = 0.6
	add_child(knife_node)
	var km := knife_model(knife_node)
	km.rotation.z = PI * 0.5
	km.scale = Vector3.ONE * 1.3
	omni(knife_node, Vector3(0.0, 0.7, 0.0), Color(0.9, 0.95, 1.0), 1.4, 6.0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.85, 0.9, 1.0, 0.16)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beacon := pillar(knife_node, 0.07, 7.0, Vector3(0.0, 3.5, 0.0), bm, false)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_piles() -> void:
	var spots := [Vector3(15.0, 0.0, 78.0), Vector3(-19.0, 0.0, 78.0), Vector3(15.0, 0.0, 58.0), Vector3(-15.0, 0.0, 50.0), Vector3(20.0, 0.0, -4.0), Vector3(-22.0, 0.0, 16.0), Vector3(46.0, 0.0, -16.0), Vector3(-40.0, 0.0, -30.0), Vector3(-50.0, 0.0, 60.0), Vector3(48.0, 0.0, 60.0)]
	for i in spots.size():
		crate_pile(spots[i], 2 + i % 3)
	for z in range(-90, 91, 15):
		tree(Vector3(-94.0, 0.0, z + randf_range(-2.0, 2.0)))
		tree(Vector3(94.0, 0.0, z + randf_range(-2.0, 2.0)))
	for p in [Vector3(-86.0, 0.0, 26.0), Vector3(-68.0, 0.0, 28.0), Vector3(-84.0, 0.0, 2.0), Vector3(10.0, 0.0, -96.0), Vector3(44.0, 0.0, -96.0), Vector3(-40.0, 0.0, -96.0)]:
		tree(p)

func build_ambient() -> void:
	var cols := [Color(0.8, 0.1, 0.12), Color(0.9, 0.75, 0.15), Color(0.2, 0.3, 0.7), Color(0.85, 0.85, 0.8)]
	var zs := [74.0, 58.0, 42.0, 26.0, 10.0, -6.0, -22.0, -38.0, -54.0, -70.0, -86.0]
	var k := 0
	for z in zs:
		for s in [-1.0, 1.0]:
			var c: Color = cols[k % cols.size()]
			k += 1
			var n := Node3D.new()
			n.position = Vector3(s * 5.4, 2.8, float(z) + randf_range(-1.5, 1.5))
			add_child(n)
			var bm := mk(c, 0.25, "", false, 0.25, c * 0.5, 0.4)
			var bl := ball(n, 0.38, Vector3.ZERO, bm)
			bl.scale = Vector3(1.0, 1.25, 1.0)
			pillar(n, 0.008, 2.8, Vector3(0.0, -1.6, 0.0), mats["dark"], false)
			balloons.append([n, n.position, randf() * TAU])

func heart_mesh(par: Node3D) -> Node3D:
	var body := Node3D.new()
	par.add_child(body)
	var ps = load("res://heart.glb")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.05, 0.05, 0.0)
	body.set_meta("glow", glow)
	if ps is PackedScene:
		var inst: Node3D = ps.instantiate()
		body.add_child(inst)
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var am = mi.get_active_material(0)
			if am is StandardMaterial3D:
				var dm: StandardMaterial3D = am.duplicate()
				dm.roughness = 0.28
				dm.emission_enabled = true
				dm.emission = Color(0.55, 0.02, 0.02)
				dm.emission_energy_multiplier = 0.4
				mi.set_surface_override_material(0, dm)
			mi.material_overlay = glow
	else:
		var hm := mk(Color(0.5, 0.02, 0.04), 0.25, "", false, 0.25, Color(1.0, 0.04, 0.06), 1.4)
		ball(body, 0.2, Vector3(-0.12, 0.08, 0.0), hm)
		ball(body, 0.2, Vector3(0.12, 0.08, 0.0), hm)
	return body

func knife_model(par: Node3D) -> Node3D:
	var holder := Node3D.new()
	par.add_child(holder)
	var ps = load("res://knife.glb")
	if ps is PackedScene:
		var inst: Node3D = ps.instantiate()
		holder.add_child(inst)
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		box(holder, Vector3(0.012, 0.045, 0.32), Vector3(0.0, 0.0, -0.15), mats["steel"], 0.0, false)
		box(holder, Vector3(0.04, 0.045, 0.14), Vector3(0.0, 0.0, 0.1), mats["dark"], 0.0, false)
	return holder

# ---------------------------------------------------------------- blood
func init_blood() -> void:
	for i in 4:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://blood.png")
		m.uv1_scale = Vector3(0.5, 0.5, 1.0)
		m.uv1_offset = Vector3((i % 2) * 0.5, floorf(i / 2.0) * 0.5, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.12
		m.metallic = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		blood_mats.append(m)

func splat_floor(pos: Vector3, size: float) -> void:
	var mi := quad(Vector3(pos.x, 0.035 + randf() * 0.004, pos.z), Vector3(-PI * 0.5, randf() * TAU, 0.0), Vector2(size, size), blood_mats[randi() % 4])
	mi.visibility_range_end = 80.0
	splats.append(mi)
	if splats.size() > 240:
		splats[0].queue_free()
		splats.remove_at(0)

func wall_splat(pos: Vector3, normal: Vector3, size: float) -> void:
	var mi := quad(pos + normal * 0.03, Vector3.ZERO, Vector2(size, size), blood_mats[randi() % 4])
	mi.look_at(mi.global_position - normal, Vector3.UP)

func blood_pool(pos: Vector3, radius: float, dur: float) -> void:
	var mi := quad(Vector3(pos.x, 0.04, pos.z), Vector3(-PI * 0.5, randf() * TAU, 0.0), Vector2(1.0, 1.0), blood_mats[0])
	mi.scale = Vector3(0.2, 0.2, 1.0)
	create_tween().tween_property(mi, "scale", Vector3(radius * 2.0, radius * 2.0, 1.0), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	splats.append(mi)

func blood_fx(pos: Vector3, dir: Vector3, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.0, 0.02)
	pm.roughness = 0.1
	pm.metallic = 0.2
	sm.material = pm
	p.mesh = sm
	p.amount = amount
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 28.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)

func blood_spray(pos: Vector3, dir: Vector3, amount: int, speed: float) -> void:
	blood_fx(pos, dir, amount, speed)
	for i in amount:
		var d := (dir + Vector3(randf_range(-0.45, 0.45), randf_range(-0.2, 0.5), randf_range(-0.45, 0.45))).normalized()
		var v := d * speed * randf_range(0.35, 1.0)
		var tl := (v.y + sqrt(maxf(0.0, v.y * v.y + 19.6 * (pos.y - 0.03)))) / 9.8
		var land := Vector3(pos.x + v.x * tl, 0.0, pos.z + v.z * tl)
		drops.append({"t": tl, "p": land, "s": randf_range(0.18, 0.7)})

# ---------------------------------------------------------------- per-frame
func lamps_update(delta: float, t: float, on: bool) -> void:
	for l in lamps:
		var e: float = l.base
		if not on:
			e = 0.0
		elif l.faulty:
			l.ph += delta * (6.0 + randf() * 10.0)
			if sin(l.ph * 3.1) + sin(l.ph * 7.3) < -0.7:
				e *= 0.15
			else:
				e *= 0.9 + randf() * 0.1
		l.light.light_energy = e
		var swv: Vector3 = Vector3(sin(t * 1.3 + l.ph), 0.0, cos(t * 1.1 + l.ph)) * 0.2
		l.light.position = l.pos + swv
		if l.bulb != null:
			l.bulb.position = l.bpos + swv
		if l.mat != null:
			l.mat.emission_energy_multiplier = e * 0.9

func update(delta: float, t: float, ppos: Vector3) -> void:
	wheel.rotation.z += delta * 0.08
	if carousel_spin:
		carousel.rotation.y += delta * 0.12
	sky.global_position = ppos
	for i in wheel_cabs.size():
		var cb: Node3D = wheel_cabs[i]
		cb.rotation = Vector3(sin(t * 1.1 + i) * 0.06, 0.0, -wheel.rotation.z)
	var near: bool = ppos.distance_to(carousel.global_position) < 28.0
	var lp: Vector3 = carousel.to_local(ppos)
	for e in horses:
		var hn: Node3D = e[0]
		hn.position.y = float(e[1]) + sin(t * 2.2 + float(e[2])) * 0.3
		if near:
			var dd: Vector3 = lp - hn.position
			hn.rotation.y = lerp_angle(hn.rotation.y, atan2(dd.x, dd.z), minf(1.0, delta * 3.0))
	for e in sways:
		var n: Node3D = e[0]
		var br: Vector3 = e[1]
		n.rotation = br + Vector3(0.0, 0.0, sin(t * float(e[3]) + float(e[4])) * float(e[2]))
	for e in balloons:
		var bn: Node3D = e[0]
		var bp: Vector3 = e[1]
		var ph := float(e[2])
		bn.position = bp + Vector3(sin(t * 0.7 + ph) * 0.4, sin(t * 1.1 + ph) * 0.3, cos(t * 0.6 + ph) * 0.4)
		bn.rotation.z = sin(t * 0.9 + ph) * 0.12
	mats["poster"].emission_energy_multiplier = 0.5 + 0.2 * sin(t * 3.0) * sin(t * 17.0)
	mats["bulb"].emission_energy_multiplier = 1.5 + sin(t * 6.0) * 0.5
	var spawned := 0
	for dr in drops:
		dr.t -= delta
		if dr.t <= 0.0 and spawned < 10:
			splat_floor(dr.p, dr.s)
			dr.t = -999.0
			spawned += 1
	drops = drops.filter(func(e): return e.t > -900.0)

# ---------------------------------------------------------------- reference-style set dressing
func build_sky() -> void:
	sky = Node3D.new()
	add_child(sky)
	var sm := SphereMesh.new()
	sm.radius = 140.0
	sm.height = 280.0
	sm.radial_segments = 32
	sm.rings = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://sky.jpg")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(mi)
	var cm := CylinderMesh.new()
	cm.top_radius = 130.0
	cm.bottom_radius = 130.0
	cm.height = 38.0
	cm.radial_segments = 48
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = load("res://mountains.png")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.disable_fog = true
	var mt := MeshInstance3D.new()
	mt.mesh = cm
	mt.material_override = mm
	mt.position = Vector3(0.0, 12.0, 0.0)
	mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(mt)

func banner(p: Vector3, yaw: float, ti: int) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	add_child(s)
	box(nav, Vector3(0.22, 3.8, 0.22), p + Vector3(cos(yaw) * -2.4, 1.9, -sin(yaw) * -2.4), mats["wood"], yaw)
	box(nav, Vector3(0.22, 3.8, 0.22), p + Vector3(cos(yaw) * 2.4, 1.9, -sin(yaw) * 2.4), mats["wood"], yaw)
	box(s, Vector3(5.2, 0.25, 0.25), Vector3(0.0, 3.8, 0.0), mats["wood"], 0.0, false)
	for sx in [-1.0, 0.0, 1.0]:
		var br := box(s, Vector3(0.14, 2.0, 0.14), Vector3(sx * 2.4, 1.7, -0.9), mats["wood"], 0.0, false)
		br.rotation.x = 0.5
	for k in 2:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://banner%d.jpg" % ((ti + k * 2) % 4))
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var q := quad(Vector3.ZERO, Vector3.ZERO, Vector2(2.3, 2.9), m)
		remove_child(q)
		s.add_child(q)
		q.position = Vector3(-1.2 + k * 2.4, 2.3, 0.05)
		q.rotation.y = randf_range(-0.05, 0.05)
		sway(q, 0.05, randf_range(0.8, 1.4))

func build_banners() -> void:
	var spec := [[Vector3(-18.0, 0.0, 52.0), PI * 0.5, 0], [Vector3(18.0, 0.0, 52.0), -PI * 0.5, 1], [Vector3(-19.0, 0.0, -8.0), PI * 0.5, 2], [Vector3(19.0, 0.0, -8.0), -PI * 0.5, 0], [Vector3(-14.0, 0.0, -34.0), PI * 0.5, 1], [Vector3(18.0, 0.0, -50.0), -PI * 0.5, 2], [Vector3(-17.0, 0.0, 76.0), PI * 0.5, 3], [Vector3(17.0, 0.0, 76.0), -PI * 0.5, 2]]
	for e in spec:
		banner(e[0], e[1], e[2])

func build_hay_and_ropes() -> void:
	for z in [72.0, 62.0, 34.0, 18.0, -14.0, -34.0, -56.0, -72.0]:
		for s in [-1.0, 1.0]:
			var bx0: float = s * (7.6 + randf() * 0.6)
			box(nav, Vector3(1.0, 0.5, 0.6), Vector3(bx0, 0.25, z + randf_range(-1.5, 1.5)), mats["hay"], randf() * 0.6)
			if randf() < 0.6:
				box(nav, Vector3(0.9, 0.45, 0.55), Vector3(bx0 + 0.1, 0.72, z + 0.2), mats["hay"], randf() * 0.6)
	var lanes := [0.0, 12.0, 40.0, -24.0, -44.0, -70.0]
	var z := 74.0
	while z > -92.0:
		var skip := false
		for lz in lanes:
			if absf(z - lz) < 5.5:
				skip = true
		if not skip and absf(z) > 17.0:
			for s in [-1.0, 1.0]:
				var a := Vector3(s * 6.6, 1.0, z)
				var b := Vector3(s * 6.6, 1.0, z - 4.0)
				box(self, Vector3(0.14, 1.1, 0.14), Vector3(a.x, 0.55, a.z), mats["wood"], 0.0, false)
				rope(a, b, 0.025, mats["rope"])
		z -= 4.0

func small_tent(c: Vector3, door_a: float, wall: Material) -> void:
	var n := 8
	var r := 3.8
	for i in n:
		var a := i * TAU / n
		if absf(wrapf(a - door_a, -PI, PI)) < 0.4:
			continue
		box(nav, Vector3(2.0 * r * sin(PI / n) + 0.1, 2.4, 0.2), c + Vector3(r * sin(a), 1.2, r * cos(a)), wall, a)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = r + 0.5
	cm.height = 3.0
	cm.radial_segments = 8
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mats["tent_roof"]
	mi.position = c + Vector3(0.0, 3.9, 0.0)
	deco(mi)
	add_child(mi)
	for k in 8:
		var a2 := k * TAU / 8.0
		rope(c + Vector3(sin(a2) * (r + 0.4), 2.6, cos(a2) * (r + 0.4)), c + Vector3(sin(a2) * (r + 2.6), 0.05, cos(a2) * (r + 2.6)), 0.02, mats["rope"])

func build_small_tents() -> void:
	small_tent(Vector3(27.0, 0.0, 62.0), PI * 1.5, mats["tent_o"])
	small_tent(Vector3(-28.0, 0.0, 60.0), PI * 0.5, mats["tent_c"])
	small_tent(Vector3(-30.0, 0.0, -26.0), PI * 0.5, mats["tent_y"])

func wagon_red(p: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	nav.add_child(s)
	box(s, Vector3(2.6, 0.3, 5.6), Vector3(0.0, 1.0, 0.0), mats["red"])
	box(s, Vector3(0.15, 2.0, 5.4), Vector3(1.25, 2.1, 0.0), mats["red"])
	box(s, Vector3(2.6, 2.0, 0.15), Vector3(0.0, 2.1, -2.7), mats["red"])
	box(s, Vector3(2.8, 0.3, 5.8), Vector3(0.0, 3.25, 0.0), mats["red"], 0.0, false)
	for k in 12:
		pillar(s, 0.035, 2.0, Vector3(-1.25, 2.1, -2.5 + k * 0.45), mats["steel"], false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := pillar(s, 0.62, 0.14, Vector3(sx * 1.45, 0.62, sz * 1.9), mats["wood"], false)
			w.rotation.z = PI * 0.5
			for k in 8:
				var sp := box(s, Vector3(0.05, 1.2, 0.05), Vector3(sx * 1.45, 0.62, sz * 1.9), mats["wood"], 0.0, false)
				sp.rotation.x = k * PI / 8.0
	lbl("MENAGERIE", p + Vector3(0.0, 3.6, 0.0), yaw, 40, Color(0.85, 0.7, 0.2))

func ticket_kiosk(p: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	nav.add_child(s)
	box(s, Vector3(1.6, 2.2, 1.2), Vector3(0.0, 1.1, 0.0), mats["red"])
	box(s, Vector3(1.9, 0.2, 1.5), Vector3(0.0, 2.35, 0.0), mats["red"], 0.0, false)
	box(s, Vector3(1.0, 0.6, 0.08), Vector3(0.0, 1.5, 0.62), mats["dark"], 0.0, false)
	lbl("TICKETS", p + Vector3(0.0, 2.7, 0.0), yaw, 36, Color(0.85, 0.7, 0.2))

func build_circus_props() -> void:
	for p in [Vector3(-9.0, 0.45, 76.0), Vector3(10.0, 0.45, 70.0), Vector3(24.0, 0.45, 56.0), Vector3(-24.0, 0.45, 52.0), Vector3(-26.0, 0.45, -20.0), Vector3(50.0, 0.45, 18.0)]:
		var b := ball(self, 0.45, p, mats["tent"])
		b.rotation = Vector3(randf() * 3.0, randf() * 3.0, 0.0)
	for p in [Vector3(30.0, 0.0, 58.0), Vector3(-31.0, 0.0, 64.0), Vector3(-32.0, 0.0, -22.0)]:
		for k in 3:
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.48
			tm.rings = 24
			tm.ring_segments = 6
			var h := MeshInstance3D.new()
			h.mesh = tm
			h.material_override = mats["c%d" % ((k * 2) % 6)]
			h.position = p + Vector3(k * 0.9, 0.5, 0.0)
			h.rotation = Vector3(PI * 0.5 - 0.3, randf() * 2.0, 0.0)
			deco(h)
			add_child(h)
	for p in [Vector3(-12.5, 0.0, 12.0), Vector3(13.0, 0.0, 28.0), Vector3(-13.0, 0.0, -20.0), Vector3(13.0, 0.0, -36.0), Vector3(-26.0, 0.0, 30.0), Vector3(22.0, 0.0, -14.0), Vector3(-44.0, 0.0, 10.0), Vector3(40.0, 0.0, 22.0)]:
		pillar(nav, 0.5, 1.0, p + Vector3(0.0, 0.5, 0.0), mats["tent"], true, 0.45)
		pillar(self, 0.46, 0.06, p + Vector3(0.0, 1.0, 0.0), mats["water"], false)
	var warns := [[Vector3(7.5, 0.0, 66.0), -PI * 0.5], [Vector3(-7.5, 0.0, 30.0), PI * 0.5], [Vector3(84.0, 0.0, 14.0), -PI * 0.5], [Vector3(-15.0, 0.0, 80.0), 0.3], [Vector3(10.0, 0.0, -60.0), -PI * 0.5]]
	for w in warns:
		var wp: Vector3 = w[0]
		var wy: float = w[1]
		box(nav, Vector3(0.1, 1.2, 0.1), wp + Vector3(0.0, 0.6, 0.0), mats["wood"], wy)
		box(self, Vector3(1.5, 0.9, 0.08), wp + Vector3(0.0, 1.5, 0.0), mats["red"], wy, false)
		lbl("WARNING\nKEEP A SAFE\nDISTANCE FROM\nTHE CAGES", wp + Vector3(0.0, 1.5, 0.0) + Vector3(sin(wy), 0.0, cos(wy)) * 0.06, wy, 20, Color(0.92, 0.88, 0.8))
	wagon_red(Vector3(-84.0, 0.0, -10.0), PI * 0.5)
	wagon_red(Vector3(88.0, 0.0, -50.0), -PI * 0.5)
	ticket_kiosk(Vector3(-10.0, 0.0, 22.0), PI * 0.5)
	ticket_kiosk(Vector3(10.0, 0.0, -50.0), -PI * 0.5)
	var rc := Vector3(46.0, 0.0, -46.0)
	for i in 12:
		if i == 3:
			continue
		var a := i * TAU / 12.0
		var pn := box(nav, Vector3(1.7, 2.3, 0.1), rc + Vector3(sin(a) * 3.4, 1.15, cos(a) * 3.4), mats["paint"], a)
		pn.rotation.z = randf_range(-0.04, 0.04)
	for p in [Vector3(26.0, 0.0, 10.0), Vector3(-34.0, 0.0, 6.0), Vector3(-26.0, 0.0, 44.0)]:
		for k in 5:
			ball(self, 0.07, p + Vector3(randf_range(-0.8, 0.8), 0.07, randf_range(-0.8, 0.8)), mats["red"])

func build_string_lights() -> void:
	for i in range(0, 10):
		var a: Vector3 = LAMP_POS[i]
		var b: Vector3 = LAMP_POS[i + 1]
		a.y = 5.4
		b.y = 5.4
		for k in 13:
			var u := k / 12.0
			var p := a.lerp(b, u)
			p.y -= sin(u * PI) * 0.9
			var bl := ball(self, 0.07, p, mats["bulb"])
			bl.visibility_range_end = 70.0
			if k % 4 == 2:
				var fl := box(self, Vector3(0.22, 0.34, 0.02), p + Vector3(0.0, -0.3, 0.0), mats["c%d" % (k % 6)], 0.0, false)
				fl.rotation.z = PI * 0.25
				sway(fl, 0.2, randf_range(1.5, 2.5))

func build_puddles() -> void:
	var pts := [Vector3(2.0, 0.0, 74.0), Vector3(-3.0, 0.0, 58.0), Vector3(1.0, 0.0, 30.0), Vector3(3.0, 0.0, 8.0), Vector3(-2.0, 0.0, -16.0), Vector3(2.0, 0.0, -34.0), Vector3(-2.0, 0.0, -58.0), Vector3(1.0, 0.0, -80.0), Vector3(-20.0, 0.0, 1.0), Vector3(22.0, 0.0, 12.0), Vector3(-34.0, 0.0, 40.0), Vector3(30.0, 0.0, 40.0), Vector3(34.0, 0.0, -24.0), Vector3(-38.0, 0.0, -44.0), Vector3(12.0, 0.0, 6.0), Vector3(-10.0, 0.0, -4.0)]
	for p in pts:
		var sz := randf_range(1.4, 3.4)
		var q := quad(Vector3(p.x, 0.05, p.z), Vector3(-PI * 0.5, randf() * TAU, 0.0), Vector2(sz, sz * randf_range(0.5, 0.9)), mats["water"])
		q.visibility_range_end = 70.0

func hide_cabinet(p: Vector3, face: Vector3) -> void:
	var yaw := atan2(face.x, face.z)
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	nav.add_child(s)
	box(s, Vector3(1.7, 2.5, 0.12), Vector3(0.0, 1.25, -0.6), mats["wood"])
	box(s, Vector3(0.12, 2.5, 1.3), Vector3(-0.8, 1.25, 0.0), mats["wood"])
	box(s, Vector3(0.12, 2.5, 1.3), Vector3(0.8, 1.25, 0.0), mats["wood"])
	box(s, Vector3(1.9, 0.14, 1.5), Vector3(0.0, 2.55, 0.0), mats["wood"], 0.0, false)
	for sgn in [-1.0, 1.0]:
		var d := box(s, Vector3(0.78, 2.3, 0.05), Vector3(sgn * 0.62, 1.2, 0.66), mats["wood"], sgn * 0.7, false)
		for k in 6:
			box(d, Vector3(0.6, 0.03, 0.02), Vector3(0.0, -0.8 + k * 0.3, 0.03), mats["dark"], 0.0, false)
	lbl("COSTUMES", p + Vector3(face.x * 0.5, 2.9, face.z * 0.5), yaw, 22, Color(0.85, 0.7, 0.2))
	hide_spots.append({"pos": Vector3(p.x, 0.1, p.z), "face": face})

func build_hides() -> void:
	var spec := [[Vector3(14.5, 0.0, 70.0), Vector3(-1.0, 0.0, 0.0)], [Vector3(-14.5, 0.0, 62.0), Vector3(1.0, 0.0, 0.0)], [Vector3(14.5, 0.0, 40.0), Vector3(-1.0, 0.0, 0.0)], [Vector3(-14.5, 0.0, 10.0), Vector3(1.0, 0.0, 0.0)], [Vector3(14.5, 0.0, -8.0), Vector3(-1.0, 0.0, 0.0)], [Vector3(-14.5, 0.0, -18.0), Vector3(1.0, 0.0, 0.0)], [Vector3(14.5, 0.0, -48.0), Vector3(-1.0, 0.0, 0.0)], [Vector3(-14.5, 0.0, -80.0), Vector3(1.0, 0.0, 0.0)]]
	for e in spec:
		hide_cabinet(e[0], e[1])

func plaque(text: String, p: Vector3, yaw: float) -> void:
	box(self, Vector3(1.9, 1.1, 0.08), p, mats["wood"], yaw, false)
	lbl(text, p + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.06, yaw, 17, Color(0.85, 0.8, 0.65))

func build_lore() -> void:
	plaque("THE LAST SHOW\nOPENED 1987\nCLOSED 1991\nTHE LAUGHTER NEVER LEFT", Vector3(-7.0, 1.7, 86.0), 0.0)
	plaque("HE PAID FOR EVERY\nLAUGH WITH A PIECE\nOF HIMSELF", Vector3(7.0, 1.7, 8.0), -PI * 0.5)
	plaque("FIRST HEART\nWHERE THE CHILDREN\nLAUGHED LOUDEST", Vector3(47.0, 1.7, 33.0), -PI * 0.5)
	plaque("SECOND HEART\nBENEATH THE WHEEL\nWHERE THE LIGHTS DIED", Vector3(49.0, 1.7, -8.0), -PI * 0.5)
	plaque("THIRD HEART\nTHE MUSIC\nNEVER STOPPED", Vector3(-39.0, 1.7, -6.0), PI * 0.5)
	plaque("FOURTH HEART\nTHE FINAL ACT\nNEVER ENDED", Vector3(-5.5, 1.7, -56.0), PI * 0.5)
	plaque("FIFTH HEART\nSHE SAW IT COMING", Vector3(-54.5, 1.7, 44.0), PI * 0.5)
	plaque("BOZO. GIGGLES. PEANUT.\nTHEY ALL STAYED.", Vector3(11.0, 1.5, -80.0), -PI * 0.5)
	plaque("DON'T LOOK BACK", Vector3(-54.0, 1.7, -78.0), PI * 0.5)
	plaque("THE KEY IS WHERE\nHE KEEPS WHAT\nHE LOVES MOST", Vector3(6.0, 1.7, -92.0), -PI * 0.5)

func build_anomalies() -> void:
	var bench_spots := [Vector3(7.0, 0.0, 66.0), Vector3(-7.0, 0.0, 28.0), Vector3(7.0, 0.0, -30.0), Vector3(-7.0, 0.0, -66.0)]
	for p in bench_spots:
		var n := Node3D.new()
		n.position = p + Vector3(0.0, 0.62, 0.0)
		n.rotation.y = randf() * TAU
		n.visible = false
		add_child(n)
		ball(n, 0.2, Vector3.ZERO, mats["white"])
		ball(n, 0.05, Vector3(0.0, -0.02, 0.19), mats["red"])
		ball(n, 0.1, Vector3(-0.2, 0.05, 0.0), mats["red"])
		ball(n, 0.1, Vector3(0.2, 0.05, 0.0), mats["red"])
		ball(n, 0.03, Vector3(-0.07, 0.04, 0.17), mats["gold"])
		ball(n, 0.03, Vector3(0.07, 0.04, 0.17), mats["gold"])
		anomalies.append({"node": n, "pos": p, "shown": false})
	var writs := [["BEHIND YOU", Vector3(9.4, 2.0, 80.0), -PI * 0.5], ["HE SEES YOU", Vector3(-9.4, 2.0, 62.0), PI * 0.5], ["STOP RUNNING", Vector3(6.2, 2.4, -2.0), -PI * 0.5], ["LET ME OUT", Vector3(-6.2, 2.0, -52.0), PI * 0.5]]
	for w in writs:
		var l := Label3D.new()
		l.text = w[0]
		l.font = Sfx.font
		l.font_size = 64
		l.pixel_size = 0.01
		l.modulate = Color(0.55, 0.02, 0.03)
		l.outline_size = 4
		l.shaded = false
		l.double_sided = true
		l.position = w[1]
		l.rotation.y = w[2]
		l.visible = false
		l.visibility_range_end = 60.0
		add_child(l)
		anomalies.append({"node": l, "pos": w[1], "shown": false})
