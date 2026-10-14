--- Time string module. Carry ISO format and custom delta format
-- ISO format:
-- format: yyyy-mm-ddThh:mm:ss.ffffff
-- example: 2008-09-15T15:53:00
-- 			2008-09-15T15:53:00+05:00
-- Delta format:
-- format: 1Y 10M 2W 1D 12h 30m
-- example: 1Y, 1h 30m, 10D

local M = {}


local function parse_date(str)
	local Y, MM, D = str:match("^(%d%d%d%d)-?(%d%d)-?(%d%d)")
	return tonumber(Y), tonumber(MM), tonumber(D)
end


local function parse_time(str)
	local h, m, s = str:match("T(%d%d):?(%d%d):?(%d%d)")
	return tonumber(h) or 0, tonumber(m) or 0, tonumber(s) or 0
end


local function parse_offset(str)
	if str:sub(-1)=="Z" then return 0,0 end -- ends with Z, Zulu time

	-- matches ±hh:mm, ±hhmm or ±hh; else returns nils
	local sign, oh, om = str:match("([-+])(%d%d):?(%d?%d?)$")
	sign, oh, om = sign or "+", oh or "00", om or "00"

	return tonumber(sign .. oh) or 0, tonumber(sign .. om) or 0
end


--- Get the table with delta times
--- @param str string In format: "1Y 10M 2W 1D 12h 30m". Can pass part of time
local function get_delta_time(str)
	local year = tonumber(str:match("(%d?)Y")) or 0
	local month = tonumber(str:match("(%d?%d?)M")) or 0
	local week = tonumber(str:match("(%d?)W")) or 0
	local day = tonumber(str:match("(%d?%d?)D")) or 0
	local hour = tonumber(str:match("(%d?%d?)h")) or 0
	local min = tonumber(str:match("(%d?%d?)m")) or 0

	return {
		year = year,
		month = month,
		day = week*7 + day,
		hour = hour,
		min = min
	}
end


--- Get seconds from ISO string time format
--- @param str string time in ISO format in GMT time
--- @param in_gmt boolean If true, return time in GMT format
function M.parse_ISO(str, in_gmt)
	local Y, MM, D = parse_date(str)
	local h, m, s = parse_time(str)
	local oh, om = parse_offset(str)
	local time = os.time({ year=Y, month=MM, day=D, hour=(h+oh), min=(m+om), sec=s })

	if in_gmt then
		time = time + M.get_timezone_offset(time)
	end

	return time
end


--- Get time in ISO format from seconds
--- @param seconds number seconds The time in seconds to convert in ISO format
--- @param in_gmt boolean|nil If true, return time in GMT format
--- @return string time in ISO format
function M.get_ISO(seconds, in_gmt)
	local time = seconds

	if in_gmt then
		time = seconds - M.get_timezone_offset(seconds)
	end

	return os.date("%Y-%m-%dT%TZ", time)
end

function M.get_days(seconds)
	return math.floor(seconds / 86400)
end

function M.get_hours(seconds)
	return math.floor(seconds / 3600)
end


--- Get time string in format: "1d 12h"
--- @param seconds number seconds
--- @return string time string
function M.get_d_h_string(seconds)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	return string.format("%dd %dh", days, hours)
end


--- Get time string in format: "12h 30m"
--- @param seconds number seconds
--- @return string time string
function M.get_h_m_string(seconds)
	assert(math.floor(seconds / 86400) == 0, "seconds must be less than 86400 (1 day)")
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dh %dm", hours, minutes)
end

--- Get time string in format: "12:30"
--- @param seconds number seconds. Must be less than 3600
--- @return string time string
function M.get_m_s_string(seconds)
	assert(M.get_hours(seconds) == 0, "seconds must be less than 3600 (1 hour)")
	local minutes = math.floor(seconds / 60)
	local seconds = seconds % 60
	return string.format("%d:%02d", minutes, seconds)
end

--- Get smart time string in format: "1d 12h" or "12h 30m" or "12:30"
--- @param seconds number seconds
--- @return string time string
function M.get_smart_time_string(seconds)
	if M.get_days(seconds) > 0 then
		return M.get_d_h_string(seconds)
	elseif M.get_hours(seconds) > 0 then
		return M.get_h_m_string(seconds)
	else
		return M.get_m_s_string(seconds)
	end
end


--- Return next time in seconds on event
--- @param start_time number date in seconds
--- @param delta_time string delta in next format: "1Y 10M 2W 1D 12h 30m". Can pass part of time
--- @param cur_time number|nil date in seconds. local time by default
function M.get_next_time(start_time, delta_time, cur_time)
	cur_time = cur_time or socket.gettime()

	local cur_table = os.date("*t", start_time)
	local time = os.time(cur_table)
	local delta = get_delta_time(delta_time)

	while time < cur_time do
		cur_table.year = cur_table.year + delta.year
		cur_table.month = cur_table.month + delta.month
		cur_table.day = cur_table.day + delta.day
		cur_table.hour = cur_table.hour + delta.hour
		cur_table.min = cur_table.min + delta.min
		time = os.time(cur_table)
	end

	return time
end


--- Convert Delta string format to seconds
function M.get_delta_seconds(delta_str)
	local time_table = get_delta_time(delta_str)
	local seconds = 0
	seconds = seconds + time_table.min * 60
	seconds = seconds + time_table.hour * 60 * 60
	seconds = seconds + time_table.day * 60 * 60 * 24
	seconds = seconds + time_table.month * 60 * 60 * 24 * 30
	seconds = seconds + time_table.year * 60 * 60 * 24 * 365
	return seconds
end


--- Return timezone offset from local time to GMT for timestamp
--- @param ts number The timestamp in seconds
function M.get_timezone_offset(ts)
	local utcdate   = os.date("!*t", ts)
	local localdate = os.date("*t", ts)
	localdate.isdst = false -- this is the trick
	return os.difftime(os.time(localdate), os.time(utcdate))
end


return M
