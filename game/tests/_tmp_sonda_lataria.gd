## Sonda temporaria do cerco: mede a lataria do Marea da estrada (altura do
## topo por x,z), as aberturas e o amassado da batida.
extends Node

func _ready() -> void:
	var carro := CarroCena.new()
	carro.com_som = false
	add_child(carro)
	await get_tree().process_frame
	var m: Dictionary = carro.medidas()
	print("comp=%s larg=%s alt=%s eixo=%s bitola=%s" % [m["comprimento"], m["largura"], m["altura"], m["entre_eixos"], m["bitola"]])
	print("vidro_base=%s vidro_topo=%s" % [m.get("vidro_base"), m.get("vidro_topo")])
	for a: Dictionary in m.get("aberturas", []):
		print("ABERTURA tipo=%s lado=%s centro=%s normal=%s" % [a["tipo"], a.get("lado"), a.get("centro"), a.get("normal")])
		print("   pontos=%s" % [a["pontos"]])
		if a.has("contorno"):
			var c: PackedVector3Array = a["contorno"]
			print("   contorno n=%d primeiro=%s" % [c.size(), c[0]])
	if carro.cabine != null:
		print("olho=%s piso=%s teto=%s painel=%s" % [carro.cabine.olho(), carro.cabine.piso_da_cabine(), carro.cabine.teto(), carro.cabine.topo_do_painel()])
		for y: float in [0.95, 1.0, 1.1, 1.2, 1.3]:
			print("  z_do_vidro(%.2f)=%.3f" % [y, carro.cabine.z_do_vidro(y)])
	var malha := m["corpo"] as ArrayMesh
	print("superficies=%d" % malha.get_surface_count())
	var arr := malha.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print("vertices=%d indices=%d" % [v.size(), idx.size()])
	var passo := 0.05
	var nx := 40
	var nz := 96
	var x0 := -1.0
	var z0 := -2.4
	var alt := PackedFloat32Array()
	alt.resize(nx * nz)
	alt.fill(-1.0)
	var ntri := idx.size() / 3 if idx.size() > 0 else v.size() / 3
	for t in ntri:
		var a := v[idx[t * 3]] if idx.size() > 0 else v[t * 3]
		var b := v[idx[t * 3 + 1]] if idx.size() > 0 else v[t * 3 + 1]
		var c := v[idx[t * 3 + 2]] if idx.size() > 0 else v[t * 3 + 2]
		var mnx := mini(nx - 1, maxi(0, floori((minf(a.x, minf(b.x, c.x)) - x0) / passo)))
		var mxx := mini(nx - 1, maxi(0, ceili((maxf(a.x, maxf(b.x, c.x)) - x0) / passo)))
		var mnz := mini(nz - 1, maxi(0, floori((minf(a.z, minf(b.z, c.z)) - z0) / passo)))
		var mxz := mini(nz - 1, maxi(0, ceili((maxf(a.z, maxf(b.z, c.z)) - z0) / passo)))
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-9:
			continue
		for iz in range(mnz, mxz + 1):
			for ix in range(mnx, mxx + 1):
				var px := x0 + ix * passo
				var pz := z0 + iz * passo
				var l1 := ((b.x - px) * (c.z - pz) - (c.x - px) * (b.z - pz)) / d
				var l2 := ((c.x - px) * (a.z - pz) - (a.x - px) * (c.z - pz)) / d
				var l3 := 1.0 - l1 - l2
				if l1 < -0.001 or l2 < -0.001 or l3 < -0.001:
					continue
				var y := a.y * l1 + b.y * l2 + c.y * l3
				var k := iz * nx + ix
				if y > alt[k]:
					alt[k] = y
	var linha := "   z   x  "
	for ix in range(0, nx, 2):
		linha += "%6.2f" % (x0 + ix * passo)
	print(linha)
	for iz in range(0, nz, 2):
		var s := "%7.2f  " % (z0 + iz * passo)
		for ix in range(0, nx, 2):
			var y := alt[iz * nx + ix]
			s += "%6.2f" % y if y > -0.5 else "     ."
		print(s)
	# O amassado da batida.
	carro.preparar_batida()
	carro.amassar_frente(1.0, 1.0)
	for i in 30:
		await get_tree().process_frame
	var am = carro.get("_amassado")
	print("amassado=%s" % [am])
	if am != null:
		print("   dent (desloc) em pontos do capo:")
		for z: float in [-2.1, -1.9, -1.7, -1.5, -1.3, -1.1, -0.95]:
			var s := "   z=%5.2f " % z
			for x: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				var ix := roundi((x - x0) / passo)
				var iz := roundi((z - z0) / passo)
				var y := alt[iz * nx + ix]
				var dd: Vector3 = am.deslocamento(Vector3(x, y, z))
				s += " (%+.3f,%+.3f,%+.3f)" % [dd.x, dd.y, dd.z]
			print(s)
	get_tree().quit(0)
