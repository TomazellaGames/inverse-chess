extends SceneTree
## Headless rules check. Run with:
##   godot --headless --path . -s res://tests/test_rules.gd

const ChessGameScript := preload("res://scripts/chess_game.gd")
const SimpleAIScript := preload("res://scripts/simple_ai.gd")

# [fen, depth, expected nodes] — standard perft reference positions.
const CASES := [
	["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 3, 8902],
	["r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 2, 2039],
	["8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 4, 43238],
	["r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 3, 9467],
	["rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 3, 62379],
]


func _init() -> void:
	var failed := 0
	for c in CASES:
		var g = ChessGameScript.new()
		g.load_fen(c[0])
		var t0 := Time.get_ticks_msec()
		var n := _perft(g, c[1])
		var ok: bool = n == c[2]
		if not ok:
			failed += 1
		print("%s perft(%d) = %d (expected %d) in %d ms" % ["OK  " if ok else "FAIL", c[1], n, c[2], Time.get_ticks_msec() - t0])

	# Fool's mate: white is checkmated, so in inverse chess white wins.
	var g = ChessGameScript.new()
	for san in ["f3", "e5", "g4", "Qh4#"]:
		var played := false
		for m in g.legal_moves():
			if g.move_to_san(m) == san:
				g.play(m)
				played = true
				break
		if not played:
			print("FAIL could not play ", san)
			failed += 1
	var mated: bool = g.get_status() == ChessGameScript.Status.CHECKMATE and g.turn == ChessGameScript.WHITE
	print("OK   fool's mate detected" if mated else "FAIL fool's mate not detected")
	if not mated:
		failed += 1

	# AI timing from the opening position.
	var ai = SimpleAIScript.new()
	var g2 = ChessGameScript.new()
	var t1 := Time.get_ticks_msec()
	for i in 6:
		var m: int = ai.choose_move(g2)
		g2.play(m)
	print("AI: 6 plies in %d ms" % (Time.get_ticks_msec() - t1))

	print("ALL PASSED" if failed == 0 else "%d FAILED" % failed)
	quit(failed)


func _perft(g, depth: int) -> int:
	if depth == 0:
		return 1
	var moves: PackedInt32Array = g.legal_moves()
	if depth == 1:
		return moves.size()
	var n := 0
	for m in moves:
		g.make_move(m)
		n += _perft(g, depth - 1)
		g.unmake_move()
	return n
