local const = require("fun.const")

local game = require("fun.modules.game")
local iapservice = require("fun.modules.iapservice")
local adsservice = require("fun.modules.adsservice")
local timex = require("fun.libs.timex")
local segmentation = require("fun.modules.segmentation")
local level_manager = require("example.modules.level_manager")

local Cohorts = {}

--- Регистрируем все когорты для игры
function Cohorts.fun_init()

    -- Новый игрок
    -- Тот кто, еще не прошел 10 уровней
    segmentation.register_cohort(const.COHORTS.NEW, 100, function()
        return level_manager.get_wins() <= 10
    end)

    -- Реактивированный игрок
    -- Активный сегодня, был активeн хотя бы раз за последение 30 дней, но не последние 7 дней
    segmentation.register_cohort(const.COHORTS.REACTIVATED, 90, function()
        local start_of_today = timex.get_time_start_of_day()
        local seven_days_ago = timex.add_days(start_of_today, -7)
        local thirty_days_ago = timex.add_days(start_of_today, -30)

        local is_played_last_seven_days = game.is_played_between(seven_days_ago, start_of_today)
        if is_played_last_seven_days then
            return false
        end

        local is_played_last_thirty_days = game.is_played_between(thirty_days_ago, seven_days_ago)
        return is_played_last_thirty_days
    end)

    -- Восстановленный игрок
    -- Активный сегодня, и последняя активность была более 30 дней назад
    segmentation.register_cohort(const.COHORTS.RESURRECTED, 80, function()
        local start_of_today = timex.get_time_start_of_day()
        local thirty_days_ago = timex.add_days(start_of_today, -30)
        local last_play_time = game.get_last_play_time()

        if last_play_time then
            return last_play_time < thirty_days_ago
        end

        return false
    end)

    -- VIP игрок, который много платил за последние 30 дней: 10 и более USD
    segmentation.register_cohort(const.COHORTS.VIP, 70, function()
        return iapservice.get_revenue(30) >= 10
    end)

    -- Платящий игрок
    segmentation.register_cohort(const.COHORTS.PAYER, 60, function()
        return iapservice.get_revenue(14) > 0
    end)

    -- Активно смотрит rewarded видео
    segmentation.register_cohort(const.COHORTS.WATCHER, 50, function()
        return adsservice.get_avg_rw_per_day(7) >= 5
    end)

    -- Активный игрок, но не смотрит rewarded видео и не платит
    segmentation.register_cohort(const.COHORTS.ACTIVE, 30, function()
        return level_manager.get_avg_wins_per_day(7) >= 3
    end)

    -- Затухающий игрок
    segmentation.register_cohort(const.COHORTS.FADING, 40, function()
        return level_manager.get_avg_wins_per_day(7) < 3
    end)

    -- Default - самый низкий приоритет, всегда срабатывает
    segmentation.register_cohort(const.COHORTS.DEFAULT, 0, function()
        return true
    end)
end

return Cohorts