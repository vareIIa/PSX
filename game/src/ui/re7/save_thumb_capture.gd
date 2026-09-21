## SaveThumbCapture — Onda 4 PREP helper (API stub).
## GO copia → game/src/ui/re7/save_thumb_capture.gd
## Thumbnail real via viewport só pós-GO runtime; PREP = placeholder TextureRect.
## Spec: docs/specs/SPEC_SAVE_CARDS_RE7.md
class_name SaveThumbCapture
extends RefCounted

const THUMB_DIR := "user://save_thumbs"
const THUMB_W := 72
const THUMB_H := 40


## Captura pixels do Viewport → Image (RGB8). Stub seguro: redimensiona se preciso.
static func capture_viewport_to_image(viewport: Viewport) -> Image:
	if viewport == null:
		return Image.create(THUMB_W, THUMB_H, false, Image.FORMAT_RGBA8)
	var tex: ViewportTexture = viewport.get_texture()
	if tex == null:
		return Image.create(THUMB_W, THUMB_H, false, Image.FORMAT_RGBA8)
	var img: Image = tex.get_image()
	if img == null:
		return Image.create(THUMB_W, THUMB_H, false, Image.FORMAT_RGBA8)
	if img.get_width() != THUMB_W or img.get_height() != THUMB_H:
		img.resize(THUMB_W, THUMB_H, Image.INTERPOLATE_BILINEAR)
	return img


## Grava PNG em user://save_thumbs/slot_{espaco}.png · retorna path absoluto lógico.
static func save_thumb_local(espaco: int, image: Image) -> String:
	var path := _path_for(espaco)
	if image == null:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THUMB_DIR))
	var err := image.save_png(path)
	if err != OK:
		push_warning("SaveThumbCapture: falha ao gravar %s (err=%d)" % [path, err])
		return ""
	return path


## Carrega Texture2D do thumb local; null se ausente.
static func load_thumb_local(espaco: int) -> Texture2D:
	var path := _path_for(espaco)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _path_for(espaco: int) -> String:
	return "%s/slot_%d.png" % [THUMB_DIR, clampi(espaco, 0, 2)]
