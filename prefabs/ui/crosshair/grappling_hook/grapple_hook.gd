@tool
extends Control

@export var outer_element_distance: float = 20.0 :
	set(value):
		outer_element_distance = value
		right_outer.position.x = value / 2
		left_outer.position.x = (-left_outer.size.x - value / 2)
@export var inner_element_distance: float = 2.0 :
	set(value):
		inner_element_distance = value
		right_inner.position.x = value / 2
		left_inner.position.x = (-left_inner.size.x - value / 2)

@onready var outer_element: Control = %OuterElement
@onready var left_outer: TextureRect = %LeftOuter
@onready var right_outer: TextureRect = %RightOuter

@onready var inner_element: Control = %InnerElement
@onready var left_inner: TextureRect = %LeftInner
@onready var right_inner: TextureRect = %RightInner

func set_outer_element_visibility(element_visibiity: bool) -> void:
	outer_element.visible = element_visibiity

func set_inner_element_visibility(element_visibiity: bool) -> void:
	inner_element.visible = element_visibiity
