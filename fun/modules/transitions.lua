--- FUN Module: transitions
--- Модуль для работы с переходами между экранами в Monarch
--- Используется для получения конфигурации переходов для экранов и узлов

local monarch = require("monarch.monarch")
local tablex = require("fun.libs.tablex")
local log = require("fun.libs.log")
local utils = require("fun.libs.utils")

local logger = log.get_logger("fun.monarch")

--- @class fun.transitions
local M = {
    realtime = {
        monarch_data = nil
    }
}

local monarch_messages = {
    monarch.TRANSITION.DONE,
    monarch.TRANSITION.SHOW_IN,
    monarch.TRANSITION.SHOW_OUT,
    monarch.TRANSITION.BACK_IN,
    monarch.TRANSITION.BACK_OUT,
    monarch.SCREEN_TRANSITION_OUT_STARTED,
    monarch.SCREEN_TRANSITION_OUT_FINISHED,
    monarch.SCREEN_TRANSITION_IN_STARTED,
    monarch.SCREEN_TRANSITION_IN_FINISHED,
    monarch.SCREEN_TRANSITION_FAILED,
    monarch.FOCUS.GAINED,
    monarch.FOCUS.LOST
}

local function get_transition_node(transition_type, node_name, transition_config)
    for _, transition in pairs(transition_config[transition_type]) do
        if transition.node_name == node_name then
            return transition
        end
    end
    return nil
end

local function override_transitions(source_transitions, target_transitions)
    for key, value in pairs(source_transitions) do
        if key == "show_in" or key == "show_out" or key == "back_in" or key == "back_out" then
            if not target_transitions[key] then
                target_transitions[key] = {}
            end
            for _, transition in pairs(value) do
                local target_transition = get_transition_node(key, transition.node_name, target_transitions)
                if target_transition then
                    -- Копируем все свойства из source в target
                    for prop_key, prop_value in pairs(transition) do
                        target_transition[prop_key] = prop_value
                    end
                else
                    -- Делаем глубокую копию перед вставкой
                    table.insert(target_transitions[key], tablex.deepcopy(transition))
                end
            end
        end
    end
    return target_transitions
end


function M.get_config_for_screen(screen_id)
    if not M.realtime.monarch_data then
        logger:error("Monarch data is not loaded, be sure that you have set the Fun / Monarch Data Path in game.project")
        return nil
    end

    for _, config in pairs(M.realtime.monarch_data) do
        if hash(config.screen_id) == screen_id then
            return config
        end
    end

    logger:warn("Monarch config is not found for screen: " .. screen_id)
    return nil
end


function M.get_transitions_for_screen(screen_id)
    local screen_config = M.get_config_for_screen(screen_id)
    if not screen_config then
        return nil
    end

    if not screen_config.transitions then
        logger:warn("Transitions config is not found for screen: " .. screen_id)
        return nil
    end

    return screen_config.transitions
end

function M.get_transitions_by_node(screen_id, next_screen_id, previous_screen_id)
    local transitions_config = M.get_transitions_for_screen(screen_id)
    if not transitions_config then
        return nil
    end

    local screen = next_screen_id or previous_screen_id
    local default_transition = nil
    local custom_transition = nil
    for _, transition in pairs(transitions_config) do
        if hash(transition.screen) == screen then
            custom_transition = transition
        end
        if hash(transition.screen) == hash("default") then
            default_transition = tablex.deepcopy(transition)
        end
    end

    if custom_transition and default_transition then
        override_transitions(custom_transition, default_transition)
    end

    return default_transition or custom_transition
end


function M.fun_init()
    local monarch_data_path = sys.get_config_string("fun.monarch_data_path")
    if not monarch_data_path then
        logger:error("Monarch data path not specified in game.project")
        return
    end

    M.realtime.monarch_data = utils.load_json(monarch_data_path)
    if not M.realtime.monarch_data then
        logger:error("Error loading monarch data: " .. monarch_data_path)
        return
    end

    monarch.add_listener(msg.url())
end

function M.fun_on_message(message_id, message, sender)

    -- if tablex.contains(monarch_messages, message_id) then
    --     logger:debug("Message from fun.monarch, message_id: " .. message_id .. " from sender: " .. tostring(sender) .. "message: ".. tablex.tostring(message))
    -- end
end


function M.fun_final()
    monarch.remove_listener(msg.url())
end

return M