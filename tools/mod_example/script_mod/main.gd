extends Node
# Example script mod for NOT MY PARCEL!
# The game calls _mod_ready once at start. "api" is the Mods object, "dir" is this mod's folder.

var api


func _mod_ready(mods_api, dir: String) -> void:
	api = mods_api
	api.connect("customer_spawned", self, "_on_customer")
	api.connect("parcel_delivered", self, "_on_delivered")
	api.connect("shift_started", self, "_on_shift")
	# a new line for orcs, in any language (exactly one %s = parcel code)
	api.add_line("orc", "ORC VERY BIG NOW. GIVE %s.")
	print("[tips mod] loaded from ", dir)


func _on_shift(main) -> void:
	api.flash("Tips mod: every parcel brings +1 coin!", 3.0)


func _on_customer(main, customer) -> void:
	if customer.kind == "orc":
		customer.scale = Vector3.ONE * 1.6


func _on_delivered(main, parcel, customer) -> void:
	api.add_money(1)
