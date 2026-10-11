/datum/hud/guardian/get_displacement_groups()
	return list(
		list(HUD_MOB_HEALTH),
		list(HUD_GUARDIAN_COMMUNICATE, HUD_GUARDIAN_MANIFEST,
			HUD_GUARDIAN_RECALL, HUD_GUARDIAN_TOGGLE, HUD_GUARDIAN_LIGHT,
			HUD_MOB_PULL, HUD_MOB_INTENTS, HUD_MOB_FLOOR_CHANGER),
	)

/datum/hud/guardian/initialize_screen_objects()
	. = ..()
	add_screen_object(/atom/movable/screen/pull, HUD_MOB_PULL, HUD_GROUP_STATIC, 'icons/hud/guardian.dmi')
	add_screen_object(/atom/movable/screen/floor_changer, HUD_MOB_FLOOR_CHANGER, HUD_GROUP_STATIC, ui_style, ui_below_throw)
	add_screen_object(/atom/movable/screen/healths/guardian, HUD_MOB_HEALTH, HUD_GROUP_INFO)
	add_screen_object(/atom/movable/screen/combattoggle/flashy, HUD_MOB_INTENTS, HUD_GROUP_STATIC, ui_style, ui_loc = ui_zonesel)

///Dextrous subtype for only dextrous holoparasites. Can hold things hence the inventory slot.
/datum/hud/dextrous/guardian
	default_inventory_slots = list(/datum/inventory_slot/guardian_storage)
	give_health_doll = FALSE

/datum/hud/dextrous/guardian/initialize_screen_objects()
	. = ..()
	add_screen_object(/atom/movable/screen/healths/guardian, HUD_MOB_HEALTH, HUD_GROUP_INFO)

/datum/inventory_slot/guardian_storage
	name = "internal storage"
	icon_state = "suit_storage"
	slot_id = ITEM_SLOT_DEX_STORAGE
	screen_loc = ui_back
