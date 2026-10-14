--- FUN Module: ads events
--- События модуля рекламы

local event = require("event.event")

--- @class fun.ads.events.on_initialized: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_rewarded_loaded: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_rewarded_failed_to_load: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_rewarded_start: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_rewarded_close: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_rewarded_reward: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_interstitial_loaded: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_interstitial_failed_to_load: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_interstitial_start: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_interstitial_close: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_banner_loaded: event
--- @field trigger fun(_, width: number, height: number)
--- @field subscribe fun(_, callback: fun(width: number, height: number), _)

--- @class fun.ads.events.on_banner_failed_to_load: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_banner_start: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_banner_close: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_banner_destroyed: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.ads.events.on_paid: event
--- @field trigger fun(_, currency_code: string, value_micros: number, precision: number, ad_unit_id: string, response_id: string, mediation_adapter_class_name: string, ad_source_name: string)
--- @field subscribe fun(_, callback: fun(currency_code: string, value_micros: number, precision: number, ad_unit_id: string, response_id: string, mediation_adapter_class_name: string, ad_source_name: string), _)


--- @class fun.ads.events_module
local M = {}

M.on_initialized = event.create()              --[[@as fun.ads.events.on_initialized]]
M.on_rewarded_loaded = event.create()          --[[@as fun.ads.events.on_rewarded_loaded]]
M.on_rewarded_failed_to_load = event.create()  --[[@as fun.ads.events.on_rewarded_failed_to_load]]
M.on_rewarded_start = event.create()           --[[@as fun.ads.events.on_rewarded_start]]
M.on_rewarded_close = event.create()           --[[@as fun.ads.events.on_rewarded_close]]
M.on_rewarded_reward = event.create()          --[[@as fun.ads.events.on_rewarded_reward]]
M.on_rewarded_paid = event.create()            --[[@as fun.ads.events.on_paid]]
M.on_interstitial_loaded = event.create()      --[[@as fun.ads.events.on_interstitial_loaded]]
M.on_interstitial_failed_to_load = event.create() --[[@as fun.ads.events.on_interstitial_failed_to_load]]
M.on_interstitial_start = event.create()       --[[@as fun.ads.events.on_interstitial_start]]
M.on_interstitial_close = event.create()       --[[@as fun.ads.events.on_interstitial_close]]
M.on_interstitial_paid = event.create()        --[[@as fun.ads.events.on_paid]]
M.on_banner_loaded = event.create()            --[[@as fun.ads.events.on_banner_loaded]]
M.on_banner_failed_to_load = event.create()    --[[@as fun.ads.events.on_banner_failed_to_load]]
M.on_banner_start = event.create()             --[[@as fun.ads.events.on_banner_start]]
M.on_banner_close = event.create()             --[[@as fun.ads.events.on_banner_close]]
M.on_banner_destroyed = event.create()         --[[@as fun.ads.events.on_banner_destroyed]]
M.on_banner_paid = event.create()              --[[@as fun.ads.events.on_paid]]

return M

