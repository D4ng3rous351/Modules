--!strict
--!native
--[[
	Author: D4ng3rous351
	Created: 2025/03/25
	Updated: 2025/09/06
	
	The purpose of this module is to create object oriented timers that are easy to change and manipulate.
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
export type Timer = {
	Started: Signals.Signal<()>,
	Ended: Signals.Signal<()>,
	Counted: Signals.Signal<()>,
	Active: boolean,
	Remaining: number,
	Interval: number,
	Decrement: number,
	
	Start: (self: Timer) -> (),
	Stop: (self: Timer) -> (),
	Destroy: (self: Timer) -> (),
}


--Private--

--Used for counting down timer and firing counted event
local function Countdown(timer: Timer): ()
	if not timer.Active then return end
	task.delay(timer.Interval, Countdown, timer)
	timer.Remaining -= timer.Decrement
	timer.Counted:Fire()
	if timer.Remaining <= 0 then	
		timer.Active = false
		timer.Ended:Fire()
	end
end

--Methods--
local Timer: Timer = {} :: Timer

--Starts counting down
function Timer.Start(self: Timer): ()
	self.Active = true
	Countdown(self)
end

--Stops timer and kills threads
function Timer.Stop(self: Timer): ()
	self.Active = false
end

--Stops counting down and destroys timer and all signals.
function Timer.Destroy(self: Timer): ()
	self.Active = false
	self.Counted:Destroy()
	self.Started:Destroy()
	self.Ended:Destroy()
	table.clear(self)
end

--Constructor--
--[[
	Creates a new Timer object with specified duration.
	<strong>duration:</strong> length of timer in seconds.
	<strong>decrement:</strong> determines how much timer's time will go down by each step. Defaults to 1.
	<strong>interval:</strong> time between each decrement. Defaults to 1.
]]
function module.New(duration: number, decrement: number?, interval: number?): Timer
	assert(typeof(duration) == "number", "Argument is not of type number")
	if decrement ~= nil then assert(typeof(decrement) == "number", "Argument is not of type number") end
	if interval ~= nil then assert(typeof(interval) == "number", "Argument is not of type number") end
	
	local NewTimer: Timer = TableUtilities.DeepCopy(Timer)
	NewTimer.Started = Signals.New()
	NewTimer.Ended = Signals.New()
	NewTimer.Counted = Signals.New()
	NewTimer.Decrement = decrement or 1
	NewTimer.Interval = interval  or 1
	NewTimer.Active = false
	NewTimer.Remaining = duration
	
	return NewTimer
end

return module
