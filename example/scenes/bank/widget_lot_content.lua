local tablex = require("fun.libs.tablex")
local segmentation = require("fun.modules.segmentation")

local widget_lot = require("example.scenes.bank.widget_lot")

---@class widget.bank.widget_lot_content: druid.widget
local M = {}

local function validate_config(lots_config)
	for sku, config in pairs(lots_config) do
		assert(config.order, "Order is required", {sku = sku})
		assert(config.flipbook, "Flipbook is required", {sku = sku})
	end
end


--- Добавляет новый лот в список
---@param self widget.bank.widget_lot_content
---@param sku string
local function add_element(self, sku, config)
	local prefab_nodes = gui.clone_tree(self.lot_prefab)
	local root = prefab_nodes[gui.get_id(self.lot_prefab)]
	table.insert(self.lots_nodes, root)

	local widget = self.druid:new_widget(widget_lot, "lot_prefab", prefab_nodes, sku, config)
	table.insert(self.lots_widgets, widget)

	gui.set_enabled(root, true)

	self.grid_for_lots:add(root)
end


--- 
---@param layout druid.layout
function M:init(layout)
	self.druid_layout = layout
    self.node_lots_content = self:get_node("lots_content")

    self.grid_for_lots = self.druid:new_grid(self.node_lots_content, "lot_prefab/root", 1)
	self.grid_for_lots.on_change_items:subscribe(function (self, index)
		gui.set_size(self.node_lots_content, self.grid_for_lots:get_size())
	end)

	self.lots_nodes = {}
	self.lots_widgets = {}

	self.lot_prefab = self:get_node("lot_prefab/root")
	gui.set_enabled(self.lot_prefab, false)

	--- Формирование лотов
	local lots_config = segmentation.get_module_config("bank", "lots", {})
	validate_config(lots_config)
	
	--- т.к. таблица конфигураций может быть не отсортирована по порядку, сортируем массив ключей
	--- на основе поля order
	local lots_skus = tablex.keys(lots_config)
	table.sort(lots_skus, function(a, b)
	    return lots_config[a].order < lots_config[b].order
	end)
	--- Проходимся по отсортированным ключам и добавляем элементы в сетку в нужном порядке
	for _, sku in ipairs(lots_skus) do
		local config = lots_config[sku]
		add_element(self, sku, config)
	end

	self.druid_layout:add(self.node_lots_content)
end




return M