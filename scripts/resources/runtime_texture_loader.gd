extends RefCounted

static var _texture_cache: Dictionary = {}
static var _frame_cache: Dictionary = {}
static var _sprite_frames_cache: Dictionary = {}

static func load_texture(resource_path: String) -> Texture2D:
	if _texture_cache.has(resource_path):
		return _texture_cache[resource_path]

	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK:
		push_warning("Failed to load texture at %s" % resource_path)
		return null

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[resource_path] = texture
	return texture

static func load_frame_texture(resource_path: String, columns: int, rows: int, frame_index: int, trim_alpha: bool = true) -> Texture2D:
	var frames: Array[Texture2D] = load_frame_textures(resource_path, columns, rows, [frame_index], trim_alpha)
	return frames[0] if not frames.is_empty() else null

static func load_frame_textures(resource_path: String, columns: int, rows: int, frame_indices: Array = [], trim_alpha: bool = false) -> Array[Texture2D]:
	var cache_key := "%s|%d|%d|%s|%s" % [resource_path, columns, rows, ",".join(_to_string_array(frame_indices)), str(trim_alpha)]
	if _frame_cache.has(cache_key):
		return _frame_cache[cache_key]

	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return []

	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK:
		push_warning("Failed to load texture at %s" % resource_path)
		return []

	if columns <= 0 or rows <= 0:
		var full_texture: Array[Texture2D] = [ImageTexture.create_from_image(image)]
		_frame_cache[cache_key] = full_texture
		return full_texture

	var frame_width := image.get_width() / columns
	var frame_height := image.get_height() / rows
	var max_frames := columns * rows
	var requested_indices: Array = frame_indices if not frame_indices.is_empty() else range(max_frames)
	var textures: Array[Texture2D] = []
	for raw_frame_index in requested_indices:
		var frame_index := clampi(int(raw_frame_index), 0, max_frames - 1)
		var frame_x := (frame_index % columns) * frame_width
		var frame_y := int(frame_index / columns) * frame_height
		var frame_image := image.get_region(Rect2i(frame_x, frame_y, frame_width, frame_height))
		if trim_alpha:
			var crop_rect := _get_alpha_bounds(frame_image)
			if crop_rect.size.x > 0 and crop_rect.size.y > 0:
				frame_image = frame_image.get_region(crop_rect)
		textures.append(ImageTexture.create_from_image(frame_image))

	_frame_cache[cache_key] = textures
	return textures

static func load_sprite_frames(resource_path: String, columns: int, rows: int, frame_indices: Array, fps: float, trim_alpha: bool = false) -> SpriteFrames:
	var cache_key := "%s|%d|%d|%s|%s|%s" % [resource_path, columns, rows, ",".join(_to_string_array(frame_indices)), str(fps), str(trim_alpha)]
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key]

	var textures: Array[Texture2D] = load_frame_textures(resource_path, columns, rows, frame_indices, trim_alpha)
	if textures.is_empty():
		return null

	var sprite_frames := SpriteFrames.new()
	if not sprite_frames.has_animation("default"):
		sprite_frames.add_animation("default")
	sprite_frames.set_animation_loop("default", true)
	sprite_frames.set_animation_speed("default", fps)
	for texture in textures:
		sprite_frames.add_frame("default", texture)

	_sprite_frames_cache[cache_key] = sprite_frames
	return sprite_frames

static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

static func _get_alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, 0, 0)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
