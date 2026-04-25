class_name PlayerGrabber3D extends Node3D

class ActiveGrabbable extends RefCounted:
	func _init(_grabbable: Grabbable3D, _slot: Node3D):
		body = _grabbable
		slot = _slot
		
	var body: Grabbable3D
	var slot: Node3D
	
signal pulled_grabbable(body: Grabbable3D)
signal throwed_grabbable(body: Grabbable3D)
signal dropped_grabbable(body: Grabbable3D)

@export var available_slots: Array[Marker3D] = []
@export var mass_lift_force: float = 10.0
@export var physics_pull_force_multiplier: float = 2.0
@export_group("Input Actions")
@export var grab_drop_input_action: StringName = &"interact"
@export var throw_input_action: StringName = &"throw"
@export_group("Interactor")
@export var grabbable_interactor: GrabbableRayCastInteractor3D
@export_range(0.1, 100.0, 0.01) var grabbable_interactor_distance: float = 2.0:
	set(value):
		if grabbable_interactor is GrabbableRayCastInteractor3D and grabbable_interactor_distance != value:
			grabbable_interactor_distance = clamp(value, 0.1, 100.0)
			_prepare_grabbable_interactor(grabbable_interactor_distance)

var active_grabbables: Array[ActiveGrabbable] = []
var holding_object: bool = false

func _input(_event: InputEvent) -> void:
	if InteractionKit3DPluginUtilities.action_just_pressed_and_exists(grab_drop_input_action):
		if holding_object:
			drop_all()
		elif grabbable_interactor and grabbable_interactor.is_colliding():
			var body = grabbable_interactor.get_collider() as Grabbable3D
			if body and not body.state_is_pull() and slots_available():
				pull_body(body)
	
	if InteractionKit3DPluginUtilities.action_just_pressed_and_exists(throw_input_action) and holding_object:
		throw_all()

func _enter_tree() -> void:
	throwed_grabbable.connect(on_throwed_grabbable)
	dropped_grabbable.connect(on_dropped_grabbable)

func _ready() -> void:
	_prepare_available_slots()
	_prepare_grabbable_interactor()
	set_physics_process(false)

func _physics_process(_delta: float):
	for active_grabbable: ActiveGrabbable in active_grabbables:
		pull_force(active_grabbable.body)

func pull_body(body: Grabbable3D, grabber: Node3D = get_random_free_slot()):
	if slots_available():
		if body_can_be_lifted(body):
			body.pull(grabber)
		else:
			body.pull(grabber)
			body.set_physics_process_internal(true)
		active_grabbables.append(ActiveGrabbable.new(body, grabber))
		pulled_grabbable.emit(body)
		holding_object = true
		set_physics_process(true)

func pull_force(body: Grabbable3D):
	if not body_can_be_lifted(body):
		body.update_linear_velocity()
		body.update_angular_velocity()

func throw_all() -> void:
	for active_grabbable: ActiveGrabbable in active_grabbables:
		throw_body(active_grabbable.body)

func throw_body(body: Grabbable3D) -> void:
	active_grabbables = active_grabbables.filter(func(active_grabbable: ActiveGrabbable): return active_grabbable.body != body)
	body.throw()
	throwed_grabbable.emit(body)
	holding_object = active_grabbables.size() > 0
	set_physics_process(holding_object)

func drop_all() -> void:
	for active_grabbable: ActiveGrabbable in active_grabbables:
		drop_body(active_grabbable.body)

func drop_body(body: Grabbable3D) -> void:
	active_grabbables = active_grabbables.filter(func(active_grabbable: ActiveGrabbable): return active_grabbable.body != body)
	body.drop()
	dropped_grabbable.emit(body)
	holding_object = active_grabbables.size() > 0
	set_physics_process(holding_object)

func body_can_be_lifted(body: Grabbable3D) -> bool:
	return body.mass <= mass_lift_force

func slots_available() -> bool:
	return available_slots.size() > 0 and active_grabbables.size() != available_slots.size()

func get_random_free_slot() -> Marker3D:
	if not slots_available():
		return null
	
	var busy_slots := active_grabbables.map(
		func(active_grabbable: ActiveGrabbable): return active_grabbable.slot
	)
	
	return available_slots.filter(func(slot: Marker3D): return not slot in busy_slots).pick_random()

func _prepare_available_slots():
	if available_slots.is_empty():
		for child in get_children():
			if child is Marker3D:
				available_slots.append(child)

func _prepare_grabbable_interactor(distance: float = grabbable_interactor_distance):
	if grabbable_interactor and distance >= 0.1:
		grabbable_interactor.target_position = Vector3.FORWARD * distance

func on_dropped_grabbable(_grabbable: Grabbable3D) -> void:
	pass

func on_throwed_grabbable(_grabbable: Grabbable3D) -> void:
	pass