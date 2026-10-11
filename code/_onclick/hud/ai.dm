/datum/hud/ai
	ui_style = 'icons/hud/screen_ai.dmi'

/datum/hud/ai/get_displacement_groups()
	return list(
		list(HUD_AI_SENSORS, HUD_AI_CAMERA_LIGHT, HUD_AI_CAMERA_TRACK,
			HUD_AI_CAMERA_LIST, HUD_AI_IMAGE_VIEW, HUD_AI_CREW_MONITOR,
			HUD_AI_CREW_MANIFEST, HUD_SILICON_ALERTS, HUD_AI_AICORE,
			HUD_AI_CALL_SHUTTLE, HUD_AI_ANNOUNCEMENT, HUD_AI_STATE_LAWS,
			HUD_SILICON_TABLET, HUD_AI_MULTICAM, HUD_AI_ADD_MULTICAM,
			HUD_AI_TAKE_IMAGE, HUD_MOB_LANGUAGE_MENU, HUD_MOB_MEMORIES),
		list(HUD_AI_FLOOR_INDICATOR, HUD_AI_GO_UP, HUD_AI_GO_DOWN),
	)

/datum/hud/ai/initialize_screen_objects()
	. = ..()
	add_screen_object(/atom/movable/screen/language_menu, HUD_MOB_LANGUAGE_MENU, HUD_GROUP_STATIC, ui_style, ui_ai_language_menu)
	add_screen_object(/atom/movable/screen/memories, HUD_MOB_MEMORIES, HUD_GROUP_STATIC, ui_style, ui_ai_memories_menu)
	add_screen_object(/atom/movable/screen/ai/floor_indicator, HUD_AI_FLOOR_INDICATOR)
	add_screen_object(/atom/movable/screen/ai/go_up, HUD_AI_GO_UP)
	add_screen_object(/atom/movable/screen/ai/go_up/down, HUD_AI_GO_DOWN)
	add_screen_object(/atom/movable/screen/ai/aicore, HUD_AI_AICORE)
	add_screen_object(/atom/movable/screen/ai/camera_list, HUD_AI_CAMERA_LIST)
	add_screen_object(/atom/movable/screen/ai/camera_track, HUD_AI_CAMERA_TRACK)
	add_screen_object(/atom/movable/screen/ai/camera_light, HUD_AI_CAMERA_LIGHT)
	add_screen_object(/atom/movable/screen/ai/crew_monitor, HUD_AI_CREW_MONITOR)
	add_screen_object(/atom/movable/screen/ai/crew_manifest, HUD_AI_CREW_MANIFEST)
	add_screen_object(/atom/movable/screen/ai/alerts, HUD_SILICON_ALERTS)
	add_screen_object(/atom/movable/screen/ai/announcement, HUD_AI_ANNOUNCEMENT)
	add_screen_object(/atom/movable/screen/ai/call_shuttle, HUD_AI_CALL_SHUTTLE)
	add_screen_object(/atom/movable/screen/ai/state_laws, HUD_AI_STATE_LAWS)
	add_screen_object(/atom/movable/screen/ai/image_take, HUD_AI_TAKE_IMAGE)
	add_screen_object(/atom/movable/screen/ai/image_view, HUD_AI_IMAGE_VIEW)
	add_screen_object(/atom/movable/screen/ai/sensors, HUD_AI_SENSORS)
	add_screen_object(/atom/movable/screen/ai/multicam, HUD_AI_MULTICAM)
	add_screen_object(/atom/movable/screen/ai/add_multicam, HUD_AI_ADD_MULTICAM)
	add_screen_object(/atom/movable/screen/ai/modpc, HUD_SILICON_TABLET)
