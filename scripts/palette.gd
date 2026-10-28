class_name Palette
extends RefCounted
## Player-customizable colors. The player only picks their own hue: the rival's
## pieces always use the complementary hue (+180°), and the board's dark squares
## use the complement of the light squares.

signal changed

const PATH := "user://settings.cfg"

const PRESETS := [
	{"name": "Ember & Tide", "piece_hue": 0.07, "piece_sat": 0.80, "piece_val": 0.95, "board_hue": 0.10, "board_sat": 0.30},
	{"name": "Royal Treason", "piece_hue": 0.78, "piece_sat": 0.60, "piece_val": 0.90, "board_hue": 0.75, "board_sat": 0.25},
	{"name": "Poison Garden", "piece_hue": 0.33, "piece_sat": 0.70, "piece_val": 0.85, "board_hue": 0.92, "board_sat": 0.30},
	{"name": "Candy Coup", "piece_hue": 0.92, "piece_sat": 0.55, "piece_val": 1.00, "board_hue": 0.50, "board_sat": 0.35},
]

var piece_hue := 0.07
var piece_sat := 0.80
var piece_val := 0.95
var board_hue := 0.10
var board_sat := 0.30


static func complement(h: float) -> float:
	return fposmod(h + 0.5, 1.0)


func player_hue() -> float:
	return piece_hue


func rival_hue() -> float:
	return complement(piece_hue)


## {fill, stroke, accent} for the player's pieces (true) or the rival's (false).
func piece_colors(is_player: bool) -> Dictionary:
	var h := player_hue() if is_player else rival_hue()
	return {
		"fill": Color.from_hsv(h, piece_sat, piece_val),
		"stroke": Color.from_hsv(h, minf(1.0, piece_sat * 0.8 + 0.2), 0.16),
		"accent": Color.from_hsv(h, piece_sat * 0.3, 1.0),
	}


func board_light() -> Color:
	return Color.from_hsv(board_hue, board_sat * 0.45, 0.90)


func board_dark() -> Color:
	return Color.from_hsv(complement(board_hue), board_sat, 0.50)


func background() -> Color:
	return Color.from_hsv(board_hue, board_sat * 0.5, 0.11)


func panel() -> Color:
	return Color.from_hsv(board_hue, board_sat * 0.5, 0.17)


func button(level: float) -> Color:
	return Color.from_hsv(board_hue, board_sat * 0.6, 0.24 + level * 0.1)


func apply_preset(i: int) -> void:
	var p: Dictionary = PRESETS[i]
	piece_hue = p.piece_hue
	piece_sat = p.piece_sat
	piece_val = p.piece_val
	board_hue = p.board_hue
	board_sat = p.board_sat
	changed.emit()


func randomize_colors() -> void:
	piece_hue = randf()
	piece_sat = randf_range(0.45, 0.9)
	piece_val = randf_range(0.8, 1.0)
	board_hue = randf()
	board_sat = randf_range(0.15, 0.45)
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # Keep other sections (e.g. audio) intact.
	for key in ["piece_hue", "piece_sat", "piece_val", "board_hue", "board_sat"]:
		cfg.set_value("colors", key, get(key))
	cfg.save(PATH)


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in ["piece_hue", "piece_sat", "piece_val", "board_hue", "board_sat"]:
		set(key, float(cfg.get_value("colors", key, get(key))))
