extends Control
## King Betrayer: Inverse Chess.
## Normal chess rules, inverted goal: get YOUR OWN king checkmated to win.

const PREVIEW_FEN := "r1bqk2r/ppp2ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 0 1"
const AI_DELAY := 0.45
const RESULT_DELAY := 0.7
const LOGO := preload("res://assets/SplashScreen-512.png")
const SPLASH_BG := Color(0.035, 0.02, 0.06)
const SPLASH_HOLD := 1.8
const MUSIC_URL := "https://pixabay.com/music/beats-lofi-loop-589689/"
const SOURCE_URL := "https://github.com/TomazellaGames/inverse-chess"
const HELP_TEXT := """In King Betrayer the usual goal of chess is turned upside down.

•  WIN by getting your OWN king checkmated.
•  LOSE if you checkmate the rival's king — that hands them the victory.
•  Every normal chess rule still applies: pieces move as usual, you must escape check, and castling, en passant and promotion all work.
•  Stalemate, threefold repetition, the 50-move rule and insufficient material are draws.

Tip: march your king into enemy territory, smother its escape squares with your own pieces, and leave the rival nothing better to do than finish you off."""

var palette := Palette.new()
var game := ChessGame.new()
var ai := SimpleAI.new()
var audio := GameAudio.new()
var player_side: int = ChessGame.WHITE
var game_over := false
var ai_thinking := false

var _token := 0
var _sans: Array[String] = []
var _pending_promos := PackedInt32Array()

var _bg: ColorRect
var _menu: Control
var _title: Label
var _subtitle: Label
var _menu_kings: Array[TextureRect] = []
var _game_screen: Control
var _board: BoardView
var _panel: PanelContainer
var _status: Label
var _side_info: Label
var _moves_scroll: ScrollContainer
var _moves_label: Label
var _custom: Control
var _custom_box: BoxContainer
var _preview: BoardView
var _swatch_player: ColorRect
var _swatch_rival: ColorRect
var _sliders := {}
var _help: Control
var _promo: Control
var _promo_buttons: Array[Button] = []
var _result: Control
var _result_title: Label
var _result_text: Label
var _audio: Control
var _audio_sliders: Array[HSlider] = []
var _credits: Control
var _splash: Control
var _splash_tween: Tween


func _ready() -> void:
	palette.load_saved()
	palette.changed.connect(_on_palette_changed)
	add_child(audio)
	_bg = _full(ColorRect.new()) as ColorRect
	add_child(_bg)
	_build_menu()
	_build_game_screen()
	_build_custom()
	_build_help()
	_build_audio()
	_build_credits()
	_build_promo()
	_build_result()
	_on_palette_changed()
	resized.connect(_layout)
	_layout.call_deferred()
	_show_menu()
	_build_splash()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and is_instance_valid(_splash):
		_end_splash()
		return
	if event.is_action_pressed("ui_cancel"):
		for o in [_help, _custom, _audio, _credits, _result]:
			if o.visible:
				_close_overlay(o)
				return
		if _promo.visible:
			_cancel_promotion()


# --- UI construction --------------------------------------------------------

func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _label(text: String, font_size: int = 0, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(audio.play.bind("click"))
	b.pressed.connect(action)
	return b


func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for b in buttons:
		row.add_child(b)
	return row


## Returns [root, content] for a dimmed, centered modal panel.
func _make_overlay() -> Array:
	var root := _full(Control.new())
	root.visible = false
	add_child(root)
	var dim := _full(ColorRect.new()) as ColorRect
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := _full(CenterContainer.new())
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	return [root, v]


func _build_menu() -> void:
	_menu = _full(Control.new())
	add_child(_menu)
	var center := _full(CenterContainer.new())
	_menu.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(300, 0)
	center.add_child(v)

	var kings := HBoxContainer.new()
	kings.alignment = BoxContainer.ALIGNMENT_CENTER
	kings.add_theme_constant_override("separation", 0)
	for i in 2:
		var king_rect := TextureRect.new()
		king_rect.custom_minimum_size = Vector2(110, 110)
		king_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		king_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		kings.add_child(king_rect)
		_menu_kings.append(king_rect)
	v.add_child(kings)

	_title = _label("King Betrayer", 58, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_title)
	_subtitle = _label("INVERSE CHESS", 26, true)
	v.add_child(_subtitle)
	v.add_child(_label("Checkmate yourself before your rival does.", 18, true))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)
	v.add_child(_button("Play as White", _start_game.bind(ChessGame.WHITE)))
	v.add_child(_button("Play as Black", _start_game.bind(ChessGame.BLACK)))
	v.add_child(_row([_button("Colors", _open_overlay.bind("custom")),
			_button("How to Play", _open_overlay.bind("help"))]))
	v.add_child(_row([_button("Audio", _open_overlay.bind("audio")),
			_button("Credits", _open_overlay.bind("credits"))]))


func _build_game_screen() -> void:
	_game_screen = _full(Control.new())
	add_child(_game_screen)
	_board = BoardView.new()
	_board.game = game
	_board.palette = palette
	_board.move_attempted.connect(_on_move_attempted)
	_board.piece_selected.connect(audio.play.bind("select"))
	_board.invalid_target.connect(audio.play.bind("invalid"))
	_game_screen.add_child(_board)

	_panel = PanelContainer.new()
	_game_screen.add_child(_panel)
	# Autowrapped labels report a huge min height before their first sort, which
	# grows the panel; re-apply the layout once the real minimum is known.
	_panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var header := HBoxContainer.new()
	var title := _label("King Betrayer", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var sound := _button("Audio", _open_overlay.bind("audio"))
	sound.size_flags_horizontal = Control.SIZE_SHRINK_END
	sound.custom_minimum_size = Vector2(0, 36)
	sound.add_theme_font_size_override("font_size", 14)
	header.add_child(sound)
	v.add_child(header)
	_side_info = _label("", 15)
	v.add_child(_side_info)
	_status = _label("", 20)
	_status.custom_minimum_size = Vector2(0, 54)
	v.add_child(_status)

	_moves_scroll = ScrollContainer.new()
	_moves_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_moves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_moves_label = _label("", 16)
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_scroll.add_child(_moves_label)
	v.add_child(_moves_scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_button("Undo", _undo))
	grid.add_child(_button("New Game", func() -> void: _start_game(player_side)))
	grid.add_child(_button("Flip Board", _flip_board))
	grid.add_child(_button("Colors", _open_overlay.bind("custom")))
	grid.add_child(_button("How to Play", _open_overlay.bind("help")))
	grid.add_child(_button("Menu", _show_menu))
	v.add_child(grid)


func _build_custom() -> void:
	var o := _make_overlay()
	_custom = o[0]
	var v: VBoxContainer = o[1]
	v.add_child(_label("Colors", 30, true))
	v.add_child(_label("Pick your color — your rival always gets its complement.", 16, true))

	_custom_box = BoxContainer.new()
	_custom_box.add_theme_constant_override("separation", 20)
	v.add_child(_custom_box)

	var preview_game := ChessGame.new()
	preview_game.load_fen(PREVIEW_FEN)
	_preview = BoardView.new()
	_preview.interactive = false
	_preview.show_coordinates = false
	_preview.game = preview_game
	_preview.palette = palette
	_preview.custom_minimum_size = Vector2(240, 240)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_custom_box.add_child(_preview)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.custom_minimum_size = Vector2(300, 0)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_box.add_child(controls)

	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 10)
	_swatch_player = ColorRect.new()
	_swatch_rival = ColorRect.new()
	for pair in [[_swatch_player, "You"], [_swatch_rival, "Rival"]]:
		var sw: ColorRect = pair[0]
		sw.custom_minimum_size = Vector2(34, 34)
		swatches.add_child(sw)
		var l := _label(pair[1], 17)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		swatches.add_child(l)
	controls.add_child(swatches)

	_add_slider(controls, "Your hue", "piece_hue", 0.0, 1.0, true)
	_add_slider(controls, "Saturation", "piece_sat", 0.2, 1.0)
	_add_slider(controls, "Brightness", "piece_val", 0.45, 1.0)
	_add_slider(controls, "Board hue", "board_hue", 0.0, 1.0, true)
	_add_slider(controls, "Board tint", "board_sat", 0.0, 0.8)

	var presets := GridContainer.new()
	presets.columns = 2
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	for i in Palette.PRESETS.size():
		presets.add_child(_button(Palette.PRESETS[i].name, palette.apply_preset.bind(i)))
	controls.add_child(presets)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_button("Randomize", palette.randomize_colors))
	row.add_child(_button("Done", _close_overlay.bind(_custom)))
	v.add_child(row)


func _add_slider(parent: Control, text: String, key: String, lo: float, hi: float, hue := false) -> void:
	var row := HBoxContainer.new()
	var l := _label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.005
	s.value = palette.get(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(160, 24)
	if hue:
		s.add_theme_stylebox_override("slider", _hue_stylebox())
		s.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
		s.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	var on_change := func(value: float) -> void:
		palette.set(key, value)
		palette.changed.emit()
	s.value_changed.connect(on_change)
	row.add_child(s)
	parent.add_child(row)
	_sliders[key] = s


func _hue_stylebox() -> StyleBoxTexture:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 7:
		offsets.append(i / 6.0)
		colors.append(Color.from_hsv(fposmod(i / 6.0, 1.0), 0.75, 0.95))
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 8
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _build_help() -> void:
	var o := _make_overlay()
	_help = o[0]
	var v: VBoxContainer = o[1]
	v.add_child(_label("How to Play", 30, true))
	var text := _label(HELP_TEXT, 17)
	text.custom_minimum_size = Vector2(420, 0)
	v.add_child(text)
	v.add_child(_button("Got it", _close_overlay.bind(_help)))


func _build_audio() -> void:
	var o := _make_overlay()
	_audio = o[0]
	var v: VBoxContainer = o[1]
	v.custom_minimum_size = Vector2(380, 0)
	v.add_child(_label("Audio", 30, true))
	var names := ["Effects", "Music"]
	var values := [audio.sfx_volume, audio.music_volume]
	for i in 2:
		var row := HBoxContainer.new()
		var l := _label(names[i], 18)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(90, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.max_value = 1.0
		s.step = 0.01
		s.value = values[i]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(200, 28)
		s.value_changed.connect(_on_audio_slider)
		row.add_child(s)
		v.add_child(row)
		_audio_sliders.append(s)
	# Preview the effects volume when the slider is released.
	_audio_sliders[0].drag_ended.connect(func(_changed: bool) -> void: audio.play("move"))
	v.add_child(_button("Done", _close_overlay.bind(_audio)))


func _on_audio_slider(_value: float) -> void:
	audio.set_volumes(_audio_sliders[0].value, _audio_sliders[1].value)


func _build_credits() -> void:
	var o := _make_overlay()
	_credits = o[0]
	var v: VBoxContainer = o[1]
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override("separation", 8)
	var logo := TextureRect.new()
	logo.texture = _logo_texture()
	logo.custom_minimum_size = Vector2(0, 170)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(logo)
	v.add_child(_label("King Betrayer: Inverse Chess", 26, true))
	v.add_child(_label("A game by Tomazella Games,\nmade with the help of Claude Code.", 18, true))
	v.add_child(_label("Music", 15, true))
	v.add_child(_label("\"Lofi Loop\" by zephiramusic, via Pixabay", 17, true))
	v.add_child(_link("pixabay.com/music/beats-lofi-loop-589689", MUSIC_URL))
	v.add_child(_label("The game's source code is open source (MIT license)", 15, true))
	v.add_child(_link("github.com/TomazellaGames/inverse-chess", SOURCE_URL))
	v.add_child(_label("Built with Godot Engine (MIT license)", 15, true))
	v.add_child(_link("godotengine.org/license", "https://godotengine.org/license"))
	v.add_child(_button("Close", _close_overlay.bind(_credits)))


## The logo PNG has a stray semi-transparent line in its leftmost pixel column.
func _logo_texture() -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = LOGO
	t.region = Rect2(1, 0, LOGO.get_width() - 1, LOGO.get_height())
	return t


func _link(text: String, url: String) -> LinkButton:
	var l := LinkButton.new()
	l.text = text
	l.uri = url
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 15)
	return l


## Studio splash shown once at startup. Tap, click or any key skips it.
func _build_splash() -> void:
	_splash = _full(ColorRect.new())
	(_splash as ColorRect).color = SPLASH_BG
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_splash)
	var logo := TextureRect.new()
	logo.texture = _logo_texture()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.15
	logo.anchor_right = 0.85
	logo.anchor_top = 0.15
	logo.anchor_bottom = 0.85
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	_splash.add_child(logo)
	_splash.gui_input.connect(_on_splash_input)
	_splash_tween = create_tween()
	_splash_tween.tween_property(logo, "modulate:a", 1.0, 0.8)
	_splash_tween.tween_interval(SPLASH_HOLD)
	_splash_tween.tween_callback(_end_splash)


func _on_splash_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_end_splash()


func _end_splash() -> void:
	if _splash == null or _splash.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_splash_tween.kill()
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_splash, "modulate:a", 0.0, 0.5)
	t.tween_callback(_splash.queue_free)
	audio.start_music()


func _build_promo() -> void:
	var o := _make_overlay()
	_promo = o[0]
	var v: VBoxContainer = o[1]
	v.add_child(_label("Promote to…", 24, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for t in ChessGame.PROMOTIONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_choose_promotion.bind(t))
		row.add_child(b)
		_promo_buttons.append(b)
	v.add_child(_button("Cancel", _cancel_promotion))


func _build_result() -> void:
	var o := _make_overlay()
	_result = o[0]
	var v: VBoxContainer = o[1]
	v.custom_minimum_size = Vector2(360, 0)
	_result_title = _label("", 34, true)
	v.add_child(_result_title)
	_result_text = _label("", 18, true)
	v.add_child(_result_text)
	v.add_child(_button("Play Again", func() -> void: _start_game(player_side)))
	v.add_child(_button("Review Board", _close_overlay.bind(_result)))
	v.add_child(_button("Menu", _show_menu))


# --- Theme & layout ---------------------------------------------------------

func _stylebox(color: Color, border: Color, border_w := 0, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


func _apply_theme() -> void:
	var mine := palette.piece_colors(true)
	var rival := palette.piece_colors(false)
	var player_fill: Color = mine.fill
	var rival_fill: Color = rival.fill
	var t := Theme.new()
	t.default_font_size = 18
	var text := Color(0.95, 0.94, 0.92)
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", text)
	t.set_color("font_pressed_color", "Button", mine.stroke)
	t.set_color("font_color", "LinkButton", rival_fill.lightened(0.25))
	t.set_color("font_hover_color", "LinkButton", rival_fill.lightened(0.5))
	t.set_color("font_pressed_color", "LinkButton", player_fill)
	t.set_stylebox("normal", "Button", _stylebox(palette.button(0.0), player_fill.darkened(0.3), 2))
	t.set_stylebox("hover", "Button", _stylebox(palette.button(1.0), player_fill, 2))
	t.set_stylebox("pressed", "Button", _stylebox(player_fill, player_fill.lightened(0.3), 2))
	t.set_stylebox("focus", "Button", _stylebox(Color(0, 0, 0, 0), rival_fill, 2))
	t.set_stylebox("panel", "PanelContainer", _stylebox(palette.panel(), rival_fill.darkened(0.2), 2, 14))
	t.set_stylebox("grabber_area", "HSlider", _stylebox(player_fill, player_fill, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _stylebox(player_fill.lightened(0.2), player_fill, 0, 4))
	theme = t
	_bg.color = palette.background()
	_title.add_theme_color_override("font_color", player_fill)
	_subtitle.add_theme_color_override("font_color", rival_fill)


func _layout() -> void:
	var s := size
	var m := maxf(12.0, minf(s.x, s.y) * 0.03)
	var landscape := s.x > s.y * 1.1
	if landscape:
		var pw := clampf(s.x * 0.3, 250.0, 380.0)
		var bs := maxf(64.0, minf(s.y - 2.0 * m, s.x - pw - 3.0 * m))
		var x0 := (s.x - (bs + m + pw)) / 2.0
		var y0 := (s.y - bs) / 2.0
		_board.position = Vector2(x0, y0)
		_board.size = Vector2(bs, bs)
		_panel.position = Vector2(x0 + bs + m, y0)
		_panel.size = Vector2(pw, bs)
	else:
		var bs := maxf(64.0, minf(s.x - 2.0 * m, s.y * 0.6))
		_board.position = Vector2((s.x - bs) / 2.0, m)
		_board.size = Vector2(bs, bs)
		_panel.position = Vector2(m, bs + 2.0 * m)
		_panel.size = Vector2(s.x - 2.0 * m, s.y - bs - 3.0 * m)
	var ps := clampf(minf(s.x, s.y) * 0.4, 150.0, 320.0)
	_preview.custom_minimum_size = Vector2(ps, ps)
	_custom_box.vertical = not landscape


func _on_palette_changed() -> void:
	_board.refresh_textures()
	_preview.refresh_textures()
	_apply_theme()
	_swatch_player.color = palette.piece_colors(true).fill
	_swatch_rival.color = palette.piece_colors(false).fill
	for i in 2:
		_menu_kings[i].texture = PieceArt.make_texture(ChessGame.KING, palette.piece_colors(i == 0), 220)
	for i in _promo_buttons.size():
		_promo_buttons[i].icon = PieceArt.make_texture(ChessGame.PROMOTIONS[i], palette.piece_colors(true), 128)
	for key in _sliders:
		(_sliders[key] as HSlider).set_value_no_signal(palette.get(key))


# --- Screens & overlays -----------------------------------------------------

func _show_menu() -> void:
	_token += 1
	ai_thinking = false
	_hide_overlays()
	_menu.visible = true
	_game_screen.visible = false


func _hide_overlays() -> void:
	for o in [_custom, _help, _audio, _credits, _promo, _result]:
		o.visible = false


func _open_overlay(which: String) -> void:
	audio.play("open")
	var overlays := {"custom": _custom, "help": _help, "audio": _audio, "credits": _credits}
	(overlays[which] as Control).visible = true


func _close_overlay(o: Control) -> void:
	audio.play("close")
	o.visible = false
	if o == _custom:
		palette.save()
	elif o == _audio:
		audio.save_settings()


# --- Game flow --------------------------------------------------------------

func _start_game(side: int) -> void:
	_token += 1
	player_side = side
	game = ChessGame.new()
	_sans.clear()
	game_over = false
	ai_thinking = false
	_board.game = game
	_board.player_side = side
	_board.flipped = side == ChessGame.BLACK
	_board.set_last_move(-1)
	_board.refresh_textures()
	_side_info.text = "You play %s. Goal: get YOUR king checkmated." % ("White" if side == ChessGame.WHITE else "Black")
	_hide_overlays()
	_menu.visible = false
	_layout.call_deferred()
	_game_screen.visible = true
	audio.play("start")
	_after_move()


func _after_move() -> void:
	_update_moves()
	var st := game.get_status()
	if st != ChessGame.Status.ONGOING:
		game_over = true
		_board.input_enabled = false
		_board.set_legal_moves(PackedInt32Array())
		_update_status(st)
		_show_result(st)
	elif game.turn == player_side:
		_board.set_legal_moves(game.legal_moves())
		_board.input_enabled = true
		_update_status(st)
	else:
		_board.input_enabled = false
		_board.set_legal_moves(PackedInt32Array())
		_run_ai()


func _run_ai() -> void:
	ai_thinking = true
	_update_status(ChessGame.Status.ONGOING)
	var token := _token
	await get_tree().create_timer(AI_DELAY).timeout
	if token != _token:
		return
	var m := ai.choose_move(game)
	ai_thinking = false
	if m >= 0:
		_commit(m)


func _commit(m: int) -> void:
	var san := game.move_to_san(m)
	var flags := ChessGame.move_flags(m)
	var captured := game.board[ChessGame.move_to(m)] != 0 or flags & ChessGame.FLAG_EP
	game.play(m)
	_sans.append(san)
	_board.notify_move(m)
	_play_move_sound(m, flags, captured)
	_after_move()


func _play_move_sound(m: int, flags: int, captured: bool) -> void:
	if ChessGame.move_promo(m) != 0:
		audio.play("promote")
	elif flags & ChessGame.FLAG_CASTLE:
		audio.play("castle")
	else:
		audio.play("capture" if captured else "move", 0.06)
	# Mate gets its own result fanfare; check sounds are for ongoing games.
	if game.has_legal_move():
		if game.in_check(player_side):
			audio.play("check_good")
		elif game.in_check(-player_side):
			audio.play("check_bad")


func _on_move_attempted(from: int, to: int) -> void:
	_pending_promos = PackedInt32Array()
	for m in _board.legal_moves:
		if ChessGame.move_from(m) == from and ChessGame.move_to(m) == to:
			_pending_promos.append(m)
	if _pending_promos.size() == 1:
		_commit(_pending_promos[0])
	elif _pending_promos.size() > 1:
		_board.input_enabled = false
		audio.play("open")
		_promo.visible = true


func _choose_promotion(piece_type: int) -> void:
	_promo.visible = false
	for m in _pending_promos:
		if ChessGame.move_promo(m) == piece_type:
			_commit(m)
			return


func _cancel_promotion() -> void:
	_promo.visible = false
	_board.input_enabled = not game_over and game.turn == player_side
	_board.clear_selection()


func _undo() -> void:
	if ai_thinking or _promo.visible:
		return
	var n := 1
	if game.turn == player_side:
		# Take back the rival's reply and your move.
		if game.move_count() < 2:
			return
		n = 2
	for i in n:
		game.takeback()
		_sans.pop_back()
	game_over = false
	_result.visible = false
	_board.set_last_move(game.last_move())
	_after_move()


func _flip_board() -> void:
	_board.flipped = not _board.flipped
	_board.clear_selection()


# --- Text -------------------------------------------------------------------

func _update_status(st: ChessGame.Status) -> void:
	if st != ChessGame.Status.ONGOING:
		_status.text = _result_info(st)[0]
	elif ai_thinking:
		_status.text = "The rival is scheming…"
	elif game.in_check(player_side):
		_status.text = "Your king is in check — so close! Your move."
	else:
		_status.text = "Your move. Lead your king to ruin."


func _update_moves() -> void:
	var lines := PackedStringArray()
	for i in range(0, _sans.size(), 2):
		var line := "%d.  %s" % [(i >> 1) + 1, _sans[i]]
		if i + 1 < _sans.size():
			line += "    " + _sans[i + 1]
		lines.append(line)
	_moves_label.text = "\n".join(lines)
	_scroll_moves.call_deferred()


func _scroll_moves() -> void:
	_moves_scroll.scroll_vertical = int(_moves_scroll.get_v_scroll_bar().max_value)


func _result_info(st: ChessGame.Status) -> Array:
	match st:
		ChessGame.Status.CHECKMATE:
			if game.turn == player_side:
				return ["Betrayal complete!", "Your king walked straight into checkmate. You win!"]
			return ["Defeat", "You checkmated the rival's king — and in King Betrayer that hands them the win."]
		ChessGame.Status.STALEMATE:
			return ["Stalemate", "Nobody can move. It's a draw."]
		ChessGame.Status.DRAW_FIFTY:
			return ["Draw", "Fifty moves without a capture or pawn move."]
		ChessGame.Status.DRAW_MATERIAL:
			return ["Draw", "Not enough material left for anyone to be checkmated."]
		ChessGame.Status.DRAW_REPETITION:
			return ["Draw", "The same position appeared three times."]
	return ["", ""]


func _show_result(st: ChessGame.Status) -> void:
	var token := _token
	await get_tree().create_timer(RESULT_DELAY).timeout
	if token != _token or not game_over:
		return
	var info := _result_info(st)
	_result_title.text = info[0]
	_result_text.text = info[1]
	_result.visible = true
	if st != ChessGame.Status.CHECKMATE:
		audio.play("draw")
	else:
		audio.play("win" if game.turn == player_side else "lose")
