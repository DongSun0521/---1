extends SceneTree

const SHEETS := [
	"res://assets/art/buildings/KeYanSuo_sheet.png",
	"res://assets/art/buildings/MinJun_sheet.png",
	"res://assets/art/buildings/NongTian_sheet.png",
	"res://assets/art/buildings/ShiWu_sheet.png",
	"res://assets/art/buildings/WuQi_sheet.png",
	"res://assets/art/buildings/YiYuan_sheet.png",
	"res://assets/art/buildings/ZiYuanShoujiSuo_sheet.png",
]


func _init() -> void:
	for path: String in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			print("%s|ERROR" % path)
			continue
		var width := image.get_width()
		var height := image.get_height()
		var format_name := _format_name(image.get_format())
		var has_alpha := image.detect_alpha() != Image.ALPHA_NONE
		var cell_width := width / 4
		var cell_height := height
		var rects := [
			Rect2i(0, 0, cell_width, cell_height),
			Rect2i(cell_width, 0, cell_width, cell_height),
			Rect2i(cell_width * 2, 0, cell_width, cell_height),
			Rect2i(cell_width * 3, 0, cell_width, cell_height),
		]
		print("%s|%dx%d|%s|alpha=%s|horizontal-4|%s" % [
			path.get_file(),
			width,
			height,
			format_name,
			str(has_alpha),
			"; ".join(rects.map(func(rect: Rect2i) -> String: return str(rect))),
		])
	quit()


func _format_name(format: Image.Format) -> String:
	match format:
		Image.FORMAT_RGBA8:
			return "RGBA8"
		Image.FORMAT_RGB8:
			return "RGB8"
		Image.FORMAT_LA8:
			return "LA8"
		Image.FORMAT_RGBAF:
			return "RGBAF"
	return str(format)
