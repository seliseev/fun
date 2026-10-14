
---@class fun.tablex
local M ={}

M.empty = {}


--- Очищает таблицу
---@param array table
function M.clear(array)
	for index = #array, 1, -1 do
		array[index] = nil
	end
end


--- table.get_item_from_array
-- @function luax.get_item_from_array
function M.get_item_from_array(array, key, value)
	for i = 1, #array do
		if array[i][key] == value then
			return array[i]
		end
	end

	return nil
end

function M.get_values_by_key(array_of_dict, key)
	local result = {}
	for i = 1, #array_of_dict do
		if array_of_dict[i][key] then
			table.insert(result, array_of_dict[i][key])
		end
	end
	return result
end


--- Checks if the table contains the value
---@param t table The table to search in
---@param value any The value to search for
---@return integer|boolean @index of element or false if element not found
function M.contains(t, value)
	for i = 1, #t do
		if t[i] == value then
			return i
		end
	end
	return false
end


--- Возвращает длину таблицы
---@param array table
---@return integer
function M.length(array)
	local length = 0
	for _ in pairs(array) do
		length = length + 1
	end
	return length
end


--- Находит и удаляет элемент из таблицы
---@param t table The table to remove the item from
---@param value any The value to remove
---@return boolean @true if the item was removed, false if the item was not found
function M.remove_item(t, value)
	local index = M.contains(t, value)
	if index then
        ---@cast index integer
		table.remove(t, index)
		return true
	end

	return false
end


--- Removes the item from the table by the dictionary
---@param t table The table to remove the item from
---@param example table The example to remove the item from
---@return boolean @true if the item was removed, false if the item was not found
function M.remove_by_dict(t, example)
	local index = -1

	for i = 1, #t do
		local v = t[i]

		local is_match = true
		for key, val in pairs(example) do
			if v[key] ~= val then
				is_match = false
			end
		end

		if is_match then
			index = i
			break
		end
	end

	if index ~= -1 then
		table.remove(t, index)
		return true
	end

	return false
end


--- Проверяет является ли таблица пустой
---@param t table
---@return boolean
function M.is_empty(t)
	if not t then
		return true
	end
	return next(t) == nil
end

--- Excludes the items from the table
---@param t1 table The table to exclude the items from
---@param t2 table The table with the items to exclude
---@return table @t1 with the excluded items
function M.exclude(t1, t2)
	for k, v in pairs(t2) do
		M.remove_item(t1, t2[k])
	end
	return t1
end

--- 
---@param t1 table
---@param t2 table
---@return any
function M.extend(t1, t2)
	if not t2 then
		return t1
	end

	for k, v in pairs(t2) do
		t1[k] = v
	end

	return t1
end

--- Расширяет таблицу t1 значениями из таблицы t2. Нет проверки на уникальность!
---@param t1 any[]
---@param t2 any[]
---@return any
function M.extend_array(t1, t2)
	if not t2 then
		return t1
	end

	for i, v in ipairs(t2) do
		table.insert(t1, v)
	end
	return t1
end

--- Merge two tables. If is_unique is true, the values will not be duplicated.
---@param t1 table
---@param t2 table
---@param is_unique boolean
function M.add(t1, t2, is_unique)
	for i = 1, #t2 do
		if is_unique then
			M.insert_unique(t1, t2[i])
		else
			table.insert(t1, t2[i])
		end
	end
end


--- Insert unique value to table
---@param t table
---@param value any
function M.insert_unique(t, value)
	if not M.contains(t, value) then
		table.insert(t, value)
	end
end


--- Returns a random item from the table
---@param t table
---@return any
function M.random(t)
	return t[math.random(#t)]
end


--- table.weight_random
-- @function luax.weight_random
function M.weight_random(chances, values)
	if values then
		assert(#values == #chances, "arrays should be with equals length")
	end

	local w = 0
	for i = 1, #chances do
		w = w + chances[i]
	end
	w = w * math.random()

	for i = 1, #chances do
		w = w - chances[i]
		if w <= 0 then
			if values then
				return values[i]
			else
				return i
			end
		end
	end

	if values then
		return values[#values]
	else
		return #chances
	end
end


--- Shuffle table
---@param t table
---@param seed number|nil
---@return table
function M.shuffle(t, seed)
	if seed then
		math.randomseed(seed)
	end
	for _ = 1, 2 do
		for i = #t, 1, -1 do
			local j = math.random(i)
			t[i], t[j] = t[j], t[i]
		end
	end
	return t
end

function M.values(t)
	local values = {}
    for _, value in pairs(t) do
        table.insert(values, value)
    end
    return values
end

function M.keys(t)
	local keys = {}
	for key, _ in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

--- Копирует массив
---@param orig table
---@return table
function M.copy_array(orig)
	local result = {}

	for i = 1, #orig do
		table.insert(result, orig[i])
	end

	return result
end

--- Копирует таблицу, включая вложенные таблицы
---@param orig table
---@return table
function M.deepcopy(orig)
	local copy
	if type(orig) == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
		end
		setmetatable(copy, M.deepcopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end


--- table.override
---@param source table
---@param target table
function M.override(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" and target[key] then
			M.override(value, target[key])
		else
			target[key] = value
		end
	end
	return target
end


--- Returns a list of keys or values from the table
---@param t table
---@param field string|nil
---@return table # list of keys or values from the table
function M.list(t, field)
	local result = {}

	for key, value in pairs(t) do
		if field then
			table.insert(result, value[field])
		else
			table.insert(result, key)
		end
	end

	return result
end

---Удаляет из списка элементы, удовлетворяющие условию
---@param t table
---@param condition function
function M.remove_if(t, condition)
	local i = 1
	while i <= #t do
		if condition(t[i]) then
			table.remove(t, i)
		else
			i = i + 1
		end
	end
end


--- Возвращает количество элементов, удовлетворяющих условию
---@param t table
---@param condition function
---@return integer
function M.count_if(t, condition)
	local count = 0
	for i = 1, #t do
		if condition(t[i]) then
			count = count + 1
		end
	end
	return count
end


---Возвращает массив элементов, удовлетворяющих условию
---@param t table
---@param condition function
---@return table
function M.get_if(t, condition)
	local result = {}
	for i = 1, #t do
		if condition(t[i]) then
			table.insert(result, t[i])
		end
	end
	return result
end

--- table.tostring
-- @function luax.tostring
function M.tostring(t)
	local result = ""

	if t and M.length(t) ~= 0 then
		for k, v in pairs(t) do
			if type(v) == "table" then
				v = M.tostring(v)
			end
			if type(v) == "boolean" then
				v = tostring(v)
			end
			result = string.format("%s = %s %s", k, v, result)
		end
		result = string.format("{ %s}", result)
	end

	return result
end

--- Применяет функцию к каждому элементу таблицы и возвращает новую таблицу
---@param t table
---@param map_func function(value, index)
---@return table
function M.map(t, map_func)
	local result = {}
	for key, value in pairs(t) do
		result[key] = map_func(value, key)
	end
	return result
end

--- Разбивает таблицу на чанки
---@param t table Массив для разбивки
---@param size integer Размер чанка
---@return table<table> Массив чанков
function M.chunk(t, size)
	assert(type(t) == "table", "t must be a table")
	assert(type(size) == "number" and size > 0, "size must be a positive number")

	local result = {}
	local current_chunk = {}

	for i = 1, #t do
		table.insert(current_chunk, t[i])
		if #current_chunk == size then
			table.insert(result, current_chunk)
			current_chunk = {}
		end
	end

	if #current_chunk > 0 then
		table.insert(result, current_chunk)
	end

	return result
end


--- Проверяет, что две таблицы имеют одинаковую структуру
--- (одинаковое количество ключей и одинаковые типы значений)
--- Значения могут быть разными
---@param t_correct table Первая таблица (обычно дефолтный конфиг)
---@param t_to_compare table Вторая таблица (обычно загруженный конфиг)
---@return boolean is_equal, string|nil error_msg @true если структуры совпадают, error_msg если структуры не совпадают содержит текст в чем отличие
function M.is_equal(t_correct, t_to_compare)
	-- Если это одна и та же таблица, они равны
	if t_correct == t_to_compare then
		return true
	end

	-- Если одна из таблиц nil, они не равны
	if t_correct == nil or t_to_compare == nil then
		return false, "One of the tables is nil, t_correct: " .. tostring(t_correct) .. ", t_to_compare: " .. tostring(t_to_compare)
	end

	-- Проверяем каждый ключ из t1
	for key, value1 in pairs(t_correct) do
		local value2 = t_to_compare[key]
		
		-- Если ключа нет в t2, структуры не совпадают
		if value2 == nil then
			return false, "Key not found in t_to_compare, key: " .. key
		end
		
		-- Получаем типы значений
		local type1 = type(value1)
		local type2 = type(value2)
		
		-- Проверяем, что типы совпадают
		if type1 ~= type2 then
			return false, "Types are not equal, type1: " .. type1 .. ", type2: " .. type2
		end
		
		-- Если значение - таблица, рекурсивно проверяем её структуру
		if type1 == "table" then
			local is_equal, error_msg = M.is_equal(value1, value2)
			if not is_equal then
				return false, "Table '" .. key .. "' is not equal, error_msg: " .. error_msg
			end
		end
	end
	
	return true
end

return M