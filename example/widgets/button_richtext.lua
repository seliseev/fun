--- widget.button_richtext - кнопка с RichText
--- Структура gui_temaplate:
--- root - корневой узел
---  - button - узел кнопки
---  - text - узел текста

local events = require("event.events")
local const = require("fun.const")
local lang = require("fun.modules.lang")

---@class widget.button_richtext.settings
---@field locale_id string
---@field adjust_type string


---@class widget.button_richtext: druid.widget
local M = {}

local function validate_settings(settings)
	assert(settings.locale_id, "locale_id is required")
	assert(settings.adjust_type, "adjust_type is required")
	return settings
end

--- Инициализация кнопки с текстом
---@param settings widget.button_text.settings
function M:init(settings, callback)
	validate_settings(settings)
	self.settings = settings
	self.callback = callback or function() end
	self.root = self:get_node("root")
	self.button = self.druid:new_button("button", self.on_button, self)
	self.text = self.druid:new_rich_text("text", lang.txt(settings.locale_id))

	events.subscribe(const.EVENTS.LANG_UPDATE, self.on_language_change, self)
end

function M:on_language_change()
	self.text:set_text(self.settings.locale_id)
end

function M:set_text(text)
	self.text:set_text(text)
end

function M:on_button()
	self.callback(self)
end


return M
