---@class fun.mathx
local M = {}

--- This function returns the next step that is currently
-- at `current` and should eventually end at `target`. The `step` value
-- is the maximum amount that the animation can move in a single step.
-- Examples:
--   step(0, 100, 10)   -> 10   (moves 10 towards target)
--   step(95, 100, 10)  -> 100  (clamped to target)
--   step(100, 0, 10)   -> 90   (moves -10 towards target)
--   step(5, 0, 10)     -> 0    (clamped to target)
---@param current number Current value
---@param target number Target value
---@param step number Maximum amount that can move in a single step
---@return number The next step
function M.step(current, target, step)
	if current < target then
		return math.min(current + step, target)
	else
		return math.max(target, current - step)
	end
end


--- Returns the sign of the given value.
-- Examples:
--   sign(5)   -> 1
--   sign(-5)  -> -1
--   sign(0)   -> 0
--   sign(0.5) -> 1
--   sign(-0.5) -> -1
---@param value number The value to get the sign of
---@return number -1 if negative, 0 if zero, 1 if positive
function M.sign(value)
	if value > 0 then
		return 1
	elseif value < 0 then
		return -1
	else
		return 0
	end
end


--- This code samples a point on the line between a and b
-- where t is the "interpolation factor" (0 = a, 1 = b)
-- Examples:
--   lerp(0, 100, 0.0)   -> 0    (at point a)
--   lerp(0, 100, 0.5)   -> 50   (halfway between a and b)
--   lerp(0, 100, 1.0)   -> 100  (at point b)
--   lerp(10, 20, 0.3)   -> 13   (30% from 10 to 20)
--   lerp(5, 15, 0.75)   -> 12.5 (75% from 5 to 15)
---@param a number
---@param b number
---@param t number
---@return number
function M.lerp(a, b, t)
	return a + (b - a) * t
end


--- Lerp position to box with size. Smoothly interpolates position towards box boundaries
-- if the position is outside the box. Uses lerp factor to control interpolation speed.
-- Examples:
--   lerp_box(vmath.vector3(50, 50, 0), vmath.vector4(0, 0, 100, 100), 0.1, vmath.vector3(10, 10, 0), false)
--     -> interpolates position towards box boundaries
---@param pos vector3 Current position
---@param box vector4 Box boundaries (x, y, z, w)
---@param lerp number Interpolation factor (0-1)
---@param size vector3|nil Size of the object (optional, defaults to vector3(0))
---@param change_point boolean If true, modifies pos directly; if false, creates new vector
---@return vector3 New interpolated position
function M.lerp_box(pos, box, lerp, size, change_point)
	size = size or vmath.vector3(0)

	local new_point = change_point and pos or vmath.vector3(pos)

	if new_point.x < box.x + size.x/2 then
		new_point.x = M.lerp(new_point.x, box.x + size.x/2, lerp)
	end
	if new_point.x > box.z - size.x/2 then
		new_point.x = M.lerp(new_point.x, box.z - size.x/2, lerp)
	end
	if new_point.y < box.y + size.y/2 then
		new_point.y = M.lerp(new_point.y, box.y + size.y/2, lerp)
	end
	if new_point.y > box.w - size.y/2 then
		new_point.y = M.lerp(new_point.y, box.w - size.y/2, lerp)
	end

	return new_point
end


--- Clamp value between min and max. Returns value if within range, otherwise returns the nearest boundary.
-- If min > max, they are automatically swapped.
-- Examples:
--   clamp(5, 0, 10)   -> 5    (within range)
--   clamp(15, 0, 10)  -> 10   (clamped to max)
--   clamp(-5, 0, 10)  -> 0    (clamped to min)
--   clamp(5, 10, 0)   -> 5    (min/max swapped automatically)
---@param a number Value to clamp
---@param min number Minimum value (will be swapped with max if min > max)
---@param max number Maximum value (will be swapped with min if min > max)
---@return number Clamped value
function M.clamp(a, min, max)
	if min > max then
		min, max = max, min
	end

	if a >= min and a <= max then
		return a
	elseif a < min then
		return min
	else
		return max
	end
end


--- Clamp position to box with size. Keeps position within box boundaries.
-- Examples:
--   clamp_box(vmath.vector3(150, 50, 0), vmath.vector4(0, 0, 100, 100), vmath.vector3(10, 10, 0), false)
--     -> vmath.vector3(95, 50, 0) (x clamped to box boundary)
---@param pos vector3 Current position
---@param box vector4 Box boundaries (x, y, z, w)
---@param size vector3|nil Size of the object (optional, defaults to vector3(0))
---@param change_point boolean If true, modifies pos directly; if false, creates new vector
---@return vector3 Clamped position
function M.clamp_box(pos, box, size, change_point)
	size = size or vmath.vector3(0)

	local new_point = change_point and pos or vmath.vector3(pos)
	new_point.x = M.clamp(new_point.x, box.x + size.x/2, box.z - size.x/2)
	new_point.y = M.clamp(new_point.y, box.y + size.y/2, box.w - size.y/2)

	return new_point
end


--- Round number to specified decimal places.
-- Examples:
--   round(3.14159)         -> 3      (0 decimal places by default)
--   round(3.14159, 2)      -> 3.14   (2 decimal places)
--   round(3.14159, 4)      -> 3.1416 (4 decimal places)
--   round(2.5)             -> 3      (rounds up)
--   round(2.4)             -> 2      (rounds down)
---@param num number Number to round
---@param numDecimalPlaces number|nil Number of decimal places (optional, defaults to 0)
---@return number Rounded number
function M.round(num, numDecimalPlaces)
	local mult = 10 ^ (numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end


--- Check if value equals any of the provided arguments.
-- Examples:
--   is(5, 1, 2, 3, 5)      -> true   (5 is in the list)
--   is(5, 1, 2, 3, 4)      -> false  (5 is not in the list)
--   is("a", "a", "b", "c") -> true   (works with strings too)
---@param value any Value to check
---@param ... any Variable number of values to compare against
---@return boolean True if value equals any of the arguments, false otherwise
function M.is(value, ...)
	for i = 1, select("#", ...) do
		if value == select(i, ...) then
			return true
		end
	end
	return false
end


--- Returns true with given probability (0.0 to 1.0).
-- Examples:
--   chance(0.5)  -> randomly true or false (50% chance)
--   chance(0.0)  -> false (0% chance)
--   chance(1.0)  -> true  (100% chance)
--   chance(0.3)  -> randomly true ~30% of the time
---@param percent number Probability from 0.0 to 1.0
---@return boolean True with given probability, false otherwise
function M.chance(percent)
	return math.random() <= percent
end


--- Calculate Euclidean distance between two points.
-- Examples:
--   distance(0, 0, 3, 4)   -> 5.0    (3-4-5 triangle)
--   distance(0, 0, 0, 0)   -> 0.0    (same point)
--   distance(1, 1, 4, 5)   -> 5.0    (√((4-1)² + (5-1)²) = 5)
---@param x1 number X coordinate of first point
---@param y1 number Y coordinate of first point
---@param x2 number X coordinate of second point
---@param y2 number Y coordinate of second point
---@return number Euclidean distance between the two points
function M.distance(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end


--- Calculate squared distance between two points (faster than distance as it avoids sqrt).
-- Useful for distance comparisons when you don't need the actual distance value.
-- Examples:
--   distance_check(0, 0, 3, 4)   -> 25    (squared distance, 5²)
--   distance_check(0, 0, 0, 0)   -> 0     (same point)
--   distance_check(1, 1, 4, 5)   -> 25    (squared distance)
---@param x1 number X coordinate of first point
---@param y1 number Y coordinate of first point
---@param x2 number X coordinate of second point
---@param y2 number Y coordinate of second point
---@return number Squared Euclidean distance between the two points
function M.distance_check(x1, y1, x2, y2)
	return (x2 - x1)^2 + (y2 - y1)^2
end


--- Calculate Manhattan distance (taxicab distance) between two points.
-- Manhattan distance is the sum of absolute differences in coordinates.
-- Examples:
--   manhattan(0, 0, 3, 4)   -> 7     (|3-0| + |4-0| = 7)
--   manhattan(1, 1, 4, 5)   -> 7     (|4-1| + |5-1| = 7)
--   manhattan(0, 0, 0, 0)   -> 0     (same point)
---@param x1 number X coordinate of first point
---@param y1 number Y coordinate of first point
---@param x2 number X coordinate of second point
---@param y2 number Y coordinate of second point
---@return number Manhattan distance between the two points
function M.manhattan(x1, y1, x2, y2)
	return math.abs(x2 - x1) + math.abs(y2 - y1)
end


--- Convert 2D vector (x, y) to angle in radians using atan2.
-- Returns angle in radians from positive x-axis.
-- Examples:
--   vec2rad(1, 0)   -> 0         (pointing right)
--   vec2rad(0, 1)   -> π/2       (pointing up)
--   vec2rad(-1, 0)  -> π         (pointing left)
--   vec2rad(0, -1)  -> -π/2      (pointing down)
--   vec2rad(1, 1)   -> π/4       (45 degrees)
---@param x number X component of the vector
---@param y number Y component of the vector
---@return number Angle in radians (-π to π)
function M.vec2rad(x, y)
	return math.atan2(y, x)
end


--- Returns random sign: either 1 or -1 (50% chance each).
-- Examples:
--   random_sign()  -> 1 or -1 (randomly)
---@return number Either 1 or -1
function M.random_sign()
	return math.random() >= 0.5 and 1 or -1
end


--- Generate random number in range [from, to).
-- Examples:
--   random(0, 10)    -> random number between 0 (inclusive) and 10 (exclusive)
--   random(5, 15)    -> random number between 5 (inclusive) and 15 (exclusive)
--   random(-1, 1)    -> random number between -1 (inclusive) and 1 (exclusive)
---@param from number Minimum value (inclusive)
---@param to number Maximum value (exclusive)
---@return number Random number in range [from, to)
function M.random(from, to)
	return math.random() * (to - from) + from
end


--- Get the absolute difference between two numbers (always positive).
-- Examples:
--   diff(5, 3)   -> 2
--   diff(3, 5)   -> 2    (same result regardless of order)
--   diff(10, 10) -> 0
--   diff(-5, 3)  -> 8    (absolute difference)
---@param number1 number First number
---@param number2 number Second number
---@return number Absolute difference between the two numbers
function M.diff(number1, number2)
	if number1 > number2 then
		return number1 - number2
	end
	return number2 - number1
end

return M