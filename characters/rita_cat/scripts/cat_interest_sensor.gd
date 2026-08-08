class_name CatInterestSensor
extends Area3D

signal interest_found(node: Node3D)

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("grabbable"):
		interest_found.emit(body)
