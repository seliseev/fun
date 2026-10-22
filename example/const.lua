--- Game const module.

---@class game.const
local M = {}

M.MONARCH_SCENES = {
    BACKGROUND = hash("background"),
    HUD = hash("hud"),
    BANK = hash("bank"),
    LEVEL = hash("level"),
    SETTINGS = hash("settings"),
    LEVEL_CHEST = hash("levelchest"),
    CHEATS = hash("cheats"),
    LANGUAGE = hash("language"),
    REWARD = hash("reward"),
    WIN = hash("win"),
    LOADING = hash("loading"),
    POPUP_ONE_BUTTON = hash("popup_one_button"),
    POPUP_TWO_BUTTONS = hash("popup_two_buttons"),
    ACCRUAL_REWARD = hash("accrual"),
    RATEUS = hash("rateus"),
    NOADS = hash("noads"),
}

M.MONARCH_SCENE_TO_STRING = {
    [M.MONARCH_SCENES.BACKGROUND] = "background",
    [M.MONARCH_SCENES.HUD] = "hud",
    [M.MONARCH_SCENES.BANK] = "bank",
    [M.MONARCH_SCENES.LEVEL] = "level",
    [M.MONARCH_SCENES.SETTINGS] = "settings",
    [M.MONARCH_SCENES.LEVEL_CHEST] = "levelchest",
    [M.MONARCH_SCENES.CHEATS] = "cheats",
    [M.MONARCH_SCENES.LANGUAGE] = "language",
    [M.MONARCH_SCENES.REWARD] = "reward",
    [M.MONARCH_SCENES.WIN] = "win",
    [M.MONARCH_SCENES.LOADING] = "loading",
    [M.MONARCH_SCENES.POPUP_ONE_BUTTON] = "popup_one_button",
    [M.MONARCH_SCENES.ACCRUAL_REWARD] = "accrual",
    [M.MONARCH_SCENES.NOADS] = "noads",
}

M.AD_INTERSTITIAL_PLACEMENTS = {
    LEVEL_WIN = "level_win",
    LEVEL_START = "level_start",
}

M.RW_PLACEMENTS = {
    BANK = "bank",
    LEVEL_WIN = "level_win",
}

M.TOKEN = {
    GOLD = "gold",
}

M.SOUNDS = {
    LEVEL_VICTORY = "level_complete",
}

return M
