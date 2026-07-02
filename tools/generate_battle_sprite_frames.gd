@tool
extends SceneTree

const FRAME_WIDTH := 221
const FRAME_HEIGHT := 221

const SHEETS := [
	{
		"source": "res://assets/art/characters/processed/FaShi_transparent.png",
		"output": "res://assets/art/characters/sprite_frames/FaShi_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
	{
		"source": "res://assets/art/characters/processed/ZhanShi_transparent.png",
		"output": "res://assets/art/characters/sprite_frames/ZhanShi_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 5},
	},
	{
		"source": "res://assets/art/characters/processed/YouXia_transparent.png",
		"output": "res://assets/art/characters/sprite_frames/YouXia_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
	{
		"source": "res://assets/art/characters/processed/ZhiLiao_transparent.png",
		"output": "res://assets/art/characters/sprite_frames/ZhiLiao_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
	{
		"source": "res://assets/art/monster/processed/monster01_transparent.png",
		"output": "res://assets/art/monster/sprite_frames/monster01_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
	{
		"source": "res://assets/art/boss/processed/ShuJing_transparent.png",
		"output": "res://assets/art/boss/sprite_frames/ShuJing_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
	{
		"source": "res://assets/art/boss/processed/HuoYuanSu_transparent.png",
		"output": "res://assets/art/boss/sprite_frames/HuoYuanSu_frames.tres",
		"counts": {"idle": 6, "attack": 8, "hit": 6, "death": 6},
	},
]

const ANIM_ROWS := {
	"idle": 0,
	"attack": 1,
	"hit": 2,
	"death": 3,
}
const ANIM_SPEEDS := {
	"idle": 6.0,
	"attack": 10.0,
	"hit": 10.0,
	"death": 8.0,
}
const ANIM_LOOPS := {
	"idle": true,
	"attack": false,
	"hit": false,
	"death": false,
}


func _init() -> void:
	for sheet: Dictionary in SHEETS:
		generate_sprite_frames(sheet)
	quit()


func generate_sprite_frames(sheet: Dictionary) -> void:
	var image := Image.new()
	var image_error := image.load(String(sheet["source"]))
	if image_error != OK:
		push_error("Missing sprite sheet: %s" % String(sheet["source"]))
		return
	var texture := ImageTexture.create_from_image(image)

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var counts: Dictionary = sheet["counts"]
	for animation_name: String in ["idle", "attack", "hit", "death"]:
		var anim := StringName(animation_name)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(ANIM_SPEEDS[animation_name]))
		frames.set_animation_loop(anim, bool(ANIM_LOOPS[animation_name]))
		var row: int = int(ANIM_ROWS[animation_name])
		var frame_count: int = int(counts[animation_name])
		for column in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * FRAME_WIDTH, row * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)
			frames.add_frame(anim, atlas)

	var error := ResourceSaver.save(frames, String(sheet["output"]))
	if error != OK:
		push_error("Unable to save SpriteFrames: %s" % String(sheet["output"]))
	else:
		print("Saved ", String(sheet["output"]))
