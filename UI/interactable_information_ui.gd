extends CanvasLayer

@onready var interactable_information: RichTextLabel = %InteractableInformation
@onready var dot_cursor: Control = $Control/CenterContainer/DotCursor

var _current_interactable: Interactable3D

func _ready() -> void:
	interactable_information.text = ""
	
	GlobalInteractionEvents.interactable_focused.connect(on_interactable_focused)
	GlobalInteractionEvents.interactable_unfocused.connect(on_interactable_unfocused)
	GlobalInteractionEvents.interactable_interacted.connect(on_interactable_interacted)

func on_interactable_focused(interactable: Interactable3D) -> void:
	_current_interactable = interactable
	dot_cursor.focused = true
	
	if interactable.title != "":
		interactable_information.text = "[i]%s[/i]" % interactable.title
	else:
		interactable_information.text = "[i][E] Interact[/i]" % interactable.title

func on_interactable_unfocused(_interactable: Interactable3D) -> void:
	_current_interactable = null
	dot_cursor.focused = false
	interactable_information.clear()

func on_interactable_interacted(_interactable: Interactable3D) -> void:
	_current_interactable = null
	dot_cursor.focused = false
	
	if _interactable.number_of_times_can_be_interacted > 0:
		var remaining = _interactable.number_of_times_can_be_interacted - _interactable.times_interacted
		if remaining > 0:
			interactable_information.text = "[i]%s (%d remaining)[/i]" % [_interactable.title, remaining]
		else:
			interactable_information.text = "[i]%s (depleted)[/i]" % _interactable.title
			interactable_information.add_theme_color_override("default_color", Color.RED)
	else:
		interactable_information.clear()
