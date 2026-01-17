extends Button

@onready var focus_outline: CanvasItem = $FocusOutline

var base_scale := Vector2.ONE
var bounce_tween: Tween


func _ready():
	base_scale = scale
	pressed.connect(on_pressed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	if focus_outline != null:
		focus_outline.visible = has_focus()


func on_pressed():
	$RandomAudioStreamPlayerComponent.play_random()
	if bounce_tween != null and bounce_tween.is_running():
		bounce_tween.kill()
	scale = base_scale
	bounce_tween = create_tween()
	bounce_tween.tween_property(self, "scale", base_scale * 1.08, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "scale", base_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_focus_entered() -> void:
	if focus_outline != null:
		focus_outline.visible = true


func _on_focus_exited() -> void:
	if bounce_tween != null and bounce_tween.is_running():
		bounce_tween.kill()
	scale = base_scale
	if focus_outline != null:
		focus_outline.visible = false
