@tool
extends SceneTree

const SPECS := [
	{"source": "res://assets/art/effect/projectiles/magic_bolt_sheet.png", "output": "res://assets/art/effect/sprite_frames/magic_bolt_frames.tres", "frame_width": 192, "frame_height": 1024, "count": 8, "fps": 12.0, "loop": true},
	{"source": "res://assets/art/effect/impact/hit_spark_sheet.png", "output": "res://assets/art/effect/sprite_frames/hit_spark_frames.tres", "frame_width": 310, "frame_height": 724, "count": 7, "fps": 12.0, "loop": false},
	{"source": "res://assets/art/effect/impact/arcane_burst_sheet.png", "output": "res://assets/art/effect/sprite_frames/arcane_burst_frames.tres", "frame_width": 192, "frame_height": 1024, "count": 8, "fps": 12.0, "loop": false},
	{"source": "res://assets/art/effect/heal/heal_circle_sheet.png", "output": "res://assets/art/effect/sprite_frames/heal_circle_frames.tres", "frame_width": 192, "frame_height": 1024, "count": 8, "fps": 10.0, "loop": false},
	{"source": "res://assets/art/effect/boss/earth_spike_sheet.png", "output": "res://assets/art/effect/sprite_frames/earth_spike_frames.tres", "frame_width": 192, "frame_height": 1024, "count": 8, "fps": 10.0, "loop": false},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/art/effect/sprite_frames"))
	for spec: Dictionary in SPECS:
		generate_frames(spec)
	quit()


func generate_frames(spec: Dictionary) -> void:
	var source_path := String(spec["source"])
	var texture := load(source_path) as Texture2D
	if texture == null:
		push_error("Unable to load battle effect sheet: %s" % source_path)
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_speed(&"play", float(spec["fps"]))
	frames.set_animation_loop(&"play", bool(spec["loop"]))
	for index in range(int(spec["count"])):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * int(spec["frame_width"]), 0, int(spec["frame_width"]), int(spec["frame_height"]))
		frames.add_frame(&"play", atlas)
	var error := ResourceSaver.save(frames, String(spec["output"]))
	if error != OK:
		push_error("Unable to save battle effect frames: %s" % String(spec["output"]))
	else:
		print("Saved ", String(spec["output"]))
