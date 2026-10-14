-- This module is responsible for managing the level chest functionality in the game.

local events = require("event.events")
local event = require("event.event")

local luax = require("fun.luax")
local saver = require("fun.modules.saver")
local segmentation = require("fun.modules.segmentation")
local const = require("fun.const")
local wallet = require("fun.modules.wallet")

local log = require("fun.libs.log")
local logger = log.get_logger("fun.levelchest")

-----------------------------------------------------------
------------------------- CHEST ---------------------------
-----------------------------------------------------------

--- @class fun.chest.state
--- @field number integer порядковый номер сундука
--- @field value integer прогресс текущего сундука
--- @field last_seen_value integer последний прогресс, который видел игрок
--- @field goal integer цель для заполнения сундука
--- @field reward_group string группа наград для достижения цели
--- @field is_rewarded boolean флаг, что сундук получен


--- @class fun.chest.chest
--- @field private _state fun.chest.state состояние сундука
--- @field on_chest_full event событие, которое срабатывает, когда сундук заполнен
local Chest = {}
Chest.__index = Chest


--- Создаёт новый сундук
---@param state fun.chest.state|nil
---@return fun.chest.chest
function Chest.new(state)
    local self = setmetatable({}, Chest)
    assert(state, "State must be provided")
    assert(state.number ~= nil, "State must contain number")
    assert(state.value ~= nil, "State must contain value")
    assert(state.last_seen_value ~= nil, "State must contain last_seen_value")
    assert(state.goal ~= nil and state.goal > 0, "State must contain goal and must be more then 0")
    assert(state.reward_group ~= nil, 'State must contain "reward_group"')
    assert(state.is_rewarded ~= nil, "State must contain is_rewarded")

    self._state = state
    self.on_chest_full = event.create()
    return self
end

function Chest:final()
    self.on_chest_full:clear()
end

function Chest:add_value(amount)
    self._state.value = self._state.value + amount

    if self._state.value > self._state.goal then
        logger:warn("Value cannot exceed goal, setting to goal value")
        self._state.value = self._state.goal
    end

    if self._state.value == self._state.goal then
        logger:info("Chest goal reached")
        self.on_chest_full:trigger(self)
    end
end

function Chest:get_number()
    return self._state.number
end

function Chest:get_value()
    return self._state.value
end

function Chest:get_goal()
    return self._state.goal
end

function Chest:get_last_seen_value()
    return self._state.last_seen_value
end

function Chest:get_reward_group()
    return self._state.reward_group
end

function Chest:is_full()
    return self._state.value >= self._state.goal
end

function Chest:add_last_seen_value(amount)
    self:set_last_seen_value(self._state.last_seen_value + amount)
end

function Chest:set_last_seen_value(value)
    self._state.last_seen_value = value
    if self._state.last_seen_value > self._state.value then
        logger:warn("Visual value cannot exceed actual value")
        self._state.last_seen_value = self._state.value
    end
end

function Chest:is_rewarded()
    return self._state.is_rewarded
end

function Chest:reward_it()
    self._state.is_rewarded = true

    wallet.add_group(self._state.reward_group, "levelchest", "reward", true)

    logger:info("Chest " .. self._state.number .. " has been rewarded")
end

-----------------------------------------------------------
----------------------- GAME DATA -------------------------
-----------------------------------------------------------

--- @class fun.chest.config
--- @field is_enabled boolean включен ли сундук
--- @field goal integer сколько уровней надо пройти для получения сундука
--- @field reward_group string группа наград для достижения цели
local chest_default_config = {
    is_enabled = false,
    goal = 10,
    reward_group = "levelchest_default"
}

-----------------------------------------------------------
------------------------ MANAGER --------------------------
-----------------------------------------------------------

--- @class fun.chest.manager
--- @field chest_list fun.chest.chest[] список сундуков
local M = {
    runtime = {
        chest_instances = {}
    },

    --- @type fun.chest.state[] состояние сундуков
    state = {}
}

--- Создаёт новое состояние сундука
---@param number number порядковый номер сундука
---@param config fun.chest.config конфигурация сундука
---@return fun.chest.state
local function create_chest_state(number, config)
    return {
        number = number,
        value = 0,
        last_seen_value = 0,
        goal = config.goal,
        reward_group = config.reward_group,
        is_rewarded = false
    }
end


--- Инициализирует новый сундук, если он не инициализирован, а текущий если есть добавляет в историю
local function next_chest()
    -- Получаем конфигурацию сундука
    local config = segmentation.get_module_config("levelchest", nil, chest_default_config)
    assert(config, "Level chest configuration not found in gamedata")

    -- Если сундук отключен, то ничего не делаем
    if not config.is_enabled then
        logger:info("Level chest is disabled, skipping next chest initialization")
        return
    end
    
    --- Проверяем, что текущий сундук если он есть, действительно заполнен и можно создать новый сундук
    local current_chest = M.get_current()
    if current_chest and not current_chest:is_full() then
        logger:warn("Current level chest is not completed, skipping next chest initialization")
        return
    end

    -- Инициализируем новый сундук
    local new_state = create_chest_state(#M.state + 1, config)
    local new_chest = Chest.new(new_state)
    new_chest.on_chest_full:subscribe(next_chest)
    table.insert(M.state, new_state)
    table.insert(M.runtime.chest_instances, new_chest)

    logger:info("New level chest initialized: " .. new_chest:get_number())
    saver.save()
end


local function reload_chest_state()
    M.runtime.chest_instances = {}
    for index, chest_state in ipairs(M.state) do
        M.runtime.chest_instances[index] = Chest.new(chest_state)
        if not M.runtime.chest_instances[index]:is_full() then
            M.runtime.chest_instances[index].on_chest_full:subscribe(next_chest)
        end
    end
end


--- Обработка события победы в уровне
local function on_level_win()
    -- Проверяем, есть ли текущий сундук, если нет, то ничего не делаем
    local current = M.get_current()
    if not current then
        logger:info("Level chest is not active, skipping 'on_level_win' processing")
        return
    end

    -- Добавляем прогресс в текущий сундук
    current:add_value(1)
end


-----------------------------------------------------------
------------------ PUBLIC METHODS -------------------------
-----------------------------------------------------------

--- Возвращает информацию о текущем сундуке
---@return fun.chest.chest|nil
function M.get_current()
    if #M.runtime.chest_instances == 0 then
        return nil
    end
    return M.runtime.chest_instances[#M.runtime.chest_instances]
end


--- Возвращает информацию о последнем сундуке, который не был получен
---@return fun.chest.chest|nil
function M.get_last_not_rewarded()
    for _, chest in ipairs(M.runtime.chest_instances) do
        if not chest:is_rewarded() then
            return chest
        end
    end
    return nil
end

-----------------------------------------------------------
------------------ FUN METHODS ----------------------------
-----------------------------------------------------------

function M.fun_init()
    saver.bind_save_state("fun.levelchest", M.state)

    reload_chest_state()
end

function M.fun_post_init()
   --- Если текущего сундука нет, стартуем новый
    if not M.get_current() or M.get_current():is_rewarded() then
        logger:info("Current level chest is not initialized, initializing next chest")
        next_chest()
    end

    events.subscribe(const.EVENTS.LEVEL_WIN, on_level_win, nil)
end

return M