GLOBAL_LIST_EMPTY(lobby_menus)
GLOBAL_VAR(lobby_background_transparent)

/// [HORIZON-ADD] Name of the registered lobby background video asset, empty string when none was found
GLOBAL_VAR(lobby_video_asset_name)

/// [HORIZON-ADD] Name of the registered lobby background image asset, empty string when none was found
GLOBAL_VAR(lobby_background_asset_name)

/// [HORIZON-ADD] Time the client gets to play its fade-out animation before the browser is hidden
#define LOBBY_FADE_OUT_TIME 0.6 SECONDS
/// [HORIZON-ADD] Minimum time between character preview re-renders
#define LOBBY_PREVIEW_REFRESH_COOLDOWN 8 SECONDS
/// [HORIZON-ADD] Directions rendered for the lobby character preview, css-facing name -> dir
#define LOBBY_PREVIEW_DIRS list("south" = SOUTH, "east" = EAST, "north" = NORTH, "west" = WEST)

/client/var/datum/lobby_menu/lobby_menu

/client/proc/initialize_lobby_menu()
	set waitfor = FALSE
	if(!src)
		return
	lobby_menu = new(src)

ADMIN_VERB(toggle_lobby_transparency, R_ADMIN, "Toggle Lobby Transparency", "Toggles the lobby background between opaque and transparent.", ADMIN_CATEGORY_MAIN)
	GLOB.lobby_background_transparent = !GLOB.lobby_background_transparent
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.set_transparency(GLOB.lobby_background_transparent)
	to_chat(user, span_adminnotice("Lobby background [GLOB.lobby_background_transparent ? "transparent" : "opaque"]."))
	log_admin("[key_name(user)] toggled lobby transparency [GLOB.lobby_background_transparent ? "on" : "off"].")

/datum/lobby_menu
	var/client/client
	var/datum/tgui_window/window
	/// Whether we've already registered for asset subsystem init signals
	var/assets_signals_registered = FALSE
	/// [HORIZON-ADD] Whether the lobby browser is currently shown (mirrors update_visibility)
	var/shown = FALSE
	/// [HORIZON-ADD] Sequence counter for preview asset names, so re-renders bust the client cache
	var/preview_sequence = 0
	/// [HORIZON-ADD] Cached preview asset URLs, direction name -> url
	var/list/preview_urls
	/// [HORIZON-ADD] world.time of the last preview render, used for throttling
	var/preview_last_refresh = 0
	/// [HORIZON-ADD] Set when the preview still needs a (re)render; retried from process()
	var/preview_dirty = TRUE
	/// [HORIZON-ADD] Length of prefs.recently_updated_keys the last time we checked
	var/last_prefs_update_count = 0
	/// [HORIZON-ADD] Pending fade-out timer id
	var/fade_timer

/datum/lobby_menu/New(client/client)
	src.client = client
	window = new(client, "lobby_menu")
	window.is_browser = TRUE

	var/transparent = GLOB.lobby_background_transparent && !client.prefs?.read_preference(/datum/preference/toggle/disable_lobby_transparency)
	create_browser(transparent)
	initialize_browser()
	window.subscribe(src, PROC_REF(on_message))

	RegisterSignal(client, COMSIG_QDELETING, PROC_REF(on_client_qdel))
	RegisterSignal(client, COMSIG_CLIENT_MOB_LOGIN, PROC_REF(on_client_mob_login))
	RegisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME, PROC_REF(on_ticker_pregame))
	RegisterSignal(SSticker, COMSIG_TICKER_ENTER_SETTING_UP, PROC_REF(on_ticker_setting_up))
	RegisterSignal(SSticker, COMSIG_TICKER_ERROR_SETTING_UP, PROC_REF(on_ticker_error_setting_up))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(on_round_start))

	GLOB.lobby_menus += src
	update_visibility()
	send_init()

/**
 * Creates the lobby_menu browser element.
 *
 * [HORIZON-ADD] The browser always lives in map_screen, overlaying the map
 * control itself, in both opaque and transparent mode. The map pane is
 * therefore selected for the whole session and its renderer stays warm, so
 * entering the game no longer swaps panes - which used to flash white for a
 * moment while the map control initialized, and briefly showed the vanilla
 * title screen behind the transition.
 *
 * In transparent mode the browser is see-through, so the map (title screen)
 * shows behind the menu. In opaque mode the element is painted black behind
 * the page (which also draws a black backdrop), hiding the map entirely -
 * except during the fade-out, where the element is made transparent so the
 * fading lobby cross-fades into the live game view behind it.
 */
/datum/lobby_menu/proc/create_browser(transparent = FALSE)
	// Remove existing browser element
	winset(client, "lobby_menu", list("parent" = ""))

	if(transparent)
		winset(client, "lobby_menu", list(
			"parent" = SKIN_MAP_SCREEN,
			"type" = "BROWSER",
			"pos" = "0,0",
			"size" = "640x480",
			"anchor1" = "0,0",
			"anchor2" = "100,100",
			"background-color" = "none",
			"inner-background-color" = "transparent",
		))
	else
		winset(client, "lobby_menu", list(
			"parent" = SKIN_MAP_SCREEN,
			"type" = "BROWSER",
			"pos" = "0,0",
			"size" = "640x480",
			"anchor1" = "0,0",
			"anchor2" = "100,100",
			"background-color" = "#000000",
			"inner-background-color" = "#000000",
		))

/datum/lobby_menu/Destroy(force)
	GLOB.lobby_menus -= src
	STOP_PROCESSING(SSlobby_menu, src)
	window?.unsubscribe(src)
	window = null
	client = null
	preview_urls = null
	if(fade_timer)
		deltimer(fade_timer)
		fade_timer = null
	return ..()

/// Loads the bundle, sends assets, and pushes initial state into the browser.
/datum/lobby_menu/proc/initialize_browser()
	window.initialize(
		strict_mode = TRUE,
		inline_css = file("tgui/public/tgui-lobby.bundle.css"),
		inline_js = file("tgui/public/tgui-lobby.bundle.js"),
	)
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/lobby_menu_font))
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/lobby_menu_sounds))
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/fontawesome))

/// Toggle the lobby browser between opaque (black backdrop) and transparent (overlaying map).
/// Recreates the browser element and reinitializes it.
/datum/lobby_menu/proc/set_transparency(transparent)
	if(transparent && client?.prefs?.read_preference(/datum/preference/toggle/disable_lobby_transparency))
		return
	create_browser(transparent)
	initialize_browser()
	update_visibility()
	send_init()
	if(transparent)
		to_chat(client, span_notice("An admin has made the lobby background transparent. You can now see the map behind the lobby menu. You can disable this in your game preferences."))

/datum/lobby_menu/process(seconds_per_tick)
	send_update(list(
		"countdown" = get_countdown_text(),
		"playerCount" = length(GLOB.clients),
		"readyCount" = SSticker.totalPlayersReady,
		"adminReadyCount" = SSticker.total_admins_ready,
		"adminCount" = length(GLOB.admins),
		"shiftTime" = (SSticker.round_start_time == 0) ? "Pre-Game" : round_timestamp(),
	))
	// [HORIZON-ADD] Watch for preference edits so the character preview can refresh
	var/update_count = length(client?.prefs?.recently_updated_keys)
	if(update_count != last_prefs_update_count)
		last_prefs_update_count = update_count
		INVOKE_ASYNC(src, PROC_REF(update_character_preview))
	// [HORIZON-ADD] Keep retrying a pending preview render. Early attempts can
	// be blocked by the refresh cooldown or fail while preferences settle, and
	// nothing else re-triggers the render - without this retry the preview
	// would stay empty until the player manually reloads the interface.
	if(preview_dirty)
		INVOKE_ASYNC(src, PROC_REF(update_character_preview))

/datum/lobby_menu/proc/on_client_qdel()
	SIGNAL_HANDLER
	qdel(src)

/datum/lobby_menu/proc/on_client_mob_login()
	SIGNAL_HANDLER
	update_visibility()

/**
 * Shows or hides the lobby browser depending on whether the client's mob is
 * a new_player. The map pane itself stays selected the entire time - the
 * lobby is simply an overlay on top of it.
 */
/datum/lobby_menu/proc/update_visibility()
	var/should_show = istype(client?.mob, /mob/dead/new_player) && !client.interviewee
	if(should_show)
		shown = TRUE
		// [HORIZON-ADD] cancel a pending hide from a rapid lobby re-entry,
		// otherwise the stale timer could hide the just-restored lobby
		if(fade_timer)
			deltimer(fade_timer)
			fade_timer = null
		// [HORIZON-ADD] re-render the character preview whenever the lobby is (re)shown
		preview_dirty = TRUE
		// The selector stays on the map pane; the browser overlays it. In
		// opaque mode the element is given its solid black background back so
		// nothing of the game bleeds through while the lobby is up.
		winset(client, SKIN_MAP_LOBBY_SELECTOR, "left=[SKIN_MAP_SCREEN]")
		if(!GLOB.lobby_background_transparent)
			winset(client, "lobby_menu", "background-color=#000000")
		winset(client, "lobby_menu", "is-visible=true")
		START_PROCESSING(SSlobby_menu, src)
		send_init()
	else
		var/was_shown = shown
		shown = FALSE
		STOP_PROCESSING(SSlobby_menu, src)
		if(was_shown)
			// [HORIZON-ADD] Let the client play its fade-out animation first.
			// The browser element is made see-through at the same time, so the
			// fading lobby cross-fades into the live game view behind it, and
			// the actual hiding of the browser is deferred until the animation
			// has had time to play. The browser itself persists while hidden,
			// and send_init() on the next show resets the fade client side.
			window?.send_message("fadeOut")
			if(!GLOB.lobby_background_transparent)
				winset(client, "lobby_menu", "background-color=none")
			if(fade_timer)
				deltimer(fade_timer)
			fade_timer = addtimer(CALLBACK(src, PROC_REF(apply_hidden_visibility)), LOBBY_FADE_OUT_TIME, TIMER_STOPPABLE)
		else
			// Already hidden - cancel any stale fade timer and make sure the map pane
			// is the one showing (the skin defaults the selector to lobby_screen)
			if(fade_timer)
				deltimer(fade_timer)
				fade_timer = null
			apply_hidden_visibility()

/// [HORIZON-ADD] Applies the hidden browser state once the fade-out animation has had time to play
/datum/lobby_menu/proc/apply_hidden_visibility()
	fade_timer = null
	if(shown || !client)
		return
	winset(client, "lobby_menu", "is-visible=false")
	if(!GLOB.lobby_background_transparent)
		// Keep the map pane selected and restore the opaque element background
		// so the next show starts from a clean black slate.
		winset(client, SKIN_MAP_LOBBY_SELECTOR, "left=[SKIN_MAP_SCREEN]")
		winset(client, "lobby_menu", "background-color=#000000")

/datum/lobby_menu/proc/on_ticker_pregame()
	SIGNAL_HANDLER
	send_update(list(
		"gamePhase" = "pregame",
		"canObserve" = TRUE,
	))

/datum/lobby_menu/proc/on_ticker_setting_up()
	SIGNAL_HANDLER
	send_update(list(
		"gamePhase" = "setting_up",
		"canReady" = FALSE,
		"canJoin" = TRUE,
	))

/datum/lobby_menu/proc/on_ticker_error_setting_up()
	SIGNAL_HANDLER
	send_update(list(
		"gamePhase" = "pregame",
		"canReady" = TRUE,
		"canJoin" = FALSE,
	))

/datum/lobby_menu/proc/on_round_start()
	SIGNAL_HANDLER
	send_update(list(
		"gamePhase" = "playing",
		"canReady" = FALSE,
		"canJoin" = TRUE,
	))

/datum/lobby_menu/proc/get_game_phase()
	switch(SSticker.current_state)
		if(GAME_STATE_STARTUP)
			return "startup"
		if(GAME_STATE_PREGAME)
			return "pregame"
		if(GAME_STATE_SETTING_UP)
			return "setting_up"
		if(GAME_STATE_PLAYING)
			return "playing"
	return "postgame"

/datum/lobby_menu/proc/get_countdown_text()
	var/time_remaining = SSticker.GetTimeLeft()
	if(time_remaining > 0)
		return "[round(time_remaining / 10)]s"
	if(time_remaining == -10)
		return "DELAYED"
	return "SOON"

/datum/lobby_menu/proc/send_init()
	var/mob/dead/new_player/player = client?.mob
	var/game_phase = get_game_phase()

	window.send_message("init", list(
		"gamePhase" = game_phase,
		"isReady" = istype(player) && player.ready == PLAYER_READY_TO_PLAY,
		"canReady" = game_phase == "pregame" || game_phase == "startup",
		"canJoin" = game_phase == "setting_up" || game_phase == "playing",
		"canObserve" = SSticker.current_state > GAME_STATE_STARTUP,
		"assetsReady" = (SSearly_assets.initialized == INITIALIZATION_INNEW_REGULAR) || (SSatoms.initialized == INITIALIZATION_INNEW_REGULAR),
		"countdown" = get_countdown_text(),
		"playerCount" = length(GLOB.clients),
		"readyCount" = SSticker.totalPlayersReady,
		"adminReadyCount" = SSticker.total_admins_ready,
		"adminCount" = length(GLOB.admins),
		"mapName" = SSmapping.current_map?.map_name || "Loading...",
		"shiftTime" = (SSticker.round_start_time == 0) ? "Pre-Game" : round_timestamp(),
		"isAdmin" = !isnull(client?.holder),
		"isLocalhost" = client?.is_localhost(),
		"hasNewPoll" = FALSE,
		"canPoll" = !is_guest_key(client?.key) && SSdbcore.Connect(),
		"transparent" = GLOB.lobby_background_transparent,
		// [HORIZON-ADD] html-lobby-v2 additions
		"language" = get_language(),
		"characterName" = get_character_name(),
		"preferenceIssues" = get_preference_issues(),
		"serverName" = CONFIG_GET(string/server),
		"videoUrl" = get_lobby_video_url(),
		"backgroundUrl" = get_lobby_background_url(),
		"previewUrls" = preview_urls,
	))

	check_new_polls()

	if(!assets_signals_registered)
		if(SSearly_assets.initialized != INITIALIZATION_INNEW_REGULAR)
			RegisterSignal(SSearly_assets, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(on_assets_ready))
			assets_signals_registered = TRUE

		if(SSatoms.initialized != INITIALIZATION_INNEW_REGULAR)
			RegisterSignal(SSatoms, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(on_assets_ready))
			assets_signals_registered = TRUE

	// [HORIZON-ADD] render the character preview in the background if it needs an update
	if(preview_dirty)
		INVOKE_ASYNC(src, PROC_REF(update_character_preview))

/datum/lobby_menu/proc/on_assets_ready(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_SUBSYSTEM_POST_INITIALIZE)

	if(SSearly_assets.initialized == INITIALIZATION_INNEW_REGULAR || SSatoms.initialized == INITIALIZATION_INNEW_REGULAR)
		send_update(list("assetsReady" = TRUE))

/datum/lobby_menu/proc/check_new_polls()
	set waitfor = FALSE
	if(!client)
		return
	var/mob/dead/new_player/player = client.mob
	if(!istype(player) || is_guest_key(player.key))
		return
	if(!SSdbcore.Connect())
		return
	var/isadmin = !isnull(client.holder)
	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT id FROM [format_table_name("poll_question")]
		WHERE (adminonly = 0 OR :isadmin = 1)
		AND Now() BETWEEN starttime AND endtime
		AND deleted = 0
		AND id NOT IN (
			SELECT pollid FROM [format_table_name("poll_vote")]
			WHERE ckey = :ckey
			AND deleted = 0
		)
		AND id NOT IN (
			SELECT pollid FROM [format_table_name("poll_textreply")]
			WHERE ckey = :ckey
			AND deleted = 0
		)
	"}, list("isadmin" = isadmin, "ckey" = player.ckey))
	if(!query.Execute())
		qdel(query)
		return
	var/has_new = query.NextRow() ? TRUE : FALSE
	qdel(query)
	if(!client)
		return
	send_update(list("hasNewPoll" = has_new))

/datum/lobby_menu/proc/send_update(list/data)
	window.send_message("state", data)

/datum/lobby_menu/proc/on_message(type, payload, href_list)
	if(type == "ready")
		send_init()
		return TRUE

	if(type != "action")
		return FALSE

	var/action = payload["action"]
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		return TRUE
	if(client.interviewee)
		return TRUE

	switch(action)
		if("ready_toggle")
			if(player.ready == PLAYER_NOT_READY)
				player.auto_deadmin_on_ready_or_latejoin()
				player.ready = PLAYER_READY_TO_PLAY
			else
				player.ready = PLAYER_NOT_READY
			send_update(list("isReady" = player.ready == PLAYER_READY_TO_PLAY))
		if("join")
			if(!SSticker?.IsRoundInProgress())
				to_chat(player, span_boldwarning("The round is either not ready, or has already finished..."))
				return TRUE

			var/relevant_cap
			var/hard_popcap = CONFIG_GET(number/hard_popcap)
			var/extreme_popcap = CONFIG_GET(number/extreme_popcap)
			if(hard_popcap && extreme_popcap)
				relevant_cap = min(hard_popcap, extreme_popcap)
			else
				relevant_cap = max(hard_popcap, extreme_popcap)

			if(SSticker.queued_players.len || (relevant_cap && living_player_count() >= relevant_cap && !(ckey(player.key) in GLOB.admin_datums)))
				to_chat(player, span_danger("[CONFIG_GET(string/hard_popcap_message)]"))
				var/queue_position = SSticker.queued_players.Find(player)
				if(queue_position == 1)
					to_chat(player, span_notice("You are next in line to join the game. You will be notified when a slot opens up."))
				else if(queue_position)
					to_chat(player, span_notice("There are [queue_position-1] players in front of you in the queue to join the game."))
				else
					SSticker.queued_players += player
					to_chat(player, span_notice("You have been added to the queue to join the game. Your position in queue is [SSticker.queued_players.len]."))
				return TRUE

			player.auto_deadmin_on_ready_or_latejoin()

			if(payload["ctrlClick"])
				to_chat(player, span_warning("Opening emergency fallback late join menu! If THIS doesn't show, ahelp immediately!"))
				GLOB.latejoin_menu.fallback_ui(player)
			else
				GLOB.latejoin_menu.ui_interact(player)
		if("observe")
			player.make_me_an_observer()
		if("character_setup")
			var/datum/preferences/prefs = client.prefs
			prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
			prefs.update_static_data(player)
			prefs.ui_interact(player)
		if("settings")
			var/datum/preferences/prefs = client.prefs
			prefs.current_window = PREFERENCE_TAB_GAME_PREFERENCES
			prefs.update_static_data(player)
			prefs.ui_interact(player)
		if("changelog")
			client.changelog()
		if("crew_manifest")
			player.ViewManifest()
		if("poll")
			player.handle_player_polling()
		if("start_now")
			if(!client.is_localhost() || !check_rights_for(client, R_SERVER))
				return TRUE
			SSticker.start_immediately = TRUE
			if(SSticker.current_state == GAME_STATE_STARTUP)
				to_chat(player, span_admin("The server is still setting up, but the round will be started as soon as possible."))
		// [HORIZON-ADD] html-lobby-v2 actions
		if("set_language")
			var/language = payload["language"]
			if(!(language in list(LOBBY_LANGUAGE_ENGLISH, LOBBY_LANGUAGE_RUSSIAN)))
				return TRUE
			var/datum/preference/language_preference = GLOB.preference_entries_by_key[/datum/preference/choiced/lobby_language]
			var/datum/preferences/current_prefs = client?.prefs
			if(!language_preference || !current_prefs)
				return TRUE
			// update_preference() is gated by is_accessible(), which depends on the
			// preferences window being open on the game tab, so write the value
			// directly instead - the lobby has to work from any state.
			if(current_prefs.write_preference(language_preference, language))
				current_prefs.save_preferences()
				language_preference.apply_to_client(client, language)
		if("refresh_preview")
			INVOKE_ASYNC(src, PROC_REF(update_character_preview), TRUE)

	return TRUE

/// [HORIZON-ADD] Returns the lobby language preference for this client
/datum/lobby_menu/proc/get_language()
	var/language = client?.prefs?.read_preference(/datum/preference/choiced/lobby_language)
	return language || LOBBY_LANGUAGE_ENGLISH

/// [HORIZON-ADD] Called when the lobby language preference is written; refreshes the lobby text
/datum/lobby_menu/proc/on_language_changed(value)
	if(!client || !window)
		return
	send_init()

/// [HORIZON-ADD] Returns the current character's name for the welcome line
/datum/lobby_menu/proc/get_character_name()
	return client?.prefs?.read_preference(/datum/preference/name/real_name)

/// [HORIZON-ADD] Returns lobby-facing warnings about the player's current preferences
/datum/lobby_menu/proc/get_preference_issues()
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		return list()
	return player.get_preference_issues(get_language())

/**
 * [HORIZON-ADD] Renders the current character into four directional preview
 * images and registers them as assets. Sends the urls to the browser once
 * done. The preview_dirty flag only clears on a successful render, and
 * process() retries while it is set, so a preview that missed its chance
 * (cooldown block, preferences still loading) eventually shows up instead
 * of staying blank until a manual interface reload.
 */
/datum/lobby_menu/proc/update_character_preview(force = FALSE)
	set waitfor = FALSE
	if(!client?.prefs)
		// Preferences are not settled yet (very early login) - process() retries
		preview_dirty = TRUE
		return
	if(!force && world.time < preview_last_refresh + LOBBY_PREVIEW_REFRESH_COOLDOWN)
		preview_dirty = TRUE
		return
	preview_last_refresh = world.time

	var/datum/preferences/prefs = client.prefs
	var/mob/living/carbon/human/dummy/mannequin = new()
	// Dress the mannequin once; silicon jobs return an /image instead
	var/rendered = prefs.render_new_preview_appearance(mannequin, TRUE)
	var/icon_source = istype(rendered, /image) ? rendered : mannequin

	var/list/new_urls = list()
	preview_sequence += 1
	for(var/dir_name in LOBBY_PREVIEW_DIRS)
		var/icon/flat = getFlatIcon(icon_source, LOBBY_PREVIEW_DIRS[dir_name])
		if(!flat)
			continue
		var/asset_name = "lobby_preview_[client.ckey]_[preview_sequence]_[dir_name].png"
		SSassets.transport.register_asset(asset_name, flat)
		SSassets.transport.send_assets(client, asset_name)
		new_urls[dir_name] = SSassets.transport.get_asset_url(asset_name)

	qdel(mannequin)

	preview_urls = length(new_urls) ? new_urls : null
	if(!preview_urls)
		// Nothing rendered this attempt - try again later rather than
		// leaving the preview panel empty forever
		preview_dirty = TRUE
		return
	// Only mark the preview done once we actually have urls to show
	preview_dirty = FALSE
	// The browser persists while the player is in the game, so push this
	// regardless of visibility - the state merges on the client side.
	send_update(list("previewUrls" = preview_urls))

/// [HORIZON-ADD] Returns the url of a lobby background video, if one is configured.
/// Videos are picked up from config/lobby_art/ (.webm or .mp4) and cached per server boot.
/datum/lobby_menu/proc/get_lobby_video_url()
	if(GLOB.lobby_background_transparent)
		return null
	if(isnull(GLOB.lobby_video_asset_name))
		var/list/candidates = list()
		for(var/filename in flist("[global.config.directory]/lobby_art/"))
			var/extension = copytext(filename, findlasttext(filename, "."))
			if(extension in list(".webm", ".mp4"))
				candidates += filename
		if(!length(candidates))
			// Negative cache so we don't rescan on every init
			GLOB.lobby_video_asset_name = ""
			return null
		var/chosen = pick(candidates)
		GLOB.lobby_video_asset_name = "lobby_video_[ckey(chosen)]"
		SSassets.transport.register_asset(GLOB.lobby_video_asset_name, fcopy_rsc("[global.config.directory]/lobby_art/[chosen]"))
	if(!GLOB.lobby_video_asset_name)
		return null
	SSassets.transport.send_assets(client, GLOB.lobby_video_asset_name)
	return SSassets.transport.get_asset_url(GLOB.lobby_video_asset_name)

/// [HORIZON-ADD] Returns the url of a custom lobby background image, if one is configured.
/// Images are picked up from config/lobby_art/ (a map-specific "<map name>.png" wins,
/// then "default.<ext>"). Standard station title screens are deliberately NOT used.
/datum/lobby_menu/proc/get_lobby_background_url()
	if(GLOB.lobby_background_transparent)
		return null
	if(isnull(GLOB.lobby_background_asset_name))
		var/art_dir = "[global.config.directory]/lobby_art/"
		var/map_name = SSmapping.current_map?.map_name
		var/chosen
		if(map_name && fexists("[art_dir][map_name].png"))
			chosen = "[map_name].png"
		else if(map_name && fexists("[art_dir][map_name].jpg"))
			chosen = "[map_name].jpg"
		else
			for(var/filename in flist(art_dir))
				var/lower_name = LOWER_TEXT(filename)
				if(lower_name == "default.png" || lower_name == "default.jpg" || lower_name == "default.jpeg")
					chosen = filename
					break
		if(!chosen)
			// Negative cache so we don't rescan on every init
			GLOB.lobby_background_asset_name = ""
			return null
		GLOB.lobby_background_asset_name = "lobby_background_[ckey(chosen)]"
		SSassets.transport.register_asset(GLOB.lobby_background_asset_name, fcopy_rsc("[art_dir][chosen]"))
	if(!GLOB.lobby_background_asset_name)
		return null
	SSassets.transport.send_assets(client, GLOB.lobby_background_asset_name)
	return SSassets.transport.get_asset_url(GLOB.lobby_background_asset_name)

#undef LOBBY_FADE_OUT_TIME
#undef LOBBY_PREVIEW_REFRESH_COOLDOWN
#undef LOBBY_PREVIEW_DIRS
