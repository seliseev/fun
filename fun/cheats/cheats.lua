--- FUN Cheats: общая чит-панель.
--- Игра регистрирует вкладки и пункты, панель fun/cheats/cheats.gui рисует их при первом открытии.
--- Вкладка general со сбросом прогресса есть всегда.
---
--- local cheats = require("fun.cheats.cheats")
--- cheats.button("general", function() return "GOD MODE: " .. (god and "ON" or "OFF") end, function() god = not god end)
--- cheats.token("player", "Money", "money")
--- cheats.value("player", "Level", get_level, set_level)
--- cheats.events("liveops", { { title, status(), to_reward(left), get_type(), next_type() } })

local saver = require("saver.saver")
local wallet = require("fun.modules.wallet")
local game = require("fun.modules.game")

local M = {
	--- false - кнопки CHEATS нет (например, в тестовом режиме)
	enabled = true,
	--- Ключи сохранения, которые переживают сброс прогресса
	keep_keys = { "saver", "fun.device" },
	--- Кнопка CHEATS: сдвиг от левого верхнего угла безопасной зоны
	open_offset = vmath.vector3(4, -4, 0),
	---@type table[] { id, title, items }
	tabs = {},
}

---@param id string
---@param title string|nil
---@return table
function M.tab(id, title)
	for _, tab in ipairs(M.tabs) do
		if tab.id == id then
			tab.title = title or tab.title
			return tab
		end
	end
	local tab = { id = id, title = title or (id:sub(1, 1):upper() .. id:sub(2)), items = {} }
	table.insert(M.tabs, tab)
	return tab
end

---@param tab_id string
---@param text string|fun():string Подпись; функцию панель зовет каждый кадр
---@param on_click fun()
function M.button(tab_id, text, on_click)
	table.insert(M.tab(tab_id).items, { type = "button", text = text, on_click = on_click })
end

--- Число с кнопками ±1…1000 и полем ввода
---@param tab_id string
---@param title string
---@param get fun():number
---@param set fun(value:number)
function M.value(tab_id, title, get, set)
	table.insert(M.tab(tab_id).items, { type = "value", title = title, get = get, set = set })
end

---@param tab_id string
---@param title string
---@param token_id string Токен кошелька FUN
function M.token(tab_id, title, token_id)
	M.value(tab_id, title, function() return wallet.get(token_id) end, function(value)
		wallet.set(token_id, value)
		wallet.sync_visual(token_id)
	end)
end

--- Выбор события и кнопки GET NEXT REWARD, NEXT REWARD - 1, TYPE.
--- Событие: title, status() - строка состояния, to_reward(left) - чтобы до награды этапа осталось left,
--- get_type() / next_type() - тип события и смена на следующий
---@param tab_id string
---@param events table[]
function M.events(tab_id, events)
	table.insert(M.tab(tab_id).items, { type = "events", events = events })
end

--- Стирает сохранение, кроме keep_keys, и перезапускает игру
function M.reset_progress()
	local state = saver.get_game_state()
	local keep = {}
	for _, key in ipairs(M.keep_keys) do
		keep[key] = state[key]
	end
	-- Модули держат ссылки на старые таблицы, но до перезапуска сохраняется уже только новое состояние
	saver.set_game_state(keep)
	saver.save_game_state()
	game.reboot()
end

table.insert(M.tab("general").items, { type = "reset" })

return M
