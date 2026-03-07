extends RefCounted

static func load_texture(resource_path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK:
		push_warning("Failed to load texture at %s" % resource_path)
		return null

	return ImageTexture.create_from_image(image)

static func load_frame_texture(resource_path: String, columns: int, rows: int, frame_index: int) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK:
		push_warning("Failed to load texture at %s" % resource_path)
		return null

	if columns <= 0 or rows <= 0:
		return ImageTexture.create_from_image(image)

	var frame_width := image.get_width() / columns
	var frame_height := image.get_height() / rows
	var frame_x := (frame_index % columns) * frame_width
	var frame_y := int(frame_index / columns) * frame_height
	var frame_image := image.get_region(Rect2i(frame_x, frame_y, frame_width, frame_height))
	var crop_rect := _get_alpha_bounds(frame_image)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return ImageTexture.create_from_image(frame_image)

	return ImageTexture.create_from_image(frame_image.get_region(crop_rect))

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
