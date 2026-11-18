extends "res://tests/test_day.gd"
## The same day as `test_day.gd`, with a wood oven lit in the morning: the bot feeds the fire when it asks and turns
## the pizzas.

func run() -> void:
	oven_tier = 3
	await super()
	check(D.UPG.oven.tiers[oven_tier].type == "wood", "it was a wood oven", D.UPG.oven.tiers[oven_tier].type)
