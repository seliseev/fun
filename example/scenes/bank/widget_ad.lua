local token = require("token.token")
local log = require("fun.libs.log")


local luax = require("fun.luax")
local timex = require("fun.libs.timex")
local tablex = require("fun.libs.tablex")

local adsservice = require("fun.modules.adsservice")
local segmentation = require("fun.modules.segmentation")
local saver = require("fun.modules.saver")
local time_string = require("fun.libs.time_string")
local lang = require("fun.modules.lang")
local wallet = require("fun.modules.wallet")

local logger = log.get_logger("scenes.bank.widget_ad")


local TEXT_KEY_BUTTON_FREE = "bank.button.free"

---@class widget.bank.widget_ad.state
---@field last_seen_time number


---@class widget.bank.widget_ad.config
---@field placement_id string
---@field cooldown number
---@field reward string


---@type widget.bank.widget_ad.config
local DEFAULT_AD_CONFIG = {
	placement_id = "bank",
	cooldown = 14400,
	reward = "rw_bank"
}

---@class widget.bank.widget_ad: druid.widget
local M = {}

local function on_adsservice_rewarded_reward(self, placement_id)
	if placement_id ~= self.placement_id then
		return
	end
	self._state.last_seen_time = timex.get_time()
	wallet.add_group(self.reward, "AD", self.placement_id, true)
end

local function stop_loading_dots_animation(self)
	if self._loading_dots_timer then
		timer.cancel(self._loading_dots_timer)
		self._loading_dots_timer = nil
	end
end

local function start_loading_dots_animation(self)
	stop_loading_dots_animation(self)
	
	local dots = {".", "..", "..."}
	self._loading_dots_index = 0
	
	self.button_text:set_text(".")
	self._loading_dots_timer = timer.delay(0.5, true, function()
		self._loading_dots_index = (self._loading_dots_index % #dots) + 1
		self.button_text:set_text(dots[self._loading_dots_index])
	end)
end

local function update_button_state(self)
	local time_left = timex.get_seconds_until_target_time(self._state.last_seen_time+self.cooldown)
	local ad_ready = adsservice.is_rewarded_ready()
	local cooldown_active = self._state.last_seen_time ~= -1 and time_left > 0

	--- Если реклама на кулдауне
	if cooldown_active then
		stop_loading_dots_animation(self)
		self.button:set_enabled(false)
		self.button_text:set_text(time_string.get_smart_time_string(time_left))
	
	--- Если кулдаун закончился и реклама готова к показу
	elseif ad_ready then
		stop_loading_dots_animation(self)
		self.button:set_enabled(true)
		self.button_text:set_text(lang.txt(TEXT_KEY_BUTTON_FREE))
	else
		self.button:set_enabled(false)
		if not self._loading_dots_timer then
			start_loading_dots_animation(self)
		end
	end
end

---@param layout druid.layout
function M:init(layout)
	assert(layout, "layout is required")

	self.layout = layout
	self._state = {
		last_seen_time = -1 -- -1 означает, что реклама не была показана
	}
	saver.bind_save_state("widget.bank.widget_ad", self._state)

	local ad_config = segmentation.get_module_config("bank", "ad", DEFAULT_AD_CONFIG)
	self.placement_id = ad_config.placement_id
	self.cooldown = ad_config.cooldown
	self.reward = ad_config.reward

	local rewards = token.get_token_group(self.reward)
	if not rewards then
		logger:error("Reward not found", {reward = self.reward})
		return
	end
	if tablex.length(rewards) ~= 1 then
		logger:error("Rewards must be exactly one", {reward = self.reward})
		return
	end
	local reward_value = tablex.values(rewards)[1]

	self.root = self:get_node("root")

	--- Проверяем, что текущий юзер в своей когорте может смотреть рекламу
	--- Тут же учитываются общие лимиты и ограничения для placement_id
	if not adsservice.can_show_rewarded(self.placement_id) then
		gui.set_enabled(self.root, false)
		return
	end

	self.button = self.druid:new_button("button/button", self.on_button, self)
	self.button_text = self.druid:new_rich_text("button/text", lang.txt(TEXT_KEY_BUTTON_FREE))
	self.value_text = self.druid:new_text("value", luax.string.split_by_rank(tostring(reward_value)))

    adsservice.on_rewarded_reward:subscribe(on_adsservice_rewarded_reward, self)

	self.layout:add(gui.get_node("ad_content"))

	update_button_state(self)
	timer.delay(1, true, function(_, handle, time_elapsed)
		update_button_state(self)
	end)
end


function M:on_remove()
	stop_loading_dots_animation(self)
	adsservice.on_rewarded_reward:unsubscribe(on_adsservice_rewarded_reward, self)
end


function M:update(dt)
	
end

function M:on_button()
	if not adsservice.show_rewarded(self.placement_id) then
		logger:warn("Failed to show rewarded ad", { placement_id = self.placement_id })
		return
	end
end


return M
