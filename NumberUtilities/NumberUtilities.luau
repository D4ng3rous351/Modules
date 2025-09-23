--!strict
--!native
--[[
	Author: D4ng3rous351
	Created: 2025/06/13
	Updated: 2025/08/02
	
	The purpose of this module is to provide useful utilities for manipulating numbers.
]]

local module = {}

--Public--

--[[
	Rounds number to provided precision.
	<strong>num:</strong> number to round.
	<strong>precision:</strong> amount of digits to round number to.
]]
function module.Round(num: number, precision: number): number
	assert(typeof(num) == "number" and num == num, "Argument is not of type number")
	assert(typeof(precision) == "number" and precision == precision, "Argument is not of type number")
	
	local Multiplier: number = 10^precision
	local Rounded: number = ((num * Multiplier) // 1) / Multiplier
	
	return Rounded
end

--[[
	Returns the approximate amount of decimals a number has.
	<strong>num:</strong> number to count decimals of.
	NOTE: Function may be inaccurate with big numbers/decimals.
]]
function module.CountDecimals(num: number): number
	assert(typeof(num) == "number" and num == num, "Argument is not of type number")
	
	num -= num // 1
	
	local StringNumber: string = tostring(num)
	if not string.find(StringNumber, ".") then return 0 end
	local Decimal: string = string.sub(StringNumber, 3, string.len(StringNumber))
	
	return string.len(Decimal)
end

--[[
	Returns the size of a number in bytes.
	<strong>num:</strong> number to get size of.
	NOTE: Does not support any floating point types other than f32.
]]
function module.GetNumberSize(num: number): number
	assert(typeof(num) == "number" and num == num, "Argument is not of type number")
	
	if num % 1 ~= 0 then return 4 end
	
	local Size: number = 8
	local PositiveLimit: number = (2^Size) - 1
	local NegativeLimit: number = -((2^Size) / 2)
	while num > PositiveLimit or num < NegativeLimit do
		Size *= 2
		PositiveLimit = (2^Size) - 1
		NegativeLimit = -((2^Size) / 2)
	end
	return Size // 8
end

--[[
	Returns the median in a table of numbers.
	<strong>nums:</strong> table of numbers to get median of.
	<strong>copy:</strong> whether or not the table should be copied before sorting. Defaults to false. 
]]
function module.Median(nums: {number}, copy: boolean?): number?
	assert(typeof(nums) == "table", "Argument is not of type table")
	if copy ~= nil then assert(typeof(copy) == "boolean", "Argument is not of type boolean") end
	
	local Length: number = #nums
	
	if Length == 0 then
		return nil
	elseif Length == 1 then
		return nums[table.maxn(nums)]
	end
	
	local Data: {number} = if copy then table.clone(nums) else nums
	table.sort(Data)
	
	local Center: number = Length // 2
	local Median: number
	
	if Length % 1 == 0 then
		Median = (nums[Center] + nums[Center + 1]) / 2
	else
		Median = nums[Center]
	end
	
	return Median
end
  
--[[
	Returns sum of numbers in a table.
	<strong>nums:</strong> table to get sum of.
]]
function module.Sum(nums: {number}): number
	local Sum: number = 0
	
	for i: number = 1, #nums do
		Sum += nums[i]
	end
	
	return Sum
end
  
--[[
	Returns the average in a table of numbers.
	<strong>nums:</strong> table of numbers to get average of.
]]
function module.Average(nums: {number}): number?
	assert(typeof(nums) == "table", "Argument is not of type table")
	
	local Length: number = #nums
	
	if Length == 0 then
		return nil
	elseif Length == 1 then
		return nums[table.maxn(nums)]
	end
	
	local Sum: number = module.Sum(nums)
	
	return Sum / Length
end
  
return module
