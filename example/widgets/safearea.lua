-- Виджет для автоматического позиционирования элементов относительно safearea
-- Работает с нодами N_Anchor, NW_Anchor, NE_Anchor, W_Anchor, E_Anchor, S_Anchor, SW_Anchor, SE_Anchor
-- Если ноды лежат в root, то для правильной работы нужно у root выставить adjust_mode в Streth
--- Пример использования:
--- local safearea = require("example.widgets.safearea") -- Подключаем модуль
--- self.safearea = self.druid:new_widget(widget_safearea, nil, nil) -- Создаем экземпляр виджета внутри init() .gui_script

local camera = require("orthographic.camera")
local luax = require("fun.luax")

---@class widget.safearea: druid.widget
local M = {}

function M:init()
	self.n_anchor = luax.gui.get_node("N_Anchor")
	self.nw_anchor = luax.gui.get_node("NW_Anchor")
	self.ne_anchor = luax.gui.get_node("NE_Anchor")
	self.w_anchor = luax.gui.get_node("W_Anchor")
	self.e_anchor = luax.gui.get_node("E_Anchor")
	self.s_anchor = luax.gui.get_node("S_Anchor")
	self.sw_anchor = luax.gui.get_node("SW_Anchor")
	self.se_anchor = luax.gui.get_node("SE_Anchor")

	local window_width, window_height = camera.get_window_size()
	local display_width, display_height = camera.get_display_size()

	local scale_x = window_width / display_width
	local scale_y = window_height / display_height

	local safe_area = window.get_safe_area()
	local insets = {
		top = safe_area.inset_top or 0,
		bottom = safe_area.inset_bottom or 0,
		left = safe_area.inset_left or 0,
		right = safe_area.inset_right or 0,
	}

	if self.n_anchor then
		luax.gui.add_y(self.n_anchor, -insets.top / scale_y)
	end

	if self.nw_anchor then
		luax.gui.add_x(self.nw_anchor, -insets.left / scale_x)
		luax.gui.add_y(self.nw_anchor, -insets.top / scale_y)
	end

	if self.ne_anchor then
		luax.gui.add_x(self.ne_anchor, insets.right / scale_x)
		luax.gui.add_y(self.ne_anchor, -insets.top / scale_y)
	end

	if self.w_anchor then
		luax.gui.add_x(self.w_anchor, -insets.left / scale_x)
	end

	if self.e_anchor then
		luax.gui.add_x(self.e_anchor, insets.right / scale_x)
	end

	if self.s_anchor then
		luax.gui.add_y(self.s_anchor, insets.bottom / scale_y)
	end

	if self.sw_anchor then
		luax.gui.add_x(self.sw_anchor, -insets.left / scale_x)
		luax.gui.add_y(self.sw_anchor, insets.bottom / scale_y)
	end

	if self.se_anchor then
		luax.gui.add_x(self.se_anchor, insets.right / scale_x)
		luax.gui.add_y(self.se_anchor, insets.bottom / scale_y)
	end
end

function M:on_remove()
	
end


return M
