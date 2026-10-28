extends SceneTree
## Drives the real main scene: plays games (random moves for the player) and
## saves screenshots of every screen. Run windowed (not headless) for screenshots:
##   godot --path . -s res://tests/smoke.gd -- <output_dir>

const MOVE_CAP := 160


func _init() -> void:
	_run.call_deferred()


func _shot(out_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.3).timeout
	await _shot(out_dir, "splash")
	await create_timer(2.5).timeout
	print("splash gone: ", not is_instance_valid(main._splash), ", music playing: ", main.audio._music.playing)
	await _shot(out_dir, "menu")

	var results := {}
	for i in 2:
		var side := ChessGame.WHITE if i % 2 == 0 else ChessGame.BLACK
		main._start_game(side)
		while not main.game_over and main.game.move_count() < MOVE_CAP:
			if main.game.turn == side and not main.ai_thinking:
				var moves: PackedInt32Array = main.game.legal_moves()
				main._commit(moves[randi() % moves.size()])
			await process_frame
			if i == 0 and main.game.move_count() == 12:
				await _shot(out_dir, "game")
		var info: Array = main._result_info(main.game.get_status())
		print("game %d (%s): %s after %d moves" % [i, "white" if side == 1 else "black", info[0], main.game.move_count()])
		results[info[0]] = results.get(info[0], 0) + 1
	await create_timer(1.0).timeout
	await _shot(out_dir, "result")
	main._result.visible = false

	for overlay in ["credits", "audio"]:
		main._open_overlay(overlay)
		await _shot(out_dir, overlay)
		main._hide_overlays()

	DisplayServer.window_set_size(Vector2i(450, 800))
	await create_timer(0.5).timeout
	await _shot(out_dir, "portrait")
	main._open_overlay("credits")
	await _shot(out_dir, "portrait_credits")
	print(results)
	quit()
