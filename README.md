# King Betrayer: Inverse Chess

Chess with the goal turned upside down: **win by getting your own king checkmated**.
Checkmate the rival's king and *they* win.

### ▶ [Play it in your browser on itch.io](https://tomazellagames.itch.io/king-betrayer-inverse-chess)

Works on desktop and mobile browsers, with no download or install needed.

A game by **Tomazella Games**, made with the help of Claude Code, built with [Godot Engine](https://godotengine.org) 4.7.

---

## How to play

Every normal chess rule still applies. Only the goal is inverted:

| Outcome | What happens |
| --- | --- |
| 🏆 **You win** | Your own king is checkmated. |
| 💀 **You lose** | You checkmate the rival's king, which hands *them* the victory. |
| 🤝 **Draw** | Stalemate, threefold repetition, the 50-move rule, or not enough material left for anyone to be mated. |

The rival plays by the same inverted rules: it is also trying to get its own king checkmated.

**Controls**
- **Click or tap** a piece, then click or tap a highlighted square, **or drag and drop** the piece.
  Dots mark legal moves; rings mark captures.
- **Undo** takes back your last move and the rival's reply.
- **Flip Board** turns the board around. **New Game** restarts with the same color.
- When a pawn promotes, you choose the piece. Under-promoting to a knight or bishop can be a real tactic here.
- **Esc** closes menus.

**Strategy tips**
- March your king toward the enemy army. A king in the corner, boxed in by its own pieces, is easy to mate.
- Block your king's escape squares with your own pieces.
- Leave the rival with nothing better to do than finish you off.
- Watch out for checks you give the rival's king: a careless checkmate loses the game.
- A glowing red king is in check, which in this game is usually good news for its owner.

## Features

- **Complete chess rules:** castling, en passant, promotion with piece choice, check, checkmate, stalemate,
  threefold repetition, the 50-move rule and insufficient material.
- **Single player vs. a simple AI.** It looks two moves ahead, refuses to mate you if it can
  avoid it, and walks its own king into danger.
- **Play as White or Black.**
- **Original SVG art.** The pieces are SVG drawings, recolored and rasterized at the exact
  on-screen size, so they stay sharp on any screen.
- **Color customization with complementary colors.** You pick your color (hue, saturation,
  brightness), and the rival always gets the complementary hue. The board's dark squares
  likewise use the complement of the light squares. Includes four presets and a Randomize button.
- **Audio.** All sound effects are synthesized in code at startup, so the game ships no
  sound-effect files. Background music plays on a loop. Effects and music have separate volume sliders.
- **Responsive layout.** Works in landscape and portrait, with mouse and touch.
- **Settings are remembered** between sessions: colors and volumes are saved in the browser.

## Running from source

1. Install [Godot 4.7](https://godotengine.org/download) (standard version; .NET is not needed).
2. Clone the repository:
   ```sh
   git clone https://github.com/TomazellaGames/inverse-chess.git
   ```
3. Open Godot, choose **Import**, and select `project.godot` in the cloned folder.
4. Press **F5** (or the ▶ button) to run.

The project uses the **GL Compatibility** renderer, the one required for web builds.

## Exporting for the web

1. In the editor, install the export templates: **Editor → Manage Export Templates → Download and Install**.
2. **Project → Export…**, select the **Web** preset and click **Export Project**.
   This writes `build/web/index.html` and its files. The `build/` folder is git-ignored.
3. To test locally, serve the folder over HTTP. Opening `index.html` directly from disk won't work:
   ```sh
   cd build/web
   python -m http.server 8000
   ```
   Then open <http://localhost:8000>.

Thread support is disabled in the Web preset, so the build needs no special server headers
(COOP/COEP). It runs on itch.io, Game Jolt and plain static hosting.

**Publishing on itch.io:** zip the *contents* of `build/web/` (with `index.html` at the
root of the zip), upload it, set the kind of project to **HTML**, and tick
**"This file will be played in the browser"**. A viewport of 1280×720 with the
**Fullscreen button** enabled and **Mobile friendly** checked works well.

## Project structure

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn` | Entry scene; the whole UI is built in code by `main.gd` |
| `scripts/main.gd` | Splash, menus, overlays, theme, layout and game flow |
| `scripts/chess_game.gd` | Rules engine: move generation, make/unmake, game status, algebraic notation |
| `scripts/simple_ai.gd` | Two-ply inverse-chess AI |
| `scripts/board_view.gd` | Board drawing, click/drag input, move animation |
| `scripts/piece_art.gd` | SVG piece templates, rasterized at runtime |
| `scripts/palette.gd` | Complementary color scheme, presets, saved settings |
| `scripts/game_audio.gd` | Music playback, synthesized sound effects, volume buses |
| `assets/` | Studio logo (splash and credits) and background music |
| `tests/` | Automated checks (excluded from exports) |

## Tests

The tests run from the command line with the Godot executable:

```sh
# Rules engine: standard perft move-count positions + checkmate detection
godot --headless --path . -s res://tests/test_rules.gd

# Plays full games through the real UI and saves screenshots (needs a window)
godot --path . -s res://tests/smoke.gd -- <screenshot_dir>

# Renders every synthesized sound effect to .wav files for listening
godot --headless --path . -s res://tests/dump_sfx.gd -- <output_dir>
```

## Credits

- **Game:** Tomazella Games, made with the help of Claude Code.
- **Music:** "Lofi Loop" by zephiramusic, via
  [Pixabay](https://pixabay.com/music/beats-lofi-loop-589689/) (Pixabay Content License).
- **Engine:** [Godot Engine](https://godotengine.org/license) (MIT license).

## License

The source code is open source under the [MIT License](LICENSE). © 2026 Tomazella Games.

The MIT License covers the code. The music is distributed under the
[Pixabay Content License](https://pixabay.com/service/license-summary/), and the
Tomazella Games logo is the studio's brand. Neither is covered by the MIT License.
