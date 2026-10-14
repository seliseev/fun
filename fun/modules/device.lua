--- FUN Module: device
--- Модуль для работы с информацией о устройстве
--- Так же этот модуль хранит в сейве device_id


local log = require("fun.libs.log")
local tablex = require("fun.libs.tablex")
local uuid = require("fun.libs.uuid")
local const = require("fun.const")

local saver = require("fun.modules.saver")

local logger = log.get_logger("fun.device")


---@class fun.device.info @Информация о устройстве
---@field language string
---@field territory string
---@field api_version string
---@field system_name string
---@field device_ident string
---@field device_model string
---@field manufacturer string
---@field system_version string
---@field device_language string
---@field gmt_offset string
---@field defold_version string


---@class fun.device
local M = {
	UNKNOWN_REGION = "UN",

	state = {
		device_id = ""
	},
	runtime = {
		is_initialized = false
	}
}


--- Возвращает ID устройства. Если device_id пустой, то генерируется device_id с помощью библиотеки uuid. И сохраняется в файл.
---@return string device_id
function M.get_device_id()
    if not M.runtime.is_initialized then
        logger:error("Device module is not initialized")
        return ""
    end

	if M.state.device_id == "" then
		if M.is_mobile() then
			local sys_info = sys.get_sys_info()
			M.state.device_id = sys_info.device_ident
			logger:debug("Get new device_id", { device_id = M.state.device_id })
		end

		if #M.state.device_id <= 2 then
			M.state.device_id= M.get_uuid()
			logger:debug("Generate device_id from uuid", { device_id = M.state.device_id })
		end
	end

	return M.state.device_id
end


--- Генерирует UUID
--- @param except table|nil of uuid, what not need to be generated
--- @return string uuid
function M.get_uuid(except)
	if not except then
		return uuid()
	else
		while true do
			local id = uuid()
			if not tablex.contains(except) then
				return id
			end
		end
	end
end


--- Возвращает регион устройства. Если регион не известен, то возвращает "UN".
--- @return string region
function M.get_region()
	local sys_info = sys.get_sys_info()
	local region = sys_info.territory
	if #region ~= 2 then
		return M.UNKNOWN_REGION
	end

	return region:upper()
end


--- Возвращает язык устройства. Двухбуквенный код ISO-639, например "en".
--- @return string language
function M.get_language()
    local info = sys.get_sys_info()
    return info.language
end


--- Возвращает информацию о устройстве
--- @return fun.device.info
function M.get_device_info()
	local info = sys.get_sys_info()
	local engine_info = sys.get_engine_info()
	local device_info = {
		language = info.language,
		territory = info.territory,
		api_version = info.api_version,
		system_name = info.system_name,
		device_ident = info.device_ident,
		device_model = info.device_model,
		manufacturer = info.manufacturer,
		system_version = info.system_version,
		device_language = info.device_language,
		gmt_offset = tostring(info.gmt_offset),

		defold_version = engine_info.version,
	}

	return device_info
end


--- Проверяет, является ли устройство Android
--- @return boolean
function M.is_android()
	local system_name = sys.get_sys_info().system_name
	return system_name == const.OS.ANDROID
end


--- Проверяет, является ли устройство iOS
--- @return boolean
function M.is_ios()
	local system_name = sys.get_sys_info().system_name
	return system_name == const.OS.IOS
end


--- Проверяет, является ли устройство мобильным (Android или iOS)
--- @return boolean
function M.is_mobile()
	local system_name = sys.get_sys_info().system_name
	return system_name == const.OS.IOS or system_name == const.OS.ANDROID
end


--- Проверяет, является ли устройство десктопным (Windows/MacOS)
--- @return boolean
function M.is_desktop()
	local system_name = sys.get_sys_info().system_name
	return system_name == const.OS.MAC or system_name == const.OS.WINDOWS
end


--- Проверяет, является ли устройство HTML5
--- @return boolean
function M.is_web()
	local system_name = sys.get_sys_info().system_name
	return system_name == const.OS.BROWSER
end


--- Проверяет, является ли устройство HTML5 мобильным
--- @return boolean
function M.is_web_mobile()
	if html5 then
		return html5.run("(typeof window.orientation !== 'undefined') || (navigator.userAgent.indexOf('IEMobile') !== -1);") == "true"
	end
	return false
end


function M.fun_init()
	uuid.randomseed(socket.gettime() * 10000)

    saver.bind_save_state("fun.device", M.state)
	M.runtime.is_initialized = true

	logger:info("Device ID", { device_id = M.get_device_id() })
	logger:info("Device Info", M.get_device_info())
end


return M