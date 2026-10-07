# Changelog

## 1.9.0

### New games
- Added Windows 95-style Solitaire, Hearts, SkiFree and Breakout, plus 3D Battle Chess with chess engine and animations.
- Expanded the game selector to fourteen games in three rows, with high scores for the new games.

### Controls and presentation
- Added shared Windows 95 desktop, cards and game-window rendering for the new games.
- Added game-specific keyboard/controller input, menu handling and return-to-selector behavior.
- Refined the shared auspex frame and existing game views.

## 1.8.0

### Minesweeper
- Added Minesweeper as a ninth program with the Windows 95 rules: Beginner 9x9/10, Intermediate 16x16/40, Expert 30x16/99 and Custom Field (9-24 rows, 9-30 columns, 10 to (h-1)(w-1) mines).
- First click is always safe; a mine under it moves to the first free square from the top-left, as in Windows.
- Left click opens on release, right click cycles flag / ? / blank, and both buttons or the middle button chord a satisfied number. Zero regions flood open.
- Timer starts on the first square, caps at 999 and stops on win or loss. The mine counter can go negative. Loss reveals every mine, marks wrong flags and highlights the fatal square; a win flags all mines.
- Game and Help menus (New, levels, Custom..., Marks (?), Best Times..., Exit, How to Play, About), Custom Field and Fastest Mine Sweepers dialogs, and per-level best times.
- Real mouse pointer plus keyboard/controller play: WASD/arrows/stick move, Space/A open or chord, F/E flag, R new game, 1/2/3 level, 4 marks, Tab menu, Esc closes menus before the game.
- Windows 95 look on a teal desktop with taskbar: bevelled window, gradient title bar, seven-segment LED counters, animated smiley, pixel digits, waving flags, ripple reveals, mine explosions with shockwaves and chain puffs, win confetti and a light CRT pass.

### Game Selector
- Nine cards in a five-over-four layout; the Minesweeper card shows the best time for the current level.

## 1.7.0

### Graphics Overhaul
- Added a shared vector canvas (`MourningstarWaitingGames_canvas.lua`) that draws straight into the view Gui with material-free primitives: clipped triangles, gradients, soft glows, bevelled blocks, particles, shockwaves, screen shake and an auspex CRT pass (scanlines, sweep, vignette, static). No extra packages are loaded.
- **Datafall (Tetris)**: bevelled gem blocks with drop shadows, glowing wireframe ghost, spotlight column, hard-drop streaks and landing dust, laser line clears with sparks, TETRIS flash and shockwaves, glowing previews.
- **Void Invaders**: nebula and gas-giant backdrop, twinkling parallax stars, perspective ground grid, two-frame animated aliens with bloom and blinking eyes, vector player ship with engine flames and muzzle flash, animated plasma bolts, saucer with tractor beam, explosions for aliens, shields, saucer and ship.
- **Snake**: smooth interpolated tube body with shading, scales and swallow bulges, head with eyes and tongue, lit cell grid and data rain, orbiting apple core, eat bursts and a shatter death sequence.
- **Pong**: gradient court with a ball-lit dot matrix, rotating centre rings, bevelled emitter paddles with hit flashes, speed-tinted ribbon trail, bounce sparks and goal explosions.
- **Asteroids**: nebulae and spiral galaxy, faceted and lit 3D rocks with craters, target-lock brackets, shaded vector ship with flame, brake jets and shield bubble, glowing shots, shockwaves and debris.
- **Warhammer 40k Quiz**: cogitator data columns, rotating cogwheel and radar sweep, brass-cornered plates, sliding selection with a travelling edge light, correct/incorrect bursts, per-question progress pips and a final score gauge.
- **Penitent Purge**: 200-column renderer with brick masonry, stained-glass windows, wall torches with flickering light and embers, perspective-correct floor and vault casting, per-column sprite occlusion, redesigned heretics, sigils, shards, relics and power-fist gauntlets.
- **Noosphere Breach**: dynamic floor lighting around the player, bloom on units and projectiles, death shockwaves and a CRT pass.
- **Game Selector**: radar backdrop, drifting motes, animated lock-on brackets, card glow, edge lights and selection bursts.

## 1.6.0

### Space Invaders Mechanics
- Reworked the simulation around fixed 60 Hz ticks and sequential alien marching, including survivor-driven acceleration and the last alien's asymmetric movement.
- Added the original repeating lower-wave starting positions and rescaled movement and projectile speeds to the existing playfield.
- Replaced random enemy fire with three separate shot slots, player-column targeting, deterministic firing sequences, and score-based reload timing.
- Added shot interception, swept projectile collisions, reliable bunker impact damage, and bunker erosion by descending aliens.
- Added deterministic saucer scoring, the original saucer countdown rules, and a shared saucer/squiggly-shot slot.
- Added one bonus life at 1,500 points per game. Kept one player shot at a time and fresh-press firing without autofire.
- Preserved the current graphics and controls; coordinated input and simulation in the same update callback.

### Visual Overhaul
- Refined the auspex presentation across every game with richer palettes, improved HUD panels, stronger contrast, and more detailed procedural effects.
- **Tetris**: Added beveled blocks, improved ghost-piece visibility, and inset HOLD/NEXT/status panels.
- **Space Invaders** and **Asteroids**: Added layered starfields, shaded sprites and objects, brighter projectiles, and richer ship effects.
- **Warhammer 40k Quiz**, **Snake**, and **Pong**: Added structured playfield panels, clearer selection and gameplay feedback, and improved object styling.
- **Penitent Purge**: Added cathedral masonry, arch details, improved depth fog, and more detailed enemy and gauntlet visuals.
- **Noosphere Breach**: Added layered arena construction, recessed panels, circuit-node effects, directional shadows, and refined HUD gauges.
- **Game Selector**: Added unique pixel icons, enhanced game cards, and improved text contrast.

### Visual Fixes
- Corrected Pong paddle rendering to align with collision bounds.
- Kept the full Asteroids rock population visible during dense waves.
- Corrected Space Invaders enemy art to match collision bounds.
- Fixed Penitent Purge HUD and entity depth layering.

## 1.5.0

### Noosphere Breach
- Added a top-down twin-stick combat program with four escalating waves and the multi-phase Cortex boss.
- Added procedural Darktide UI rendering with clear firing lanes, animated enemies, telegraphs, projectiles, particles, shadows, corruption effects, and scanner feedback.
- Added keyboard, mouse, and controller controls for movement, aiming, continuous fire, and dash.
- Added combo scoring, persistent high score, damage and dash feedback, and full disable/view-transition cleanup.

### Game Selector
- Expanded the selector to an eight-program 4x2 layout.
- Removed the abbreviations from the game cards.
- Games can now be played in the Meat Grinder.

## 1.4.2

### Game Selector
- Fixed unreliable WASD and controller navigation in the hub by actively polling menu input.
- Added arrow-key navigation and Enter as permanent fallbacks.
- Added arrow-key movement fallbacks to every minigame.

## 1.4.1

### Game Selector
- Added an auspex launcher for selecting and starting all seven waiting games without opening the mod options.
- The game hotkey returns to the selector from an active game, while Esc closes the current view.
- Existing hotkey bindings, previous game selection, and highscores carry over automatically.

## 1.4.0

### Penitent Purge
- Introducing Penitent Purge: Reliquary Run, a fast first-person 3D score chase through procedurally generated cathedral sectors.
- Collect sigils, build resonance combos, dash through corruption, and reach the vault before the purge timer expires.
- Features endless difficulty scaling, utility pickups, themed sectors, perspective floor and ceiling grids, depth fog, animated portals, particles, speed lines, screen effects, and a dedicated HUD.
- Controls include WASD movement, mouse/controller look, and dash on attack, jump, sprint, or right-click.

### Bugfixes
- **Tetris**: R now activates Hold, and Esc now closes the active waiting game.

### Quiz
- Added 300 new questions.

## 1.3.0

### Improved
- Added a shared auspex frame/backdrop system for all Mourningstar Waiting Games.
- Tightened the black playfield area so it lines up cleanly with the frame.
- Added clearer inner borders for each minigame play area.

### Gameplay
- Pong now continues from level 11 up to level 20 with increasing difficulty.

## 1.2.1

##Bugfixes
- Asteroids would be shown outside the black field. No clips correctly.

## 1.2.0

- Added Asteroids.
- Improved: All games received visual updates.

## 1.1.1

### Bugfixes
- **Tetris**: Soft drop (S key) no longer awards +1 point per row. Score now only comes from line clears and hard drops.
- **Controls text**: Instructions were invisible because widgets didn't exist at `init()` — BaseView creates them asynchronously when the view package loads. Fixed by setting static text directly in the widget definition (`value = mod:localize(...)`) instead of via `content.text` in `init`.
- **Highscore text**: Was updated after `super._draw_widgets()` (one frame late). Moved before the super call so it renders immediately.
- **Localize crash**: `mod:localize("xxx_highscore")` tried to format `"Best: %d"` internally with no argument. Changed to plain `"Best:"` with separate string concatenation.
- **Controls accuracy**: Removed "Space" from Tetris, Invaders, and Quiz controls — those actions bind to the `jump` input (user-dependent key), not the Space key directly.

### New Features
- **High scores**: Personal best is saved per game using `mod:set()` in DMF settings (persists across mod updates). Displayed as `"Best: <score>"` below controls text in each view.
- **Controls overlay**: All 5 games now show their keybindings at the bottom of the game view (green text, font 14).

### Localization
- Added: `tetris_controls`, `invaders_controls`, `quiz_controls`, `snake_controls`, `pong_controls`
- Added: `tetris_highscore`, `invaders_highscore`, `quiz_highscore`, `snake_highscore`, `pong_highscore`

### Files Changed
- `Tetris_game.lua`, `Tetris_view.lua`, `SpaceInvaders_view.lua`, `Quiz_view.lua`, `Snake_view.lua`, `Pong_view.lua`
- `MourningstarWaitingGames.lua`, `MourningstarWaitingGames_localization.lua`
