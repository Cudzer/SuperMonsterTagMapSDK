class_name Palette
## The game's colors. UI styling lives in res://assets/theme/game_theme.tres (the project's default
## theme), which uses these same values; use these constants for any color set from code.

## Darkest background. Also the text color on teal, seafoam and sunburst fills.
const ABYSS: Color = Color("#12292a")
## Panels and dialogs.
const DEEP_TEAL: Color = Color("#1e4644")
## Pressed buttons and ground surfaces.
const LAGOON: Color = Color("#2f6b67")
## Primary brand color: buttons, borders, walls.
const TEAL: Color = Color("#62a7a2")
## Hover states and soft highlights.
const SEAFOAM: Color = Color("#9ed3cc")
## Primary text on dark backgrounds, and regular players.
const MINT: Color = Color("#d2efeb")
## Complement of teal: errors, danger, exhaustion, and the tagger.
const CORAL: Color = Color("#f2726b")
## Warm accent: keyboard focus, stamina, things to grab.
const SUNBURST: Color = Color("#ffc857")
## Second warm accent: text selection, special level pieces.
const BERRY: Color = Color("#c2528b")

## Terrain colors for level pieces (the level kit's swatches), beside the UI colors above.
const SAND: Color = Color("#c9a868")
const MOSS: Color = Color("#7cab57")
const LILAC: Color = Color("#6e5596")
const FROST: Color = Color("#cfe9e5")
## Base spots, and the first team's colour by default (Settings.TEAM_PALETTES).
const SKY: Color = Color("#5aa9e6")
## Mud floors (KitPiece.Surface.MUD).
const MUD: Color = Color("#7a5a3e")
## Town colors (Rooftop Town): brick walls, asphalt streets and roofs, and cream trim.
const BRICK: Color = Color("#b9584b")
const ASPHALT: Color = Color("#3d3f52")
const CREAM: Color = Color("#f1dfbc")
