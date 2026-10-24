/datum/crafting_recipe/hullfix
	name = "Fix Nanocarbon Hull Panel"
	tool_behaviors = list(TOOL_WELDER)
	result = /obj/structure/hull_plating/nanocarbon
	reqs = list(
		/obj/item/nanocarbon_shard = 5,
	)
	time = 2 SECONDS
	category = CAT_MISC

/datum/crafting_recipe/hullfix/tape
	name = "Tape Nanocarbon Hull Panel"
	tool_behaviors = null
	reqs = list(
		/obj/item/nanocarbon_shard = 5,
		/obj/item/stack/medical/wrap/sticky_tape = 1,
	)
	time = 7 SECONDS
	category = CAT_MISC
