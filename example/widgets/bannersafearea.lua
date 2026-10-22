--- Виджет для автоматического позиционирования элементов относительно баннера рекламы
--- Работает с нодами N_Anchor, NW_Anchor, NE_Anchor, S_Anchor, SW_Anchor, SE_Anchor
--- Пример использования:
--- local bannersafearea = require("example.widgets.bannersafearea")
--- self.bannersafearea = self.druid:new_widget(widget_bannersafearea, nil, nil)

local camera = require("orthographic.camera")
local events = require("event.events")

local luax = require("fun.luax")
local const = require("fun.const")

local adsservice = require("fun.modules.adsservice")

---@class widget.bannersafearea: druid.widget
local M = {}


---@param self widget.bannersafearea
local function on_banner_close(self)
    for _, anchor in ipairs(self.anchors) do
        if anchor.node then
            gui.set_position(anchor.node, anchor.position)
        end
    end
end

function M:init()
    self.anchors = {
        {node=luax.gui.get_node("N_Anchor"), banner_position=const.ADS_BANNER_POSITION.TOP},
        {node=luax.gui.get_node("NW_Anchor"), banner_position=const.ADS_BANNER_POSITION.TOP},
        {node=luax.gui.get_node("NE_Anchor"), banner_position=const.ADS_BANNER_POSITION.TOP},
        {node=luax.gui.get_node("S_Anchor"), banner_position=const.ADS_BANNER_POSITION.BOTTOM},
        {node=luax.gui.get_node("SW_Anchor"), banner_position=const.ADS_BANNER_POSITION.BOTTOM},
        {node=luax.gui.get_node("SE_Anchor"), banner_position=const.ADS_BANNER_POSITION.BOTTOM},
    }

    for _, anchor in ipairs(self.anchors) do
        if anchor.node then
            anchor.position = gui.get_position(anchor.node)
        end
    end

    adsservice.on_banner_start:subscribe(M.reposition, self)
    adsservice.on_banner_refresh:subscribe(M.reposition, self)
    adsservice.on_banner_close:subscribe(on_banner_close, self)

    if adsservice.is_banner_showing() then
        self:reposition(adsservice.get_banner_width(), adsservice.get_banner_height(), adsservice.get_banner_position())
    end
end

function M:reposition(width, height, position)
    local window_width, window_height = camera.get_window_size()
    local display_width, display_height = camera.get_display_size()

	local scale_x = window_width / display_width
	local scale_y = window_height / display_height
    local y_offset = 0

    if position == const.ADS_BANNER_POSITION.TOP then
        y_offset = -height/scale_y
    elseif position == const.ADS_BANNER_POSITION.BOTTOM then
        y_offset = height/scale_y
    else
        
    end

    for _, anchor in ipairs(self.anchors) do
        if anchor.node and anchor.banner_position == position then
            local position = vmath.vector3(anchor.position)
            position.y = position.y + y_offset
            gui.set_position(anchor.node, position)
        end
    end
end

function M:on_remove()
	adsservice.on_banner_start:unsubscribe(M.reposition, self)
    adsservice.on_banner_refresh:unsubscribe(M.reposition, self)
    adsservice.on_banner_close:unsubscribe(on_banner_close, self)
end


return M
