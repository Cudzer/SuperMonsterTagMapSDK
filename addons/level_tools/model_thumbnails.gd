@tool
extends SubViewport
## Renders the Models tab's thumbnails: each model in its own little world, framed from a
## three-quarter view with its own light, one at a time. The editor's resource previewer doesn't
## make previews of imported scenes, so this does. Thumbnails are cached by path and file time, so
## a re-exported model gets a new one.

const THUMBNAIL_SIZE: int = 128
## Camera direction from the model, and its field of view.
const VIEW_DIRECTION: Vector3 = Vector3(1.0, 0.8, 1.2)
const FOV_DEGREES: float = 30.0

var _cache: Dictionary[String, Texture2D] = {}
## Waiting requests: [path, callback taking the Texture2D].
var _queue: Array[Array] = []
var _busy: bool = false
var _stage: Node3D
var _camera: Camera3D


func _init() -> void:
	size = Vector2i(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Palette.MINT
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	add_child(light)
	_camera = Camera3D.new()
	_camera.fov = FOV_DEGREES
	add_child(_camera)
	_stage = Node3D.new()
	add_child(_stage)


## Calls [param on_ready] with the thumbnail of the model at [param path], now if it's cached.
func request(path: String, on_ready: Callable) -> void:
	var key: String = _key(path)
	if _cache.has(key):
		on_ready.call(_cache[key])
		return
	_queue.append([path, on_ready])
	if not _busy:
		_render_queue()


func _render_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var request_entry: Array = _queue.pop_front()
		var path: String = request_entry[0]
		var key: String = _key(path)
		if not _cache.has(key):
			var texture: Texture2D = await _render(path)
			if texture != null:
				_cache[key] = texture
		if _cache.has(key):
			(request_entry[1] as Callable).call(_cache[key])
	_busy = false


func _render(path: String) -> Texture2D:
	var scene: PackedScene = load(path) as PackedScene
	var model: Node3D = scene.instantiate() as Node3D if scene != null else null
	if model == null:
		return null
	_stage.add_child(model)
	var bounds: AABB = _bounds(model, Transform3D.IDENTITY)
	var radius: float = maxf(bounds.size.length() * 0.5, 0.1)
	var distance: float = radius / sin(deg_to_rad(FOV_DEGREES) * 0.5)
	var center: Vector3 = bounds.get_center()
	_camera.look_at_from_position(center + VIEW_DIRECTION.normalized() * distance, center)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_texture().get_image()
	_stage.remove_child(model)
	model.queue_free()
	return ImageTexture.create_from_image(image) if image != null else null


func _bounds(node: Node, at: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	var instance: VisualInstance3D = node as VisualInstance3D
	if instance != null:
		bounds = at * instance.get_aabb()
	for child: Node in node.get_children(true):
		var child_3d: Node3D = child as Node3D
		if child_3d == null:
			continue
		var child_bounds: AABB = _bounds(child_3d, at * child_3d.transform)
		if child_bounds.has_volume():
			bounds = child_bounds if not bounds.has_volume() else bounds.merge(child_bounds)
	return bounds


static func _key(path: String) -> String:
	return "%s@%d" % [path, FileAccess.get_modified_time(path)]
