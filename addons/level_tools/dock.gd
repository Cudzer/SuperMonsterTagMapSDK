@tool
extends VBoxContainer
## The Level Tools dock: item buttons to arm for placing (Kit, Models and Gameplay tabs), a
## color and grid choice, and the Map tab: validation results, new maps, thumbnails, and exporting
## and playtesting map packages. The plugin does the placing, checking and exporting; this only
## holds choices and shows results.

## Emitted when an item is armed, or with an empty dictionary when disarmed.
signal armed_changed(item: Dictionary)

const Catalog := preload("catalog.gd")
const MapFiles := preload("map_files.gd")
const ModelThumbnails := preload("model_thumbnails.gd")
const PackageTools := preload("package_tools.gd")
const GRID_SIZES: Array[float] = [0.0, 0.5, 1.0, 2.0, 4.0]
const GRID_DEFAULT: int = 2
const HEIGHT_STEPS: Array[float] = [0.25, 0.5, 1.0, 2.0]
const HEIGHT_STEP_DEFAULT: int = 1

var plugin: EditorPlugin

var _item_buttons: Array[Button] = []
var _group: ButtonGroup
## The Models tab, its buttons, and the model paths they were built from (to skip rebuilding when
## nothing changed).
var _models_box: VBoxContainer
var _model_buttons: Array[Button] = []
var _model_paths: PackedStringArray = PackedStringArray()
var _thumbnails: ModelThumbnails
## The swatch new pieces get, or -1 for each piece's own preset color.
var _color: int = -1
var _status: Label
var _map_message: Label
var _grid: OptionButton
var _height_step: OptionButton
var _hint: Label
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _tabs: TabContainer
var _map_tab: int = 0
var _summary: Label
var _issue_list: ItemList
## The nodes the listed issues point at, by list index.
var _issue_nodes: Array = []
var _playtest_mode: OptionButton
var _playtest_bots: SpinBox
## The installed game's path (Map SDK only).
var _game_path: LineEdit
var _game_dialog: EditorFileDialog


func _init() -> void:
	name = "Level Tools"
	custom_minimum_size = Vector2(220, 0)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var group: ButtonGroup = ButtonGroup.new()
	group.allow_unpress = true
	_group = group

	# Short tab titles, so all four fit a narrow dock.
	var pieces: VBoxContainer = _tab(tabs, "Kit")
	pieces.add_child(_item_grid(Catalog.PIECES, group))
	pieces.add_child(_heading("Color"))
	pieces.add_child(_swatches())

	_thumbnails = ModelThumbnails.new()
	add_child(_thumbnails)
	_models_box = _tab(tabs, "Models")
	refresh_models()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(refresh_models)

	var gameplay: VBoxContainer = _tab(tabs, "Gameplay")
	gameplay.add_child(_item_grid(Catalog.GAMEPLAY, group))
	var aim_hint: Label = _heading("Aim a spring pad: select it and drag the handle at the end of its arc onto the landing spot.")
	aim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aim_hint.modulate.a = 0.6
	gameplay.add_child(aim_hint)

	# Validation and map files share a tab, so the tabs fit a narrow dock.
	_tabs = tabs
	var map: VBoxContainer = _tab(tabs, "Map")
	_map_tab = map.get_parent().get_index()
	var run: Button = Button.new()
	run.text = "Validate Map"
	run.tooltip_text = "Check spots, bases, pads, bars and slopes. Also runs whenever the map is saved."
	run.pressed.connect(func() -> void: plugin.call(&"validate_map"))
	map.add_child(run)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map.add_child(_summary)
	_issue_list = ItemList.new()
	_issue_list.custom_minimum_size = Vector2(0, 240)
	_issue_list.max_text_lines = 4
	_issue_list.auto_height = true
	_issue_list.item_selected.connect(_on_issue_selected)
	map.add_child(_issue_list)
	map.add_child(HSeparator.new())
	var files_row: HBoxContainer = HBoxContainer.new()
	var new_map: Button = Button.new()
	new_map.text = "New Map..."
	new_map.tooltip_text = "Create a map folder under res://maps with a starter island, and open it."
	new_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_map.pressed.connect(_ask_map_name)
	files_row.add_child(new_map)
	var capture: Button = Button.new()
	capture.text = "Thumbnail"
	capture.tooltip_text = "Save the current 3D view as this map's picker thumbnail (16:9)."
	capture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capture.pressed.connect(_capture_thumbnail)
	files_row.add_child(capture)
	map.add_child(files_row)
	_build_package_section(map)
	_map_message = Label.new()
	_map_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map.add_child(_map_message)

	add_child(HSeparator.new())
	var grid_row: HBoxContainer = HBoxContainer.new()
	var grid_label: Label = Label.new()
	grid_label.text = "Grid"
	grid_row.add_child(grid_label)
	_grid = OptionButton.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.tooltip_text = "Placed items snap to this grid horizontally."
	for size: float in GRID_SIZES:
		_grid.add_item("Off" if size == 0.0 else "%s m" % size)
	_grid.select(GRID_DEFAULT)
	grid_row.add_child(_grid)
	add_child(grid_row)

	var height_row: HBoxContainer = HBoxContainer.new()
	var height_label: Label = Label.new()
	height_label.text = "Height"
	height_row.add_child(height_label)
	_height_step = OptionButton.new()
	_height_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_height_step.tooltip_text = "How far Q/E (while placing), Page Up/Down and the Up/Down buttons move things."
	for step: float in HEIGHT_STEPS:
		_height_step.add_item("%s m steps" % step)
	_height_step.select(HEIGHT_STEP_DEFAULT)
	height_row.add_child(_height_step)
	add_child(height_row)
	var move_row: HBoxContainer = HBoxContainer.new()
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	move_row.add_child(_height_button("Up", editor_theme.get_icon(&"MoveUp", &"EditorIcons"),
			"Raise the selection one step (Page Up).", func() -> void: plugin.call(&"nudge_selection", 1)))
	move_row.add_child(_height_button("Down", editor_theme.get_icon(&"MoveDown", &"EditorIcons"),
			"Lower the selection one step (Page Down).", func() -> void: plugin.call(&"nudge_selection", -1)))
	move_row.add_child(_height_button("Drop", null,
			"Drop the selection onto the surface below it (End).", func() -> void: plugin.call(&"drop_selection")))
	add_child(move_row)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate.a = 0.6
	add_child(_hint)
	show_hint(false, 0.0)

	_name_dialog = ConfirmationDialog.new()
	_name_dialog.title = "New Map"
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Map name, e.g. Sky Fort"
	_name_edit.text_submitted.connect(func(_text: String) -> void: _create_map())
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(_create_map)
	add_child(_name_dialog)
	set_scene_root(null)


## Horizontal grid snap in meters, 0 for none.
func grid_size() -> float:
	return GRID_SIZES[_grid.selected]


## Meters a height nudge moves (Q/E while placing, Page Up/Down, the Up/Down buttons).
func height_step() -> float:
	return HEIGHT_STEPS[_height_step.selected]


## The key hints under the dock: placing keys while an item is armed (with its height offset),
## selection keys otherwise.
func show_hint(placing: bool, height_offset: float) -> void:
	if placing:
		var height: String = "" if is_zero_approx(height_offset) else " (%+.2f m)" % height_offset
		_hint.text = "Click: place   R: turn 45°   Q/E: lower/raise%s   Esc: stop" % height
	else:
		_hint.text = "Selection: Page Up/Down raise/lower   End: drop to ground"


func _height_button(text: String, icon: Texture2D, tooltip: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.icon = icon
	button.tooltip_text = tooltip
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_pressed)
	return button


## The swatch to paint new pieces with, or -1 to keep each piece's preset.
func piece_color() -> int:
	return _color


func disarm() -> void:
	for button: Button in _item_buttons:
		button.set_pressed_no_signal(false)
	armed_changed.emit({})


func set_scene_root(root: Node) -> void:
	show_issues([])
	_summary.text = "Press Validate Map to check this map."
	if root == null or not root is Node3D:
		_status.text = "Open a 3D scene to place pieces."
	elif root.get_script() == MapFiles.GAME_MAP_SCRIPT:
		_status.text = "Map: %s" % root.name
	else:
		_status.text = "%s isn't a map (GameMap). Pieces work; gameplay spots only count in maps." % root.name


func show_map_message(text: String) -> void:
	_map_message.text = text


## Lists validator issues ({"severity", "message", "node"}, see validator.gd) with the count of
## errors and warnings in the tab title.
func show_issues(issues: Array[Dictionary]) -> void:
	_issue_list.clear()
	_issue_nodes.clear()
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	var icons: Array[Texture2D] = [
		editor_theme.get_icon(&"StatusError", &"EditorIcons"),
		editor_theme.get_icon(&"StatusWarning", &"EditorIcons"),
		editor_theme.get_icon(&"NodeInfo", &"EditorIcons"),
	]
	var counts: Array[int] = [0, 0, 0]
	for issue: Dictionary in issues:
		var severity: int = issue["severity"]
		counts[severity] += 1
		_issue_list.add_item(issue["message"], icons[severity])
		_issue_nodes.append(issue["node"])
	if counts[0] + counts[1] == 0:
		_summary.text = "No problems found."
		_tabs.set_tab_title(_map_tab, "Map")
	else:
		_summary.text = "%d errors, %d warnings. Click one to select its node." % [counts[0], counts[1]]
		_tabs.set_tab_title(_map_tab, "Map (%d)" % (counts[0] + counts[1]))


func _on_issue_selected(index: int) -> void:
	var node: Node = _issue_nodes[index]
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	EditorInterface.edit_node(node)


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


func _item_grid(items: Array[Dictionary], group: ButtonGroup) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	for item: Dictionary in items:
		var button: Button = Button.new()
		button.text = item["name"]
		button.tooltip_text = item.get("tip", "")
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				armed_changed.emit(item)
			elif group.get_pressed_button() == null:
				armed_changed.emit({}))
		grid.add_child(button)
		_item_buttons.append(button)
	return grid


## Lists the models in LevelModel.MODELS_DIR, a heading per subfolder, with editor thumbnails.
## Runs whenever the project's files change, so new models appear by themselves.
func refresh_models() -> void:
	var items: Dictionary[String, Array] = Catalog.model_items()
	var paths: PackedStringArray = PackedStringArray()
	for category: String in items:
		for item: Dictionary in items[category]:
			paths.append(item["model"])
	if paths == _model_paths and _models_box.get_child_count() > 0:
		return
	_model_paths = paths
	var armed: String = ""
	for button: Button in _model_buttons:
		if button.button_pressed:
			armed = button.get_meta(&"model")
		_item_buttons.erase(button)
	_model_buttons.clear()
	for child: Node in _models_box.get_children():
		_models_box.remove_child(child)
		child.queue_free()
	if items.is_empty():
		var empty: Label = _heading("Put .glb models in %s/ and they appear here. Subfolders become categories." % LevelModel.MODELS_DIR)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.modulate.a = 0.6
		_models_box.add_child(empty)
		return
	for category: String in items:
		_models_box.add_child(_heading(category.capitalize() if category != "" else "Models"))
		var category_items: Array[Dictionary] = []
		category_items.assign(items[category])
		var grid: GridContainer = _item_grid(category_items, _group)
		_models_box.add_child(grid)
		for index: int in grid.get_child_count():
			var button: Button = grid.get_child(index)
			var path: String = items[category][index]["model"]
			button.set_meta(&"model", path)
			button.custom_minimum_size = Vector2(0, 92)
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.expand_icon = true
			button.clip_text = true
			_model_buttons.append(button)
			_thumbnails.request(path, func(thumbnail: Texture2D) -> void:
				if is_instance_valid(button):
					button.icon = thumbnail)
			if path == armed:
				button.set_pressed_no_signal(true)


func _swatches() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	var group: ButtonGroup = ButtonGroup.new()
	var preset: Button = Button.new()
	preset.text = "Preset"
	preset.tooltip_text = "Each piece's own color: berry paths, teal walls, and so on."
	preset.toggle_mode = true
	preset.button_group = group
	preset.button_pressed = true
	preset.pressed.connect(func() -> void: _color = -1)
	flow.add_child(preset)
	for swatch: int in KitPiece.SWATCH_COLORS.size():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(26, 26)
		button.tooltip_text = String(KitPiece.Swatch.keys()[swatch]).capitalize()
		button.toggle_mode = true
		button.button_group = group
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = KitPiece.SWATCH_COLORS[swatch]
			style.set_corner_radius_all(4)
			if state.contains("pressed"):
				style.set_border_width_all(3)
				style.border_color = Color.WHITE
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(func() -> void: _color = swatch)
		flow.add_child(button)
	return flow


func _ask_map_name() -> void:
	_name_edit.text = ""
	_name_dialog.popup_centered(Vector2i(360, 0))
	_name_edit.grab_focus()


func _create_map() -> void:
	var display_name: String = _name_edit.text.strip_edges()
	_name_dialog.hide()
	var error: String = MapFiles.create_map(display_name)
	if error != "":
		show_map_message(error)
		return
	var path: String = MapFiles.scene_path_for(MapFiles.id_for(display_name))
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)
	show_map_message("Created %s. Shape it, then frame a view and press Thumbnail." % path)


## Export Package and Playtest, the playtest's mode and bots, and (in the Map SDK) the game to run.
func _build_package_section(map: VBoxContainer) -> void:
	map.add_child(HSeparator.new())
	var row: HBoxContainer = HBoxContainer.new()
	var export_button: Button = Button.new()
	export_button.text = "Export Package"
	export_button.tooltip_text = "Write this map as a map package (data, plus your own models and images) into res://exports/<id>/."
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(func() -> void: plugin.call(&"export_package"))
	row.add_child(export_button)
	var playtest_button: Button = Button.new()
	playtest_button.text = "Playtest"
	playtest_button.tooltip_text = "Export, then play it in the game with bots. In the game, F5 reloads the map after you export again."
	playtest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playtest_button.pressed.connect(func() -> void: plugin.call(&"playtest_package", _playtest_mode.get_selected_id(), int(_playtest_bots.value)))
	row.add_child(playtest_button)
	map.add_child(row)

	var options: HBoxContainer = HBoxContainer.new()
	_playtest_mode = OptionButton.new()
	_playtest_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playtest_mode.tooltip_text = "The mode to playtest in."
	for id: int in GameModes.NAMES.size():
		_playtest_mode.add_item(GameModes.NAMES[id], id)
	_playtest_mode.select(clampi(int(PackageTools.get_choice("playtest_mode", 0)), 0, GameModes.NAMES.size() - 1))
	_playtest_mode.item_selected.connect(func(index: int) -> void: PackageTools.set_choice("playtest_mode", index))
	options.add_child(_playtest_mode)
	var bots_label: Label = Label.new()
	bots_label.text = "Bots"
	options.add_child(bots_label)
	_playtest_bots = SpinBox.new()
	_playtest_bots.min_value = 0
	_playtest_bots.max_value = 15
	_playtest_bots.value = int(PackageTools.get_choice("playtest_bots", 3))
	_playtest_bots.value_changed.connect(func(value: float) -> void: PackageTools.set_choice("playtest_bots", int(value)))
	options.add_child(_playtest_bots)
	map.add_child(options)

	# The game's own project playtests itself; the SDK needs the installed game.
	if not MapFormat.is_sdk():
		return
	var game_row: HBoxContainer = HBoxContainer.new()
	var game_label: Label = Label.new()
	game_label.text = "Game"
	game_row.add_child(game_label)
	_game_path = LineEdit.new()
	_game_path.editable = false
	_game_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_path.placeholder_text = "SuperMonsterTag.exe"
	_game_path.text = PackageTools.game_path()
	_game_path.tooltip_text = _game_path.text
	game_row.add_child(_game_path)
	var browse: Button = Button.new()
	browse.text = "..."
	browse.tooltip_text = "Choose the game's SuperMonsterTag.exe. In Steam: right-click the game, Manage, Browse local files."
	browse.pressed.connect(_choose_game)
	game_row.add_child(browse)
	map.add_child(game_row)
	_game_dialog = EditorFileDialog.new()
	_game_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_game_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_game_dialog.title = "Choose SuperMonsterTag.exe"
	_game_dialog.add_filter("*.exe", "Super Monster Tag")
	_game_dialog.file_selected.connect(func(path: String) -> void:
		PackageTools.set_game_path(path)
		_game_path.text = path
		_game_path.tooltip_text = path)
	add_child(_game_dialog)


func _choose_game() -> void:
	if _game_path.text != "":
		_game_dialog.current_dir = _game_path.text.get_base_dir()
	_game_dialog.popup_file_dialog()


## The plugin reports back through show_map_message().
func _capture_thumbnail() -> void:
	show_map_message("Capturing...")
	plugin.call(&"capture_thumbnail")
