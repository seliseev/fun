--- Defold Lua extended module
--- 
local tablex = require("fun.libs.tablex")
local mathx = require("fun.libs.mathx")

---@class fun.luax
local M = {
	string = {},
	debug = {},
	func = {},
	operators = {},
	camera = {},
	timer = {},
	toboolean = function(arg) return not not arg end,
}

--- Проверяет, является ли объект экземпляром класса
---@param obj any
---@param class any
---@return boolean
M.instanceof = function(obj, class)
    local mt = getmetatable(obj)
    while mt do
        if mt == class then
            return true
        end
        mt = getmetatable(mt)
    end
    return false
end

--- @class fun.luax.go
M.go = {
	PROP_POS = "position",
	PROP_POS_X = "position.x",
	PROP_POS_Y = "position.y",
	PROP_SCALE = "scale",
	PROP_SCALE_X = "scale.x",
	PROP_SCALE_Y = "scale.y",
	PROP_ALPHA = "tint.w",
	PROP_EULER = "euler",
	PROP_EULER_X = "euler.x",
	PROP_EULER_Y = "euler.y",
	PROP_EULER_Z = "euler.z"
}

--- @class fun.luax.gui
M.gui = {
	PROP_POS = "position",
	PROP_POS_X = "position.x",
	PROP_POS_Y = "position.y",
	PROP_ALPHA = "color.w",
	PROP_COLOR = "color",
	PROP_SCALE = "scale",
	PROP_SCALE_X = "scale.x",
	PROP_SCALE_Y = "scale.y",
	PROP_ROT = "rotation",
	PROP_ROT_X = "rotation.x",
	PROP_ROT_Y = "rotation.y",
	PROP_ROT_Z = "rotation.z",
	PROP_SIZE = "size",
	PROP_SIZE_X = "size.x",
	PROP_SIZE_Y = "size.y",
	PROP_SIZE_Z = "size.z"
}

--- @class fun.luax.vmath
M.vmath = {
	VECTOR_ZERO = vmath.vector3(0),
	VECTOR_ONE = vmath.vector3(1),
	VECTOR4_ONE = vmath.vector4(1)
}



M.string.empty = ""
M.vmath.temp_vector = vmath.vector3(0)
M.func.empty = function() end


--- string.is_empty
-- @function luax.string.is_empty
function M.string.is_empty(str)
	return str == nil or str == ""
end


--- Splits a string into a table of substrings
---@param inputstr string
---@param sep string
---@return table<string>
function M.string.split(inputstr, sep)
	sep = sep or "%s"
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end


--- Добавляет нули в начало строки
---@param str string
---@param count integer
---@return string
function M.string.add_prefix_zeros(str, count)
	for _ = string.len(str), count - 1 do
		str = "0" .. str
	end
	return str
end


--- Разбивает строку на разряды
---@param str any
---@return string
function M.string.split_by_rank(str)
	str = tostring(str)
	local new_s = ""

	local cur_index = str:len()
	while cur_index >= 3 do
		new_s = str:sub(cur_index - 2, cur_index) .. " " .. new_s
		cur_index = cur_index - 3
	end
	if cur_index > 0 then
		new_s = str:sub(1, cur_index) .. " " .. new_s
	end

	return new_s
end


--- string.starts
-- @function luax.string.starts
function M.string.starts(String,Start)
	return string.sub(String,1,string.len(Start))==Start
end


--- string.ends
-- @function luax.string.ends
function M.string.ends(String,End)
	return End=='' or string.sub(String,-string.len(End))==End
end


--- string.random
-- @function luax.string.random
function M.string.random(length)
	local result = ""

	for i = 1, length do
		result = result .. string.char(mathx.random(97, 122))
	end

	return result
end

--- Получает символы UTF-8 из строки
---@param str string
---@return table # table of UTF-8 characters
function M.string.utf8_chars(str)
    local chars = {}
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
        local char_len = 1
        
        if byte >= 240 then
            char_len = 4
        elseif byte >= 224 then
            char_len = 3
        elseif byte >= 192 then
            char_len = 2
        end
        
        table.insert(chars, str:sub(i, i + char_len - 1))
        i = i + char_len
    end
    return chars
end

--- Возвращает длину строки в символах UTF-8
---@param str string
---@return integer # length of the string in UTF-8 characters
function M.string.utf8_length(str)
	local length = 0
    for _ in string.gmatch(str, "[^\128-\191]") do
        length = length + 1
    end
    return length
end

--- Возвращает подстроку в символах UTF-8
---@param str string
---@param start_i integer
---@param end_i integer
---@return string
function M.string.utf8_sub(str, start_i, end_i)
    -- Преобразуем в таблицу символов
    local chars = M.string.utf8_chars(str)
    local len = #chars

    -- Обработка отрицательных индексов
    if start_i < 0 then
        start_i = len + start_i + 1
    end
    if end_i and end_i < 0 then
        end_i = len + end_i + 1
    end

    -- Ограничения
    start_i = math.max(1, start_i)
    end_i = end_i and math.min(len, end_i) or len

    -- Сборка подстроки
    local result = {}
    for i = start_i, end_i do
        result[#result + 1] = chars[i]
    end

    return table.concat(result)
end

--- Перемешивает символы UTF-8 строки
---@param str string Строка с UTF-8 символами
---@param seed number|nil Опциональный seed для генератора случайных чисел
---@return string Строка с перемешанными символами
function M.string.shuffle(str, seed)
	local chars = M.string.utf8_chars(str)
	tablex.shuffle(chars, seed)
	return table.concat(chars)
end


--- Устанавливает альфа-канал для спрайта
---@param sprite_id string|url|userdata
---@param alpha float
function M.go.set_alpha(sprite_id, alpha)
	go.set(sprite_id, "tint.w", alpha)
end


--- Безопасный доступ к gui.get_node
---@param name any
---@return node|nil
function M.gui.get_node(name)
	local ok, node = pcall(gui.get_node, name)
    return ok and node or nil
end

--- Устанавливает альфа-канал для узла
---@param node node
---@param alpha number
function M.gui.set_alpha(node, alpha)
	local color = gui.get_color(node)
	color.w = alpha
	gui.set_color(node, color)
end

--- gui.set_x
-- @function luax.gui.set_x
function M.gui.set_x(node, pos_x)
	local position = gui.get_position(node)
	position.x = pos_x
	gui.set_position(node, position)
end


--- gui.add_x
-- @function luax.gui.add_x
function M.gui.add_x(node, add_x)
	local position = gui.get_position(node)
	position.x = position.x + add_x
	gui.set_position(node, position)
end


--- gui.set_y
-- @function luax.gui.set_y
function M.gui.set_y(node, pos_y)
	local position = gui.get_position(node)
	position.y = pos_y
	gui.set_position(node, position)
end


--- gui.add_y
-- @function luax.gui.add_y
function M.gui.add_y(node, add_y)
	local position = gui.get_position(node)
	position.y = position.y + add_y
	gui.set_position(node, position)
end


--- gui.set_z
-- @function luax.gui.set_z
function M.gui.set_z(node, pos_z)
	local position = gui.get_position(node)
	position.z = pos_z
	gui.set_position(node, position)
end


--- gui.add_z
-- @function luax.gui.add_z
function M.gui.add_z(node, add_z)
	local position = gui.get_position(node)
	position.z = position.z + add_z
	gui.set_position(node, position)
end

--- Возвращает альфа канал узла
---@param node userdata
---@return float
function M.gui.get_alpha(node)
	return gui.get_color(node).w
end


--- debug.timelog
-- @function luax.debug.timelog
function M.debug.timelog(name)
	if not debug._timelog_time then
		debug._timelog_time = socket.gettime()
		return
	end
	print("[Timelog]:", name, "time:", socket.gettime() - debug._timelog_time)
	debug._timelog_time = socket.gettime()
end


--- gui.is_chain_enabled
-- @function luax.gui.is_chain_enabled
function M.gui.is_chain_enabled(node)
	local current = node
	while current do
		if not gui.is_enabled(current) then
			return false
		end
		current = gui.get_parent(current)
	end

	return true
end


--- vmath.rad2vec
-- @function luax.vmath.rad2vec
function M.vmath.rad2vec(radians)
	local dir_vector = vmath.vector3()
	dir_vector.x = math.cos(radians)
	dir_vector.y = math.sin(radians)
	return dir_vector
end


--- vmath.vec2rad
-- @function luax.vmath.vec2rad
function M.vmath.vec2rad(vector)
	return math.atan2(vector.y, vector.x)
end


--- vmath.rad2quat
-- @function luax.vmath.rad2quat
function M.vmath.rad2quat(radians)
	return vmath.quat_rotation_z(radians)
end


--- vmath.vec2quat
-- @function luax.vmath.vec2quat
function M.vmath.vec2quat(vector)
	local dir = vmath.normalize(vector)
	dir.z = 0
	return M.vmath.rad2quat(M.vmath.vec2rad(dir))
end


--- vmath.distance
-- @function luax.vmath.distance
function M.vmath.distance(v1, v2)
	return math.sqrt((v2.x - v1.x)^2 + (v2.y - v1.y)^2)
end


--- operators.lt
-- @function luax.operators.lt
function M.operators.lt(x, y)
	return x < y
end


--- operators.le
-- @function luax.operators.le
function M.operators.le(x, y)
	return x <= y
end


--- operators.gt
-- @function luax.operators.gt
function M.operators.gt(x, y)
	return x > y
end


--- operators.ge
-- @function luax.operators.ge
function M.operators.ge(x, y)
	return x >= y
end


--- operators.eq
-- @function luax.operators.eq
function M.operators.eq(x, y)
	return x == y
end


--- operators.neq
-- @function luax.operators.neq
function M.operators.neq(x, y)
	return x ~= y
end


--- Trigger callback and schedule timer on it
-- @function luax.timer.trigger_and_delay
-- @tparam number delay§
-- @tparam function calback
-- @treturn hash The timer id
function M.timer.trigger_and_delay(delay, callback)
	local timer_id = timer.delay(delay, true, callback)
	timer.trigger(timer_id)
	return timer_id
end



return M
