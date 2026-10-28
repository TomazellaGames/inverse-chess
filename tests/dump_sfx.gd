extends SceneTree
## Renders every synthesized sound to WAV files for listening:
##   godot --headless --path . -s res://tests/dump_sfx.gd -- <output_dir>
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := OS.get_cmdline_user_args()[0]
	var sfx := GameAudio.new()
	var t0 := Time.get_ticks_msec()
	root.add_child(sfx)
	await process_frame
	print("synthesized %d sounds in %d ms" % [sfx._streams.size(), Time.get_ticks_msec() - t0])
	for sound in sfx._streams:
		(sfx._streams[sound] as AudioStreamWAV).save_to_wav(out_dir.path_join(sound + ".wav"))
	quit()
