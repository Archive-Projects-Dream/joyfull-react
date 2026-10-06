/// Prevents admins from making the lobby screen transparent for this player
/datum/preference/toggle/disable_lobby_transparency
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "disable_lobby_transparency"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/// [HORIZON-ADD] Language used by the HTML lobby menu
/datum/preference/choiced/lobby_language
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "lobby_language"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/choiced/lobby_language/create_default_value()
	return LOBBY_LANGUAGE_ENGLISH

/datum/preference/choiced/lobby_language/init_possible_values()
	return list(
		LOBBY_LANGUAGE_ENGLISH,
		LOBBY_LANGUAGE_RUSSIAN,
	)

/datum/preference/choiced/lobby_language/compile_constant_data()
	var/list/data = ..()

	var/list/display_names = list()
	display_names[LOBBY_LANGUAGE_ENGLISH] = "English"
	display_names[LOBBY_LANGUAGE_RUSSIAN] = "Русский"
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = display_names

	return data

/// Live-updates the lobby language when the preference is written
/datum/preference/choiced/lobby_language/apply_to_client(client/target, value)
	target?.lobby_menu?.on_language_changed(value)
