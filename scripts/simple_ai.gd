class_name SimpleAI
extends RefCounted
## A deliberately simple inverse-chess opponent.
## Looks two plies ahead (its move, your reply) and scores positions by how
## close its own king is to being checkmated — and how far yours is.

const WIN := 100000.0
const DRAW := -300.0

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func choose_move(game: ChessGame) -> int:
	var me := game.turn
	var moves := game.legal_moves()
	if moves.is_empty():
		return -1
	var best_score := -INF
	var best_move := moves[0]
	for m in moves:
		# Random jitter keeps games varied; applied before search so pruning stays valid.
		var jitter := rng.randf_range(0.0, 10.0)
		game.make_move(m)
		var score := _worst_reply(game, me, best_score - jitter) + jitter
		game.unmake_move()
		if score > best_score:
			best_score = score
			best_move = m
	return best_move


## Opponent is to move. Returns the score of their best reply (worst for us).
func _worst_reply(game: ChessGame, me: int, alpha: float) -> float:
	var replies := game.legal_moves()
	if replies.is_empty():
		# We just checkmated them: in inverse chess that hands them the win.
		return -WIN if game.in_check(-me) else DRAW
	var worst := INF
	for r in replies:
		game.make_move(r)
		var s: float
		if game.in_check(me) and not game.has_legal_move():
			s = WIN
		else:
			s = _evaluate(game, me)
		game.unmake_move()
		if s < worst:
			worst = s
			if worst <= alpha:
				break
	return worst


func _evaluate(game: ChessGame, me: int) -> float:
	var score := 0.0
	var my_king := game.king_of(me)
	var opp_king := game.king_of(-me)
	# We want our own king boxed in, and theirs free to roam.
	score -= _king_freedom(game, my_king, me) * 12.0
	score += _king_freedom(game, opp_king, -me) * 6.0
	if game.in_check(me):
		score += 20.0
	if game.in_check(-me):
		score -= 30.0
	# March our king toward the enemy army.
	var advance := (my_king >> 3) if me == ChessGame.WHITE else 7 - (my_king >> 3)
	score += advance * 5.0
	# Enemy attackers near our king are welcome; keep the enemy strong.
	var kf := my_king & 7
	var kr := my_king >> 3
	for s in 64:
		var p := game.board[s]
		if p == 0 or (p > 0) == (me == ChessGame.WHITE) or absi(p) == ChessGame.KING:
			continue
		var dist := maxi(absi((s & 7) - kf), absi((s >> 3) - kr))
		score += (7 - dist) * 1.5
	score += game.material(-me) * 3.0 - game.material(me) * 1.0
	return score


## Adjacent squares the king could step to without being attacked.
func _king_freedom(game: ChessGame, ksq: int, side: int) -> int:
	var f := ksq & 7
	var r := ksq >> 3
	var free := 0
	for d in ChessGame.KING_STEPS:
		var f1: int = f + d[0]
		var r1: int = r + d[1]
		if f1 < 0 or f1 > 7 or r1 < 0 or r1 > 7:
			continue
		var t := r1 * 8 + f1
		var q := game.board[t]
		if q != 0 and (q > 0) == (side == ChessGame.WHITE):
			continue
		if not game.is_attacked(t, -side):
			free += 1
	return free
