class_name PieceArt
extends RefCounted
## SVG piece artwork. Each piece is an SVG template recolored at runtime and
## rasterized at the exact on-screen size, so it stays crisp at any resolution.

const HEADER := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" viewBox=\"0 0 100 100\">" \
	+ "<ellipse cx=\"50\" cy=\"89\" rx=\"33\" ry=\"5\" fill=\"#000000\" fill-opacity=\"0.28\"/>" \
	+ "<g fill=\"{fill}\" stroke=\"{stroke}\" stroke-width=\"3.5\" stroke-linejoin=\"round\" stroke-linecap=\"round\">"
const BASE := "<rect x=\"20\" y=\"75\" width=\"60\" height=\"12\" rx=\"5\"/>" \
	+ "<path d=\"M28 81 H72\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"2.5\"/>"
const FOOTER := "</g></svg>"

const BODIES := {
	ChessGame.PAWN:
		"<path d=\"M34 75 C35 64 41 56 44 49 H56 C59 56 65 64 66 75 Z\"/>"
		+ "<rect x=\"37\" y=\"43\" width=\"26\" height=\"7\" rx=\"3.5\"/>"
		+ "<circle cx=\"50\" cy=\"30\" r=\"13\"/>"
		+ "<path d=\"M43 26 A8 8 0 0 1 51 21\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3\"/>",
	ChessGame.KNIGHT:
		"<path d=\"M32 75 C30 64 34 56 44 50 C38 49 32 52 27 55 C22 54 19 49 22 44 C28 35 35 27 41 22 L40 10 L49 17 C64 17 75 30 74 48 C73 60 70 68 70 75 Z\"/>"
		+ "<circle cx=\"44\" cy=\"30\" r=\"3\" fill=\"{stroke}\" stroke=\"none\"/>"
		+ "<path d=\"M55 23 C62 29 66 38 66 52\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3\"/>"
		+ "<path d=\"M25 47 L28 46\" fill=\"none\" stroke-width=\"2.5\"/>",
	ChessGame.BISHOP:
		"<path d=\"M34 75 C38 66 42 60 43 52 H57 C58 60 62 66 66 75 Z\"/>"
		+ "<rect x=\"37\" y=\"45\" width=\"26\" height=\"7\" rx=\"3.5\"/>"
		+ "<path d=\"M50 16 C62 24 67 34 62 45 H38 C33 34 38 24 50 16 Z\"/>"
		+ "<circle cx=\"50\" cy=\"11\" r=\"5\"/>"
		+ "<path d=\"M56 25 L46 37\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3.5\"/>",
	ChessGame.ROOK:
		"<path d=\"M31 75 L35 44 H65 L69 75 Z\"/>"
		+ "<path d=\"M29 44 V17 H38 V25 H45.5 V17 H54.5 V25 H62 V17 H71 V44 Z\"/>"
		+ "<path d=\"M41 54 V67\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3\"/>",
	ChessGame.QUEEN:
		"<path d=\"M33 75 C37 66 40 60 41 54 H59 C60 60 63 66 67 75 Z\"/>"
		+ "<path d=\"M31 54 L25 24 L38 38 L43 18 L50 34 L57 18 L62 38 L75 24 L69 54 Z\"/>"
		+ "<circle cx=\"25\" cy=\"21\" r=\"4\"/><circle cx=\"43\" cy=\"14\" r=\"4\"/>"
		+ "<circle cx=\"57\" cy=\"14\" r=\"4\"/><circle cx=\"75\" cy=\"21\" r=\"4\"/>"
		+ "<path d=\"M35 48 H65\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3\"/>",
	ChessGame.KING:
		"<path d=\"M33 75 C37 66 40 60 41 54 H59 C60 60 63 66 67 75 Z\"/>"
		+ "<path d=\"M31 54 C25 42 27 30 38 30 C44 30 48 34 50 39 C52 34 56 30 62 30 C73 30 75 42 69 54 Z\"/>"
		+ "<rect x=\"46.5\" y=\"7\" width=\"7\" height=\"24\" rx=\"1.5\"/>"
		+ "<rect x=\"40\" y=\"13\" width=\"20\" height=\"7\" rx=\"1.5\"/>"
		+ "<path d=\"M35 48 H65\" fill=\"none\" stroke=\"{accent}\" stroke-width=\"3\"/>"
		+ "<circle cx=\"50\" cy=\"47\" r=\"3\" fill=\"{accent}\" stroke=\"none\"/>",
}


static func svg_for(piece_type: int, colors: Dictionary) -> String:
	var svg: String = HEADER + BODIES[piece_type] + BASE + FOOTER
	return svg.format({
		"fill": "#" + (colors.fill as Color).to_html(false),
		"stroke": "#" + (colors.stroke as Color).to_html(false),
		"accent": "#" + (colors.accent as Color).to_html(false),
	})


static func make_texture(piece_type: int, colors: Dictionary, px: int) -> ImageTexture:
	var img := Image.new()
	img.load_svg_from_string(svg_for(piece_type, colors), maxf(px, 8) / 100.0)
	return ImageTexture.create_from_image(img)
