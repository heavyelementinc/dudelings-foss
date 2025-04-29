class_name VolleyNet
extends StaticBody2D
# The volley ball net used in the volley game field.
#
# @author ethan_hewlett
# @copyright 2024 Heavy Element

func _ready() -> void:
	var _a = $Area2DLeft.connect("body_entered", self, "_on_Area2DLeft_body_entered")
	var _b = $Area2DLeft.connect("body_exited", self, "_on_Area2DLeft_body_exited")
	var _c = $Area2DRight.connect("body_entered", self, "_on_Area2DRight_body_entered")
	var _d = $Area2DRight.connect("body_exited", self, "_on_Area2DRight_body_exited")


func _on_Area2DLeft_body_entered(body: Node) -> void:
	if !body is GameBall:
		return

	$Sprite.set_frame(1)


func _on_Area2DLeft_body_exited(body: Node) -> void:
	if !body is GameBall:
		return

	$Sprite.set_frame(0)


func _on_Area2DRight_body_entered(body: Node) -> void:
	if !body is GameBall:
		return

	$Sprite.set_frame(2)


func _on_Area2DRight_body_exited(body: Node) -> void:
	if !body is GameBall:
		return

	$Sprite.set_frame(0)
