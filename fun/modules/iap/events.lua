local event = require("event.event")

---@class fun.iap.events.on_transaction: event
---@field trigger fun(_, transaction: fun.iap.transaction, error: table|nil): any
---@field subscribe fun(_, callback: fun(transaction: fun.iap.transaction, error: table|nil)): boolean

---@class fun.iap.events.on_list_products: event
---@field trigger fun(_, success: boolean, products: fun.iap.product[], error: table|nil): any
---@field subscribe fun(_, callback: fun(success: boolean, products: fun.iap.product[], error: table|nil), callback_context: any|nil): boolean

---@class fun.iap.events.on_purchase_error: event
---@field trigger fun(_, error: table|nil): any
---@field subscribe fun(_, callback: fun(error: table|nil)): boolean

local M = {}

M.on_purchase_start = event.create()         --[[@as fun.iap.events.on_transaction]]
M.on_purchase_purchased = event.create()     --[[@as fun.iap.events.on_transaction]]
M.on_purchase_failed = event.create()        --[[@as fun.iap.events.on_transaction]]
M.on_purchase_restored = event.create()      --[[@as fun.iap.events.on_transaction]]
M.on_purchase_unverified = event.create()    --[[@as fun.iap.events.on_transaction]]
M.on_purchase_error = event.create()         --[[@as fun.iap.events.on_transaction]]
M.on_list_products = event.create()          --[[@as fun.iap.events.on_list_products]]

return M