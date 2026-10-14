--- Fun lang module
-- API to work with game localization


local events = require("event.events")
local log = require("fun.libs.log")

local luax = require("fun.luax")
local tablex = require("fun.libs.tablex")
local const = require("fun.const")

local utils = require("fun.libs.utils")
local saver = require("fun.modules.saver")
local device = require("fun.modules.device")
local gamedata = require("fun.modules.gamedata")

local logger = log.get_logger("fun.lang")

---@class fun.lang.config
---@field lang_paths table<string, string>
---@field default string

---@class fun.lang
local M = {

	---@type fun.lang.config
	default_config = {
		lang_paths = {
			["en"] = "lang/en.json"
		},
		default = "en"
	},

	---@type fun.lang.config|nil
	config = nil,

	state = {
		lang = nil,
		--- true, если игрок сам выбрал язык в настройках - тогда язык платформы его не перебивает
		is_user_selected = false
	},

	runtime = {
		lang_dict = {}
	},
}


--- Загружает языковой файл для заданного языка из файла
---@param lang string двухбуквенный код языка
---@return table|nil @Словарь с переводами для заданного языка, nil если файл не найден или не удалось загрузить
local function load_lang(lang)
	if not M.config then
		logger:error("\"lang\" module is not initialized")
		return nil
	end

	local filename = M.config.lang_paths[lang]
	if not filename then
		logger:error("Language path is not defined for language: " .. lang)
		return nil
	end

	return utils.load_json(filename) or nil
end


local function get_time_data(seconds)
	local minutes = math.max(0, math.floor(seconds / 60))
	seconds = math.max(0, math.floor(seconds % 60))
	local hours = math.max(0, math.floor(minutes / 60))
	minutes = math.max(0, math.floor(minutes % 60))
	local days = math.max(0, math.floor(hours / 24))
	hours = math.max(0, math.floor(hours % 24))

	return days, hours, minutes, seconds
end


--- Return localized time format from seconds
function M.time_format(seconds)
	local days, hours, minutes, secs = get_time_data(seconds)
	if days > 0 then
		return M.txp("time_format_d", days, hours, minutes, secs)
	elseif hours > 0 then
		return M.txp("time_format_h", hours, minutes, secs)
	else
		return M.txp("time_format_m", minutes, secs)
	end
end


--- Применить язык: загрузить словарь и оповестить подписчиков
--- @param lang string language code
local function apply_lang(lang)
	if lang == M.state.lang then
		return
	end

	-- Загружаем словарь для нового языка
	local new_lang_dict = load_lang(lang)
	if not new_lang_dict then
		logger:error("Failed to load language dictionary for language: " .. lang)
		return
	end

	M.runtime.lang_dict = new_lang_dict
	M.state.lang = lang
	events.trigger(const.EVENTS.LANG_UPDATE, { lang = lang })
end

--- Set current language chosen by the player
--- @param lang string current language code
function M.set_lang(lang)
	M.state.is_user_selected = true
	apply_lang(lang)
end

--- Set language detected by the platform (e.g. Yandex Games i18n.lang).
--- Ignored if the player chose a language in settings or the language is not localized.
--- @param lang string ISO 639-1 language code
function M.set_platform_lang(lang)
	if M.state.is_user_selected or not M.config.lang_paths[lang] then
		logger:info("Platform language ignored", { lang = lang, is_user_selected = M.state.is_user_selected })
		return
	end
	apply_lang(lang)
end

--- Get current language
--- @return string current language code
function M.get_lang()
	return M.state.lang
end


--- Get translation for locale id
--- @param lang_id string locale id from your localization
--- @return string translated locale
function M.txt(lang_id, ...)
	assert(lang_id, "You must provide the lang id")

	if ... == nil then
		return M.runtime.lang_dict[lang_id] or lang_id
	end

	return string.format(M.runtime.lang_dict[lang_id] or lang_id, ...)
end


--- Get translation for locale id with params
--- @param lang_id string Locale id from your localization
--- @param ... string Params for string.format for lang_id
--- @return string Translated locale
function M.txp(lang_id, ...)
	assert(lang_id, "You must provide the lang id")
	return string.format(M.txt(lang_id), ...)
end


--- Check is translation with lang_id exist
--- @param lang_id string @Locale id from your localization
--- @return bool @Is translation exist
function M.is_exist(lang_id)
	return luax.toboolean(M.runtime.lang_dict[lang_id])
end


--- Возвращает список доступных языков из конфига
--- @return string[] @Список доступных языков в формате ISO 639-1 (двухбуквенный код)
function M.get_langs()
	if not M.config then
		logger:error("\"lang\" module is not initialized")
		return {}
	end

	return tablex.keys(M.config.lang_paths)
end

--- Get default language from gamedata
--- @return string #Default language code
function M.get_default_lang()
	if not M.config then
		logger:error("\"lang\" module is not initialized")
		return ""
	end

	return M.config.default
end


--- Initialize language module called by fun.init
function M.fun_pre_init()

    M.config = gamedata.get_module_config("lang", M.default_config)

	-- Текущий язык по умолчанию из конфига
	M.state.lang = M.config.default

    -- Если среди языков в конфиге есть язык устройства, то используем его как текущий язык
	if M.config.lang_paths[device.get_language()] then
		M.state.lang = device.get_language()
	end

	-- Биндим сохранение, возможно игрок уже выбирал язык в предыдущих сессиях
    saver.bind_save_state("fun.lang", M.state)

    -- Обрабатываем ситуацию если в сейвах язык, которого уже нет в конфигурации
    if not M.config.lang_paths[M.state.lang] then
        M.state.lang = M.config.default
    end

	--- Загружаем словарь для текущего языка
	M.runtime.lang_dict = load_lang(M.state.lang)
end


return M