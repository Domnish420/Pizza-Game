extends Node
## Static game data, loaded once from res://data/game_data.json.
## Edit that file to rebalance the game: ingredients, dough recipes, pizzas, menus, venues, upgrades, staff roles.

var ING := {}          # ingredient id -> {name, price, store, unit, pack, space, life, kind, col, shape}
var DOUGHS := {}       # dough style id -> baker's percentages, ball weight, shaping method
var DOUGH_PARTS := []  # ["flour","water","salt","yeast","oil","sugar"]
var RECIPES := []      # pizzas
var REC := {}          # pizza id -> pizza
var MENUS := []        # fortnightly menus
var MENU := {}         # menu id -> menu
var MENU_DAYS := 14
var VENUES := []
var UPG := {}          # upgrade track id -> {area, name, tiers:[...]}
var ROLES := {}
var NAMES := []

const STORE_NAME := {"fridge": "Fridge", "freezer": "Freezer", "dry": "Dry store"}

func _init() -> void:
	var f := FileAccess.open("res://data/game_data.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	ING = d.ING; DOUGHS = d.DOUGHS; DOUGH_PARTS = d.DOUGH_PARTS; RECIPES = d.RECIPES
	MENUS = d.MENUS; MENU_DAYS = int(d.MENU_DAYS); VENUES = d.VENUES; UPG = d.UPG; ROLES = d.ROLES; NAMES = d.NAMES
	for r in RECIPES: REC[r.id] = r
	for m in MENUS: MENU[m.id] = m
