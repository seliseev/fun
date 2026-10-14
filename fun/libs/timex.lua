
local M = {}

--- Returns the time in seconds, relative to the system epoch (Unix epoch time since January 1, 1970 (UTC) or Windows file time since January 1, 1601 (UTC)). You should use the values returned by this function for relative measurements only.
--- @return number @the number of seconds elapsed.
function M.get_time()
	return socket.gettime()
end


--- Get time in seconds at the start of the current day
---@param timestamp number|nil The timestamp in seconds, if nil - get current time
---@return number @Time in seconds at the start of the current day
function M.get_time_start_of_day(timestamp)
	local time = timestamp or M.get_time()
	local current_date = os.date("*t", time)  --[[@as osdate]]
	current_date.hour = 0
	current_date.min = 0
	current_date.sec = 0
	return os.time(current_date)
end

--- Get date in format: YYYYMMDD
---@return number|nil @Current day in format YYYYMMDD
function M.get_date_code(timestamp)
	timestamp = timestamp or M.get_time()
	date = os.date("*t", timestamp)
	return date.year * 10000 + date.month * 100 + date.day
end


--- Get time in ISO format from seconds
--- @param seconds number The time in seconds to convert in ISO format
--- @param in_gmt boolean|nil If true, return time in GMT format
--- @return string time in ISO format
function M.get_ISO(seconds, in_gmt)
	local time = seconds

	if in_gmt then
		time = seconds - M.get_timezone_offset(seconds)
	end

	return os.date("%Y-%m-%dT%TZ", time)    --[[@as string]]
end


--- Add days to time
--- @param seconds number The time in seconds
--- @param days number The number of days to add
--- @return number The time in seconds
function M.add_days(seconds, days)
    local date = os.date("*t", seconds)     --[[@as osdate]]
    date.day = date.day + days
    return os.time(date)
end


---Calculate days from seconds
---@param seconds number The time in seconds
---@return integer @Days
function M.convert_to_days(seconds)
	return math.floor(seconds / 86400) -- 86400 seconds is 24h
end

--- Calculate time in seconds until target time
---@param target_time number The target time in seconds
---@return integer @Seconds until target time in seconds
function M.get_seconds_until_target_time(target_time)
	local time = M.get_time()
	return target_time - time
end


--- Get seconds until next day
--- @return integer @Seconds until next day
function M.get_seconds_until_new_day()
	local time = M.get_time()
	local current_date = os.date("*t", time)  --[[@as osdate]]

	local next_date = os.date("*t", time + (60 * 60 * 24))  --[[@as osdate]]
	next_date.hour = 0
	next_date.min = 0
	next_date.sec = 0

	return os.difftime(os.time(next_date), os.time(current_date))
end

--- Return timezone offset from local time to GMT for timestamp
--- @param ts number The timestamp in seconds
function M.get_timezone_offset(ts)
	local utcdate   = os.date("!*t", ts)   --[[@as osdate]]
	local localdate = os.date("*t", ts)    --[[@as osdate]]
	localdate.isdst = false -- this is the trick
	return os.difftime(os.time(localdate), os.time(utcdate))
end

--- Check if two timestamps are on the same day
---@param timestamp1 number The first timestamp in seconds
---@param timestamp2 number The second timestamp in seconds
---@return boolean
function M.is_same_day(timestamp1, timestamp2)
	return math.floor(timestamp1 / 86400) == math.floor(timestamp2 / 86400)
end


--- Check if cooldown reached
---@param last_time number The time of the last action
---@param cooldown number The cooldown in seconds
---@return boolean @True if cooldown reached, false otherwise
function M.is_cooldown_reached(last_time, cooldown)
    if last_time + cooldown >= M.get_time() then
        return false
    end
    return true
end

return M