--- FUN: const
-- Specify all fun constant

---@class fun.const
local M = {}

--- Available OS values
--- @enum fun.const.OS
M.OS = {
	ANDROID = "Android",
	IOS = "iPhone OS",
	MAC = "Darwin",
	LINUX = "Linux",
	WINDOWS = "Windows",
	BROWSER = "HTML5",
}

--- Available target configs, see modules/target.lua
--- @enum fun.const.TARGETS
M.TARGETS = {
	DEVELOPMENT = "development",
	GOOGLEPLAY = "googleplay",
	APPSTORE = "appstore",
	YANDEXGAMES = "yandexgames",
	RUSTORE = "rustore",
}


--- Fun gui layers
--- @enum fun.const.GUI_LAYERS
M.GUI_LAYERS = {
	GENERAL_BOT = "general_bot",
	TEXT_BOT = "text_bot",
	GENERAL = "general",
	TEXT = "text",
	GENERAL_TOP = "general_top",
	TEXT_TOP = "text_top",
}


--- This is all keys from all.input_binding
M.INPUT_KEYS = {
	hash("key_space"),
	hash("key_exclamationmark"),
	hash("key_doublequote"),
	hash("key_hash"),
	hash("key_dollarsign"),
	hash("key_ampersand"),
	hash("key_singlequote"),
	hash("key_lparen"),
	hash("key_rparen"),
	hash("key_asterisk"),
	hash("key_plus"),
	hash("key_comma"),
	hash("key_minus"),
	hash("key_period"),
	hash("key_slash"),
	hash("key_0"),
	hash("key_1"),
	hash("key_2"),
	hash("key_3"),
	hash("key_4"),
	hash("key_5"),
	hash("key_6"),
	hash("key_7"),
	hash("key_8"),
	hash("key_9"),
	hash("key_colon"),
	hash("key_semicolon"),
	hash("key_lessthan"),
	hash("key_equals"),
	hash("key_greaterthan"),
	hash("key_questionmark"),
	hash("key_at"),
	hash("key_a"),
	hash("key_b"),
	hash("key_c"),
	hash("key_d"),
	hash("key_e"),
	hash("key_f"),
	hash("key_g"),
	hash("key_h"),
	hash("key_i"),
	hash("key_j"),
	hash("key_k"),
	hash("key_l"),
	hash("key_m"),
	hash("key_n"),
	hash("key_o"),
	hash("key_p"),
	hash("key_q"),
	hash("key_r"),
	hash("key_s"),
	hash("key_t"),
	hash("key_u"),
	hash("key_v"),
	hash("key_w"),
	hash("key_x"),
	hash("key_y"),
	hash("key_z"),
	hash("key_lbracket"),
	hash("key_rbracket"),
	hash("key_backslash"),
	hash("key_caret"),
	hash("key_underscore"),
	hash("key_grave"),
	hash("key_lbrace"),
	hash("key_rbrace"),
	hash("key_pipe"),
	hash("key_esc"),
	hash("key_f1"),
	hash("key_f2"),
	hash("key_f3"),
	hash("key_f4"),
	hash("key_f5"),
	hash("key_f6"),
	hash("key_f7"),
	hash("key_f8"),
	hash("key_f9"),
	hash("key_f10"),
	hash("key_f11"),
	hash("key_f12"),
	hash("key_up"),
	hash("key_down"),
	hash("key_left"),
	hash("key_right"),
	hash("key_lshift"),
	hash("key_rshift"),
	hash("key_lctrl"),
	hash("key_rctrl"),
	hash("key_lalt"),
	hash("key_ralt"),
	hash("key_tab"),
	hash("key_enter"),
	hash("key_backspace"),
	hash("key_insert"),
	hash("key_del"),
	hash("key_pageup"),
	hash("key_pagedown"),
	hash("key_home"),
	hash("key_end"),
	hash("key_numpad_0"),
	hash("key_numpad_1"),
	hash("key_numpad_2"),
	hash("key_numpad_3"),
	hash("key_numpad_4"),
	hash("key_numpad_5"),
	hash("key_numpad_6"),
	hash("key_numpad_7"),
	hash("key_numpad_8"),
	hash("key_numpad_9"),
	hash("key_numpad_divide"),
	hash("key_numpad_multiply"),
	hash("key_numpad_subtract"),
	hash("key_numpad_add"),
	hash("key_numpad_decimal"),
	hash("key_numpad_equal"),
	hash("key_numpad_enter"),
	hash("key_numpad_numlock"),
	hash("key_capslock"),
	hash("key_scrolllock"),
	hash("key_pause"),
	hash("key_lsuper"),
	hash("key_rsuper"),
	hash("key_menu"),
	hash("key_back"),

	-- from mouse some triggers
	hash("mouse_wheel_down"),
	hash("mouse_wheel_up"),
}




--- Доступные места для показа banner рекламы
--- @enum fun.const.ADS_BANNER_POSITION
M.ADS_BANNER_POSITION = {
	TOP = "top",
	BOTTOM = "bottom",
}

--- Все доступные когорты
---@enum fun.const.COHORTS
M.COHORTS = {
	DEFAULT = "default",
	NEW = "new",
	REACTIVATED = "reactivated",
	RESURRECTED = "resurrected",
	FADING = "fading",
	ACTIVE = "active",
	WATCHER = "watcher",
	PAYER = "payer",
	VIP = "vip",
}

--- Fun input events
M.INPUT = {
	MULTITOUCH = hash("touch_multi"),
	TOUCH = hash("touch"),
	CLOSE = hash("close"),
	CALLBACK = hash("callback"),
	SCROLL_UP = hash("mouse_wheel_up"),
	SCROLL_DOWN = hash("mouse_wheel_down"),
	KEY_Q = hash("key_q"),
	KEY_R = hash("key_r"),
	KEY_N = hash("key_n"),
	KEY_D = hash("key_d"),
	KEY_P = hash("key_p"),
	KEY_O = hash("key_o"),
	KEY_1 = hash("key_1"),
	KEY_2 = hash("key_2"),
	KEY_3 = hash("key_3"),
	KEY_L = hash("key_l"),
	KEY_LALT = hash("key_lalt"),
	KEY_LCTRL = hash("key_lctrl"),
}


--- Fun built-in input type
M.INPUT_TYPE = {
	KEY_PRESSED = hash("key_pressed"),
	KEY_REPEATED = hash("key_repeated"),
	KEY_HOLD = hash("key_hold"),
	KEY_RELEASED = hash("key_released"),
	TOUCH_START = hash("touch_start"),
	TOUCH = hash("touch"),
	TOUCH_END = hash("touch_end"),
	LONG_TOUCH = hash("long_touch"),
	DRAG_START = hash("drag_start"), -- it mean touch_cancel too
	DRAG = hash("drag"),
	DRAG_END = hash("drag_end"),
	PINCH_START = hash("pinch_start"),
	PINCH = hash("pinch"),
	PINCH_END = hash("pinch_end"),
}


--- Fun built-in game
--- @enum EVENT
M.EVENTS = {
	GAME_START = "fun.game.start",
	GAME_FOCUS = "fun.game.focus",
	LANG_UPDATE = "fun.lang.update",
	NEW_DAY = "fun.game.new_day",
	WINDOW_EVENT = "fun.window.event",

	LEVEL_START = "fun.level.start",
	LEVEL_WIN = "fun.level.win",
	LEVEL_FAIL = "fun.level.fail",
	LEVEL_RESTART = "fun.level.restart",

	SEGMENTATION_COHORT_CHANGED = "fun.segmentation.cohort_changed",
}






return M
