--- widget.button_text - кнопка с текстом
--- Структура gui_temaplate:
--- root - корневой узел
---  - button - узел кнопки
---  - text - узел текста


---@class widget.button_text.settings
---@field locale_id string
---@field adjust_type string


---@class widget.button_text: druid.widget
local M = {}


--- Инициализация кнопки с текстом
---@param settings widget.button_text.settings
function M:init(settings, callback, params)
	self.settings = settings
	self.callback = callback or function() end

	self.root = self:get_node("root")
	self.button = self.druid:new_button("button", self.on_button, params)
	if settings and settings.locale_id then
		self.text = self.druid:new_lang_text("text", settings.locale_id)
	else
		self.text = self.druid:new_text("text")
	end
end

function M:set_enabled(enabled)
	if type(enabled) ~= "boolean" then
		error("enabled must be a boolean value")
	end

	gui.set_enabled(self.root, enabled)
end


function M:set_text(text)
	text = tostring(text)
	self.text:set_text(text)
end

function M:on_button(params)
	self.callback(self, params)
end


return M
