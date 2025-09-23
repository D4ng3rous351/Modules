--!native
--!strict
--[[
	Author: D4ng3rous351
	Created: 2025/05/21
	Updated: 2025/09/06
	
	The purpose of this module is to create efficient object oriented stopwatches that can easily be
	manipulated.
]]

local module = {}

--Variables--
--Folders
local Utility = script.Utility
local Classes = script.Classes

--Utility
local TableUtilities = require(Utility.TableUtilities)

--Classes
local Signals = require(Classes.Signals)


--Types--
export type Stopwatch = {
	Counted: Signals.Signal<()>,
	Active: boolean,
	Increment: number,
	Interval: number,
	Current: number,
	
	Start: (self: Stopwatch) -> (),
	Pause: (self: Stopwatch) -> (),
	Reset: (self: Stopwatch) -> (),
	Destroy: (self: Stopwatch) -> (),
}


--Private--

--Used for increasing stopwatch's count
local function Count(stopwatch: Stopwatch): ()
	if not stopwatch.Active then return end
	task.delay(stopwatch.Interval, Count, stopwatch)
	stopwatch.Current += stopwatch.Increment
	stopwatch.Counted:Fire()
end

--Methods--
local Class: Stopwatch = {} :: Stopwatch

--Starts counting. If stopwatch is paused, it will continue from where it left off.
function Class.Start(self: Stopwatch): ()
	if self.Active then return end
	self.Active = true
	Count(self)
end

--Stops stopwatch from counting
function Class.Pause(self: Stopwatch): ()
	self.Active = false
end

--Resets pauses and sets stopwatch's time to 0.
function Class.Reset(self: Stopwatch): ()
	self.Active = false
	self.Current = 0
end

--Removes instance from memory
function Class.Destroy(self: Stopwatch): ()
	self.Active = false
	self.Counted:Destroy()
	table.clear(self)
end

--Constructor--

--[[
	Creates a new stopwatch.
	<strong>increment:</strong> how much stopwatch will go up by on each tick. Defaults to 1.
	<strong>interval:</strong> amount of time in seconds between each tick. Defaults to 1.
]]
function module.New(increment: number?, interval: number?): Stopwatch
	if increment ~= nil then assert(typeof(increment) == "number", "Argument is not of type number") end
	if interval ~= nil then assert(typeof(interval) == "number", "Argument is not of type number") end
	
	local New: Stopwatch = TableUtilities.DeepCopy(Class)
	New.Counted = Signals.New()
	New.Active = false
	New.Current = 0
	New.Interval = interval or 1
	New.Increment = increment or 1
	
	return New
end

return module
