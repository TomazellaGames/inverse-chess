class_name ChessGame
extends RefCounted
## Chess rules: board state, legal move generation, make/unmake and game status.
## Squares are indexed 0..63 as rank * 8 + file (a1 = 0, h8 = 63).
## Pieces are signed ints: positive = white, negative = black.
## Moves are packed ints: from | to << 6 | promo << 12 | flags << 16.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const WHITE := 1
const BLACK := -1

const FLAG_EP := 1
const FLAG_CASTLE := 2
const FLAG_DOUBLE := 4

const CASTLE_WK := 1
const CASTLE_WQ := 2
const CASTLE_BK := 4
const CASTLE_BQ := 8

enum Status { ONGOING, CHECKMATE, STALEMATE, DRAW_FIFTY, DRAW_MATERIAL, DRAW_REPETITION }

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const PIECE_LETTERS := ".PNBRQK"
const FILES := "abcdefgh"

const KNIGHT_STEPS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_STEPS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const ROOK_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
const BISHOP_DIRS := [[1, 1], [1, -1], [-1, 1], [-1, -1]]
const PROMOTIONS := [QUEEN, ROOK, BISHOP, KNIGHT]

var board := PackedInt32Array()
var turn: int = WHITE
var castling: int = 15
var ep_square: int = -1
var halfmove: int = 0
var fullmove: int = 1
var white_king: int = 4
var black_king: int = 60

var _undo: Array = []
var _keys: Array[String] = []
var _castle_mask := PackedInt32Array()


func _init() -> void:
	_castle_mask.resize(64)
	_castle_mask.fill(15)
	_castle_mask[0] = 15 & ~CASTLE_WQ
	_castle_mask[4] = 15 & ~(CASTLE_WK | CASTLE_WQ)
	_castle_mask[7] = 15 & ~CASTLE_WK
	_castle_mask[56] = 15 & ~CASTLE_BQ
	_castle_mask[60] = 15 & ~(CASTLE_BK | CASTLE_BQ)
	_castle_mask[63] = 15 & ~CASTLE_BK
	load_fen(START_FEN)


# --- Move encoding helpers -------------------------------------------------

static func encode(from: int, to: int, promo: int = 0, flags: int = 0) -> int:
	return from | (to << 6) | (promo << 12) | (flags << 16)


static func move_from(m: int) -> int:
	return m & 63


static func move_to(m: int) -> int:
	return (m >> 6) & 63


static func move_promo(m: int) -> int:
	return (m >> 12) & 7


static func move_flags(m: int) -> int:
	return m >> 16


static func square_name(s: int) -> String:
	return FILES[s & 7] + str((s >> 3) + 1)


static func square_from_name(n: String) -> int:
	return FILES.find(n[0]) + (n.substr(1).to_int() - 1) * 8


# --- Setup ------------------------------------------------------------------

func load_fen(fen: String) -> void:
	board.resize(64)
	board.fill(EMPTY)
	var parts := fen.strip_edges().split(" ")
	var rank := 7
	var file := 0
	for c in parts[0]:
		if c == "/":
			rank -= 1
			file = 0
		elif c.is_valid_int():
			file += c.to_int()
		else:
			var t := PIECE_LETTERS.find(c.to_upper())
			var p := t if c == c.to_upper() else -t
			var s := rank * 8 + file
			board[s] = p
			if p == KING:
				white_king = s
			elif p == -KING:
				black_king = s
			file += 1
	turn = BLACK if parts.size() > 1 and parts[1] == "b" else WHITE
	castling = 0
	if parts.size() > 2:
		if "K" in parts[2]:
			castling |= CASTLE_WK
		if "Q" in parts[2]:
			castling |= CASTLE_WQ
		if "k" in parts[2]:
			castling |= CASTLE_BK
		if "q" in parts[2]:
			castling |= CASTLE_BQ
	ep_square = -1
	if parts.size() > 3 and parts[3] != "-":
		ep_square = square_from_name(parts[3])
	halfmove = parts[4].to_int() if parts.size() > 4 else 0
	fullmove = parts[5].to_int() if parts.size() > 5 else 1
	_undo.clear()
	_keys.clear()
	_keys.append(position_key())


func position_key() -> String:
	return "%s|%d|%d|%d" % [str(board), turn, castling, ep_square]


func king_of(side: int) -> int:
	return white_king if side == WHITE else black_king


# --- Attacks ----------------------------------------------------------------

func is_attacked(sq: int, by: int) -> bool:
	var f := sq & 7
	var r := sq >> 3
	# Pawns of `by` attack diagonally forward, so they sit one rank "behind" sq.
	var pr := r - by
	if pr >= 0 and pr <= 7:
		if f > 0 and board[pr * 8 + f - 1] == PAWN * by:
			return true
		if f < 7 and board[pr * 8 + f + 1] == PAWN * by:
			return true
	for d in KNIGHT_STEPS:
		var f1: int = f + d[0]
		var r1: int = r + d[1]
		if f1 >= 0 and f1 <= 7 and r1 >= 0 and r1 <= 7 and board[r1 * 8 + f1] == KNIGHT * by:
			return true
	for d in KING_STEPS:
		var f1: int = f + d[0]
		var r1: int = r + d[1]
		if f1 >= 0 and f1 <= 7 and r1 >= 0 and r1 <= 7 and board[r1 * 8 + f1] == KING * by:
			return true
	if _ray_hits(f, r, ROOK_DIRS, ROOK * by, QUEEN * by):
		return true
	return _ray_hits(f, r, BISHOP_DIRS, BISHOP * by, QUEEN * by)


func _ray_hits(f: int, r: int, dirs: Array, a: int, b: int) -> bool:
	for d in dirs:
		var df: int = d[0]
		var dr: int = d[1]
		var f1 := f + df
		var r1 := r + dr
		while f1 >= 0 and f1 <= 7 and r1 >= 0 and r1 <= 7:
			var q := board[r1 * 8 + f1]
			if q != EMPTY:
				if q == a or q == b:
					return true
				break
			f1 += df
			r1 += dr
	return false


func in_check(side: int) -> bool:
	return is_attacked(king_of(side), -side)


# --- Move generation --------------------------------------------------------

func _gen_pseudo(moves: PackedInt32Array) -> void:
	var side := turn
	for s in 64:
		var p := board[s]
		if p == EMPTY or (p > 0) != (side == WHITE):
			continue
		var t := absi(p)
		var f := s & 7
		var r := s >> 3
		if t == PAWN:
			_gen_pawn(moves, s, f, r, side)
		elif t == KNIGHT:
			_gen_steps(moves, s, f, r, side, KNIGHT_STEPS)
		elif t == BISHOP:
			_gen_slides(moves, s, f, r, side, BISHOP_DIRS)
		elif t == ROOK:
			_gen_slides(moves, s, f, r, side, ROOK_DIRS)
		elif t == QUEEN:
			_gen_slides(moves, s, f, r, side, ROOK_DIRS)
			_gen_slides(moves, s, f, r, side, BISHOP_DIRS)
		else:
			_gen_steps(moves, s, f, r, side, KING_STEPS)
			_gen_castles(moves, side)


func _is_enemy(q: int, side: int) -> bool:
	return q != EMPTY and (q > 0) != (side == WHITE)


func _add_pawn_move(moves: PackedInt32Array, from: int, to: int, promote: bool) -> void:
	if promote:
		for pr in PROMOTIONS:
			moves.append(encode(from, to, pr))
	else:
		moves.append(encode(from, to))


func _gen_pawn(moves: PackedInt32Array, s: int, f: int, r: int, side: int) -> void:
	var start_rank := 1 if side == WHITE else 6
	var promo_rank := 7 if side == WHITE else 0
	var r1 := r + side
	if r1 < 0 or r1 > 7:
		return
	var one := r1 * 8 + f
	if board[one] == EMPTY:
		_add_pawn_move(moves, s, one, r1 == promo_rank)
		if r == start_rank:
			var two := (r + 2 * side) * 8 + f
			if board[two] == EMPTY:
				moves.append(encode(s, two, 0, FLAG_DOUBLE))
	for df in [-1, 1]:
		var f1: int = f + df
		if f1 < 0 or f1 > 7:
			continue
		var t := r1 * 8 + f1
		if _is_enemy(board[t], side):
			_add_pawn_move(moves, s, t, r1 == promo_rank)
		elif t == ep_square:
			moves.append(encode(s, t, 0, FLAG_EP))


func _gen_steps(moves: PackedInt32Array, s: int, f: int, r: int, side: int, steps: Array) -> void:
	for d in steps:
		var f1: int = f + d[0]
		var r1: int = r + d[1]
		if f1 < 0 or f1 > 7 or r1 < 0 or r1 > 7:
			continue
		var t := r1 * 8 + f1
		var q := board[t]
		if q == EMPTY or _is_enemy(q, side):
			moves.append(encode(s, t))


func _gen_slides(moves: PackedInt32Array, s: int, f: int, r: int, side: int, dirs: Array) -> void:
	for d in dirs:
		var df: int = d[0]
		var dr: int = d[1]
		var f1 := f + df
		var r1 := r + dr
		while f1 >= 0 and f1 <= 7 and r1 >= 0 and r1 <= 7:
			var t := r1 * 8 + f1
			var q := board[t]
			if q == EMPTY:
				moves.append(encode(s, t))
			else:
				if _is_enemy(q, side):
					moves.append(encode(s, t))
				break
			f1 += df
			r1 += dr


func _gen_castles(moves: PackedInt32Array, side: int) -> void:
	var base := 0 if side == WHITE else 56
	var ks := CASTLE_WK if side == WHITE else CASTLE_BK
	var qs := CASTLE_WQ if side == WHITE else CASTLE_BQ
	if board[base + 4] != KING * side or (castling & (ks | qs)) == 0:
		return
	var enemy := -side
	if castling & ks and board[base + 5] == EMPTY and board[base + 6] == EMPTY \
			and board[base + 7] == ROOK * side and not is_attacked(base + 4, enemy) \
			and not is_attacked(base + 5, enemy) and not is_attacked(base + 6, enemy):
		moves.append(encode(base + 4, base + 6, 0, FLAG_CASTLE))
	if castling & qs and board[base + 3] == EMPTY and board[base + 2] == EMPTY \
			and board[base + 1] == EMPTY and board[base] == ROOK * side \
			and not is_attacked(base + 4, enemy) and not is_attacked(base + 3, enemy) \
			and not is_attacked(base + 2, enemy):
		moves.append(encode(base + 4, base + 2, 0, FLAG_CASTLE))


func legal_moves() -> PackedInt32Array:
	var pseudo := PackedInt32Array()
	_gen_pseudo(pseudo)
	var legal := PackedInt32Array()
	var side := turn
	for m in pseudo:
		make_move(m)
		if not is_attacked(king_of(side), -side):
			legal.append(m)
		unmake_move()
	return legal


func has_legal_move() -> bool:
	var pseudo := PackedInt32Array()
	_gen_pseudo(pseudo)
	var side := turn
	for m in pseudo:
		make_move(m)
		var ok := not is_attacked(king_of(side), -side)
		unmake_move()
		if ok:
			return true
	return false


# --- Make / unmake ----------------------------------------------------------

func make_move(m: int) -> void:
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flags := m >> 16
	var piece := board[from]
	var captured := board[to]
	if flags & FLAG_EP:
		var cap_sq := to - 8 * turn
		captured = board[cap_sq]
		board[cap_sq] = EMPTY
	_undo.append([m, captured, castling, ep_square, halfmove, white_king, black_king])
	board[to] = piece if promo == 0 else promo * turn
	board[from] = EMPTY
	if flags & FLAG_CASTLE:
		if to > from:
			board[from + 1] = board[from + 3]
			board[from + 3] = EMPTY
		else:
			board[from - 1] = board[from - 4]
			board[from - 4] = EMPTY
	if piece == KING:
		white_king = to
	elif piece == -KING:
		black_king = to
	castling &= _castle_mask[from] & _castle_mask[to]
	ep_square = (from + to) >> 1 if flags & FLAG_DOUBLE else -1
	halfmove = 0 if absi(piece) == PAWN or captured != EMPTY else halfmove + 1
	if turn == BLACK:
		fullmove += 1
	turn = -turn


func unmake_move() -> void:
	var u: Array = _undo.pop_back()
	var m: int = u[0]
	var captured: int = u[1]
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flags := m >> 16
	turn = -turn
	if turn == BLACK:
		fullmove -= 1
	board[from] = PAWN * turn if promo != 0 else board[to]
	if flags & FLAG_EP:
		board[to] = EMPTY
		board[to - 8 * turn] = captured
	else:
		board[to] = captured
	if flags & FLAG_CASTLE:
		if to > from:
			board[from + 3] = board[from + 1]
			board[from + 1] = EMPTY
		else:
			board[from - 4] = board[from - 1]
			board[from - 1] = EMPTY
	castling = u[2]
	ep_square = u[3]
	halfmove = u[4]
	white_king = u[5]
	black_king = u[6]


## Plays a move in the real game (tracks repetition), as opposed to search.
func play(m: int) -> void:
	make_move(m)
	_keys.append(position_key())


func takeback() -> void:
	if _undo.is_empty():
		return
	unmake_move()
	_keys.pop_back()


func move_count() -> int:
	return _undo.size()


func last_move() -> int:
	return -1 if _undo.is_empty() else int(_undo.back()[0])


# --- Status -----------------------------------------------------------------

func get_status() -> Status:
	if not has_legal_move():
		return Status.CHECKMATE if in_check(turn) else Status.STALEMATE
	if halfmove >= 100:
		return Status.DRAW_FIFTY
	if _insufficient_material():
		return Status.DRAW_MATERIAL
	if _keys.count(_keys.back()) >= 3:
		return Status.DRAW_REPETITION
	return Status.ONGOING


func _insufficient_material() -> bool:
	var minors := 0
	for p in board:
		var t := absi(p)
		if t == PAWN or t == ROOK or t == QUEEN:
			return false
		if t == KNIGHT or t == BISHOP:
			minors += 1
			if minors > 1:
				return false
	return true


func material(side: int) -> int:
	const VALUES := [0, 1, 3, 3, 5, 9, 0]
	var total := 0
	for p in board:
		if p != EMPTY and (p > 0) == (side == WHITE):
			total += VALUES[absi(p)]
	return total


# --- Notation ---------------------------------------------------------------

## Standard algebraic notation. Call before playing `m`; `m` must be legal.
func move_to_san(m: int) -> String:
	var from := move_from(m)
	var to := move_to(m)
	var promo := move_promo(m)
	var flags := move_flags(m)
	var piece := board[from]
	var t := absi(piece)
	var capture := board[to] != EMPTY or flags & FLAG_EP
	var san := ""
	if flags & FLAG_CASTLE:
		san = "O-O" if to > from else "O-O-O"
	elif t == PAWN:
		if capture:
			san = FILES[from & 7] + "x"
		san += square_name(to)
		if promo != 0:
			san += "=" + PIECE_LETTERS[promo]
	else:
		san = PIECE_LETTERS[t]
		var ambiguous := false
		var same_file := false
		var same_rank := false
		for o in legal_moves():
			if o != m and move_to(o) == to and board[move_from(o)] == piece:
				ambiguous = true
				if (move_from(o) & 7) == (from & 7):
					same_file = true
				if (move_from(o) >> 3) == (from >> 3):
					same_rank = true
		if ambiguous:
			if not same_file:
				san += FILES[from & 7]
			elif not same_rank:
				san += str((from >> 3) + 1)
			else:
				san += square_name(from)
		if capture:
			san += "x"
		san += square_name(to)
	make_move(m)
	if in_check(turn):
		san += "#" if not has_legal_move() else "+"
	unmake_move()
	return san
