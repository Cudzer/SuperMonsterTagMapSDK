# Super Monster Tag Map SDK 1.0.0

Make your own maps for Super Monster Tag: build them in Godot with the game's own kit pieces, toys
and models (and your own models), playtest them in the game, and export them as map packages.

The full guide is on the SDK's wiki: https://github.com/Cudzer/SuperMonsterTagMapSDK/wiki

## What you need

- **Godot 4.5.1** (the standard build, not .NET), from https://godotengine.org/download/archive/4.5.1-stable/
- **Super Monster Tag**, to playtest your maps. This SDK is for game version 1.0.0.

## Getting started

1. Open `project.godot` in Godot 4.5.1. The first import takes a minute.
2. The **Level Tools** dock sits below the Inspector. On its **Map** tab, press **New Map...** and
   name your map. It's created in `maps/<id>/` with a starter island.
3. Build it:
   - **Kit:** boxes, ramps, stairs, islands, buildings and more, sized in the Inspector.
   - **Models:** the game's level models, and your own.
   - **Gameplay:** spring pads, swing bars, ziplines, rails, teleporters, fans, hiding spots, and the
     spots for coins, the button and bases.

   Arm an item and click to place it. R turns it, Q and E raise and lower it.
4. Press **Validate Map** to check for problems, frame a nice view and press **Thumbnail**, and fill
   in the map's name, description and author in `maps/<id>/<id>.tres`.
5. Press **Playtest** to play it in the game with bots. The first time, choose the game's
   `SuperMonsterTag.exe` (in Steam: right-click the game, Manage, Browse local files). In the
   playtest, **F5** reloads the map, so you can export again and see your change straight away.
6. **Export Package** writes the map package to `exports/<id>/`.

The `maps/` folder has an example to learn from: **Twin Peaks** (`maps/twin_peaks/`), a small map
using the common toys, and the finished version of the wiki's "Your First Map" tutorial.

## Publishing to the Steam Workshop

Publish from the game, not from here:

1. In Super Monster Tag's main menu, open **My Maps** and press **Add Folder...**. Pick this SDK's
   `exports` folder (once: every map you export there is listed from then on).
2. Press **Publish** on your map, check its title, description and who can see it, and press
   **Publish**. The thumbnail is its Workshop picture.
3. The first time, open its page and accept the Steam Workshop agreement, or nobody else can see it.

To update it, export again and press **Update** in My Maps. The map keeps its page, ratings and
subscribers. **Play** in My Maps starts a match on it with bots, like Playtest here.

Players who subscribe find it in the Start Match panel's Community section. Anyone joining a lobby
playing it downloads it first, so they don't need to subscribe.

## Your own models

Put `.glb` files in a folder of your own under `assets/models/level/`, such as
`assets/models/level/my_map/`. They appear on the Models tab under that folder's name, and are
copied into your map's package when you export. Model them with the origin at the centre of the
base. Textures can be `.png`, `.jpg` or `.webp`.

## The rules

A map package is data, never code, so a map from anyone is safe to play:

- No scripts or scenes of your own in a map. Use the kit pieces, toys, models and Godot's own
  nodes (meshes, CSG, lights, decals, particles, labels).
- Don't change the files in `addons/`, `assets/` (apart from your own models), `scenes/`,
  `scripts/` or `sdk/`. They're the game's, the game uses its own copies, and SDK updates replace
  them.

The export lists anything it had to leave out, and why.

## Updating

Download the new SDK, then copy your `maps/<id>/` folders and your model folders into it. Point
My Maps at the new SDK's `exports` folder.
