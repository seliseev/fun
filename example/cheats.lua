--- Пункты чит-панели FUN (fun.cheats) для примера
local cheats = require("fun.cheats.cheats")
local monarch = require("monarch.monarch")
local game_const = require("example.const")
local level_manager = require("example.modules.level_manager")
local levelchest = require("fun.modules.levelchest")
local iap = require("fun.modules.iap.iap")
local adsservice = require("fun.modules.adsservice")
local noads = require("fun.modules.noads")

cheats.button("general", "COMPLETE LEVEL", level_manager.complete)
cheats.button("general", "RESTART LEVEL", level_manager.restart)
cheats.button("general", "SHOW RATE US", function() monarch.show(game_const.MONARCH_SCENES.RATEUS) end)

cheats.token("player", "Gold", game_const.TOKEN.GOLD)
cheats.value("player", "Level chest", function() return levelchest.get_current():get_value() end,
	function(value) levelchest.get_current():add_value(value - levelchest.get_current():get_value()) end)

cheats.button("ads", "SHOW REWARDED", function()
	adsservice.show_rewarded(game_const.RW_PLACEMENTS.LEVEL_WIN, true)
end)
cheats.button("ads", "SHOW INTERSTITIAL", function()
	adsservice.show_interstitial(game_const.AD_INTERSTITIAL_PLACEMENTS.LEVEL_WIN, true)
end)
cheats.button("ads", function() return adsservice.runtime.is_enabled and "ADS: ON" or "ADS: OFF" end, function()
	if adsservice.runtime.is_enabled then
		adsservice.disable_ads()
	else
		adsservice.enable_ads()
	end
end)
cheats.button("ads", function() return noads.is_purchased() and "NOADS: PURCHASED" or "NOADS: NO" end, function()
	if noads.is_purchased() then
		noads.reset()
	else
		noads.purchase()
	end
end)

cheats.button("iap", "TEST PURCHASED", function() iap.purchase("android.test.purchased") end)
cheats.button("iap", "TEST CANCELLED", function() iap.purchase("android.test.canceled") end)
cheats.button("iap", "TEST REFUNDED", function() iap.purchase("android.test.refunded") end)
cheats.button("iap", "TEST UNAVAILABLE", function() iap.purchase("android.test.item_unavailable") end)
