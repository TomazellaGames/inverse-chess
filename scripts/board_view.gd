class_name BoardView
extends Control
## Draws the board and pieces, and turns clicks/drags into move attempts.

signal move_attempted(from: int, to: int)
signal piece_selected
signal invalid_target

const ANIM_TIME := 0.18

var game: ChessGame
var palette: Palette
var player_side: int = ChessGame.WHITE
var flipped := false
var interactive := true
var input_enabled := false
var show_coordinates := true

var legal_moves := PackedInt32Array()
var selected := -1
var targets := PackedInt32Array()
var last_from := -1
var last_to := -1

var _textures := {}
var _tex_px := 0
var _dragging := false
var _drag_pos := Vector2.ZERO
var _skip_anim := false
var _anim_from := -1
var _anim_to := -1
var _anim_t := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func refresh_textures() -> void:
	_tex_px = 0
	queue_redraw()


func set_legal_moves(moves: PackedInt32Array) -> void:
	legal_moves = moves
	clear_selection()


func clear_selection() -> void:
	selected = -1
	targets = PackedInt32Array()
	_dragging = false
	queue_redraw()


func set_last_move(m: int) -> void:
	last_from = -1 if m < 0 else ChessGame.move_from(m)
	last_to = -1 if m < 0 else ChessGame.move_to(m)
	queue_redraw()


## Call after a move was played on `game`.
func notify_move(m: int) -> void:
	set_last_move(m)
	clear_selection()
	if _skip_anim:
		_skip_anim = false
		_anim_t = 1.0
	else:
		_anim_from = last_from
		_anim_to = last_to
		_anim_t = 0.0


func _process(delta: float) -> void:
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / ANIM_TIME)
		queue_redraw()


# --- Geometry ---------------------------------------------------------------

func board_rect() -> Rect2:
	var side := floorf(minf(size.x, size.y) / 8.0) * 8.0
	return Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))


func square_size() -> float:
	return board_rect().size.x / 8.0


func square_rect(sq: int) -> Rect2:
	var br := board_rect()
	var s := br.size.x / 8.0
	var col := sq & 7
	var row := 7 - (sq >> 3)
	if flipped:
		col = 7 - col
		row = 7 - row
	return Rect2(br.position + Vector2(col * s, row * s), Vector2(s, s))


func square_at(pos: Vector2) -> int:
	var br := board_rect()
	if not br.has_point(pos):
		return -1
	var s := br.size.x / 8.0
	var col := clampi(int((pos.x - br.position.x) / s), 0, 7)
	var row := clampi(int((pos.y - br.position.y) / s), 0, 7)
	if flipped:
		col = 7 - col
		row = 7 - row
	return (7 - row) * 8 + col


# --- Input ------------------------------------------------------------------

func _owns(sq: int) -> bool:
	var p := game.board[sq]
	return p != 0 and signi(p) == player_side


func _select(sq: int) -> void:
	selected = sq
	targets = PackedInt32Array()
	for m in legal_moves:
		if ChessGame.move_from(m) == sq and not targets.has(ChessGame.move_to(m)):
			targets.append(ChessGame.move_to(m))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive or not input_enabled or game == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var sq := square_at(event.position)
		if event.pressed:
			if selected != -1 and targets.has(sq):
				move_attempted.emit(selected, sq)
			elif sq != -1 and _owns(sq):
				if sq != selected:
					piece_selected.emit()
				_select(sq)
				_dragging = true
				_drag_pos = event.position
			else:
				if selected != -1:
					invalid_target.emit()
				clear_selection()
		elif _dragging:
			_dragging = false
			if sq != selected and targets.has(sq):
				_skip_anim = true
				move_attempted.emit(selected, sq)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_pos = event.position
		queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _texture(piece: int) -> ImageTexture:
	var px := int(square_size())
	if px != _tex_px:
		_tex_px = px
		_textures.clear()
	if not _textures.has(piece):
		var colors := palette.piece_colors(signi(piece) == player_side)
		_textures[piece] = PieceArt.make_texture(absi(piece), colors, px)
	return _textures[piece]


func _draw() -> void:
	if game == null or palette == null:
		return
	var br := board_rect()
	if br.size.x < 8:
		return
	var s := br.size.x / 8.0
	var light := palette.board_light()
	var dark := palette.board_dark()
	var accent: Color = palette.piece_colors(true).fill

	draw_rect(br.grow(maxf(3.0, s * 0.06)), palette.piece_colors(true).stroke)
	for sq in 64:
		var is_light := ((sq & 7) + (sq >> 3)) % 2 == 1
		draw_rect(square_rect(sq), light if is_light else dark)

	var hl := Color(accent, 0.38)
	for sq in [last_from, last_to]:
		if sq >= 0:
			draw_rect(square_rect(sq), hl)
	if selected >= 0:
		draw_rect(square_rect(selected), Color(accent, 0.6))

	# A king in check glows: in inverse chess that's usually good news for its owner.
	for side in [ChessGame.WHITE, ChessGame.BLACK]:
		if game.in_check(side):
			var r := square_rect(game.king_of(side))
			var glow := Color(1.0, 0.15, 0.3)
			for i in 4:
				draw_circle(r.get_center(), s * (0.5 - i * 0.08), Color(glow, 0.18 + i * 0.12))

	if show_coordinates:
		_draw_coordinates(light, dark)

	var animating := _anim_t < 1.0
	for sq in 64:
		var p := game.board[sq]
		if p == 0:
			continue
		if animating and sq == _anim_to:
			continue
		if _dragging and sq == selected:
			continue
		draw_texture_rect(_texture(p), square_rect(sq), false)

	var dot := Color(palette.piece_colors(true).stroke, 0.55)
	for t in targets:
		var r := square_rect(t)
		if game.board[t] != 0:
			draw_arc(r.get_center(), s * 0.44, 0, TAU, 32, dot, s * 0.07, true)
		else:
			draw_circle(r.get_center(), s * 0.15, dot)

	if animating and game.board[_anim_to] != 0:
		var a := square_rect(_anim_from).position
		var b := square_rect(_anim_to).position
		var t := ease(_anim_t, -2.0)
		draw_texture_rect(_texture(game.board[_anim_to]), Rect2(a.lerp(b, t), Vector2(s, s)), false)

	if _dragging and selected >= 0 and game.board[selected] != 0:
		var big := s * 1.15
		draw_texture_rect(_texture(game.board[selected]), Rect2(_drag_pos - Vector2(big, big) / 2.0, Vector2(big, big)), false)


func _draw_coordinates(light: Color, dark: Color) -> void:
	var font := get_theme_default_font()
	var s := square_size()
	var fs := int(maxf(9.0, s * 0.18))
	for i in 8:
		# Files along the bottom row, ranks along the left column (from the viewer's side).
		var file_sq := (0 if not flipped else 56) + (i if not flipped else 7 - i)
		var fr := square_rect(file_sq)
		var on_light := ((file_sq & 7) + (file_sq >> 3)) % 2 == 1
		draw_string(font, fr.position + Vector2(fr.size.x - fs * 0.75, fr.size.y - fs * 0.25),
				ChessGame.FILES[file_sq & 7], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dark if on_light else light)
		var rank_sq := (7 - i) * 8 if not flipped else i * 8 + 7
		var rr := square_rect(rank_sq)
		on_light = ((rank_sq & 7) + (rank_sq >> 3)) % 2 == 1
		draw_string(font, rr.position + Vector2(fs * 0.25, fs * 1.0),
				str((rank_sq >> 3) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dark if on_light else light)
