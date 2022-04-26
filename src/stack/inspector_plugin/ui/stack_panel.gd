@tool
extends Control


@onready var _modifiers_container: Control = $VBoxContainer/DragContainer
@onready var _modifiers_popup: PopupPanel = $VBoxContainer/HBoxContainer/Add/ModifiersPopup
@onready var _root: Control = $VBoxContainer/DragContainer

var _scatter
var _modifier_stack
var _modifier_panel = preload("./modifier/modifier_panel.tscn")
var _is_ready := false


func _ready():
	_modifiers_popup.add_modifier.connect(_on_modifier_added)
	_modifiers_container.child_moved.connect(_on_modifier_moved)

	_is_ready = true
	rebuild_ui()


func set_node(node) -> void:
	if not node:
		return

	_scatter = node
	rebuild_ui()


func rebuild_ui() -> void:
	if not _is_ready:
		return

	_validate_stack_connections()
	_clear()
	for m in _modifier_stack.stack:
		var ui = _modifier_panel.instantiate()
		_root.add_child(ui)
		ui.set_root(_scatter)
		ui.create_ui_for(m)
		ui.removed.connect(_on_modifier_removed.bind(m))
		ui.value_changed.connect(_on_value_changed.bind(m))


func _clear() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()


func _validate_stack_connections() -> void:
	if not _scatter:
		return

	if _modifier_stack:
		_modifier_stack.changed.disconnect(_on_stack_changed)

	_modifier_stack = _scatter.modifier_stack
	_modifier_stack.changed.connect(_on_stack_changed)

	if _modifier_stack.just_created:
		_on_load_preset("default")


func _set_children_owner(new_owner: Node, node: Node):
	for child in node.get_children():
		child.set_owner(new_owner)
		if child.get_children().size() > 0:
			_set_children_owner(new_owner, child)


func _get_root_folder() -> String:
	var path: String = get_script().get_path().get_base_dir()
	var folders = path.right(6) # Remove the res://
	var tokens = folders.split('/')
	return "res://" + tokens[0] + "/" + tokens[1]


func _on_modifier_added(modifier) -> void:
	_modifier_stack.add(modifier)


func _on_modifier_moved(old_index: int, new_index: int) -> void:
	_modifier_stack.move(old_index, new_index)


func _on_modifier_removed(m) -> void:
	_modifier_stack.remove(m)


func _on_stack_changed() -> void:
	rebuild_ui()


func _on_value_changed() -> void:
	if _scatter:
		_scatter.update()


func _on_rebuild_pressed() -> void:
	if _scatter:
		_scatter.full_update()


func _on_save_preset(preset_name) -> void:
	if not _scatter:
		return

	var preset = _scatter.duplicate(7)
	preset.clear()
	_set_children_owner(preset, preset)

	var packed_scene = PackedScene.new()
	if packed_scene.pack(preset) != OK:
		print("Failed to save preset")
		return

	var preset_path = _get_root_folder() + "/presets/" + preset_name + ".tscn"
	var _err= ResourceSaver.save(preset_path, packed_scene)


func _on_load_preset(preset_name) -> void:
	var preset_path = _get_root_folder() + "/presets/" + preset_name + ".tscn"
	var preset = load(preset_path).instantiate()
	if not preset:
		return

	_modifier_stack = preset.modifier_stack.duplicate(7)
	_modifier_stack.changed.connect(_on_stack_changed)
	_scatter.modifier_stack = _modifier_stack
	rebuild_ui()
	_scatter.update()
	preset.queue_free()


func _on_delete_preset(preset_name) -> void:
	var dir = Directory.new()
	dir.remove(_get_root_folder() + "/presets/" + preset_name + ".tscn")