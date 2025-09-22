--!strict
--!native
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/04/05
	Updated: 2025/09/13
	
	The purpose of this module is to provide utility functions for managing and controlling user
	interface objects.
]]

local module = {}

--Services--
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")


--Variables--
local Player = Players.LocalPlayer
local PlayerGUI = Player.PlayerGui
local Camera = workspace.CurrentCamera

--Folders
local Utility = script.Utility

--Utility
local TableUtilities = require(Utility.TableUtilities)

--Types--
type Typewritable = TextLabel | TextButton | TextBox
type PositionOptions = "l" | "r" | "c" | "t" | "b"
type ScaleOrOffset = "s" | "o"
type PositionFunc = (GuiObject, GuiObject) -> boolean
type CenterFunc = (GuiObject, GuiObject, Vector2) -> boolean


--Private--

--Returns whether 2 UIs overlap or not.
local function __Overlaps(a: GuiObject, b: GuiObject): boolean
	local Bounds1: Rect = module.GetBounds(a)
	local Min1: Vector2 = Bounds1.Min
	local Max1: Vector2 = Bounds1.Max
  
	local Bounds2: Rect = module.GetBounds(b)
	local Min2: Vector2 = Bounds2.Min
	local Max2: Vector2 = Bounds2.Max
  
	local OverlapsX: boolean = ((Min1.X >= Min2.X) and (Min1.X <= Max2.X)) or ((Min1.X <= Min2.X) and (Max1.X >= Min2.X))
	local OverlapsY: boolean = ((Min1.Y >= Min2.Y) and (Min1.Y <= Max2.Y)) or ((Min1.Y <= Min2.Y) and (Max1.Y >= Min2.Y))
  
	return OverlapsX and OverlapsY
end

--Filter function for top most positioned UI
local function __Top(a: GuiObject, b: GuiObject): boolean
	return a.AbsolutePosition.Y < b.AbsolutePosition.Y
end

--Filter function for bottom most positioned UI
local function __Bottom(a: GuiObject, b: GuiObject): boolean
	return a.AbsolutePosition.Y > b.AbsolutePosition.Y
end

--Filter function for left most positioned UI
local function __Left(a: GuiObject, b: GuiObject): boolean
	return a.AbsolutePosition.X > b.AbsolutePosition.X
end

--Filter function for right most positioned UI
local function __Right(a: GuiObject, b: GuiObject): boolean
	return a.AbsolutePosition.X < b.AbsolutePosition.X
end

--Filter function for center most positioned UI
local function __Center(a: GuiObject, b: GuiObject, center: Vector2): boolean
	local ADistance: number = (a.AbsolutePosition - center).Magnitude
	local BDistance: number = (b.AbsolutePosition - center).Magnitude
	return BDistance < ADistance
end

--Public--

--[[
	Returns UI object from an array that is positioned to the left/right/center/top/bottom the most.
	<strong>ui:</strong> array of UIs to compare.
	<strong>option:</strong> which position to compare.
	<strong>parent:</strong> optional parent size. Defaults to viewport size if unspecified.
	NOTE: Uses absolute position, not anchorpoints.
]]
function module.GetFurthestPositioned(ui: {GuiObject}, option: PositionOptions, parent: Vector2?): GuiObject
	assert(typeof(ui) == "table", "Argument is not of type table")
	assert(#ui > 0, "Table is empty")
	assert(option == "l" or option == "r" or option == "t" or option == "b" or option == "c", "Invalid position specifier")
	if parent ~= nil then assert(typeof(parent) == "Vector2", "Argument is not of type Vector2") end
	
	local FilterFunc: PositionFunc | CenterFunc
	
	if option == "t" then
		FilterFunc = __Top
	elseif option == "b" then
		FilterFunc = __Bottom
	elseif option == "c" then
		FilterFunc = __Center
	elseif option == "l" then
		FilterFunc = __Left
	else
		FilterFunc = __Right
	end
	
	local _: number, UI: GuiObject
	
	if option == "c" then
		local Center: Vector2 = if parent then parent / 2 else Camera.ViewportSize / 2
		_, UI = TableUtilities.Filter(ui, FilterFunc :: CenterFunc, Center)
	else
		_, UI = TableUtilities.Filter(ui, FilterFunc :: PositionFunc)
	end
	
	return UI
end
  
--[[
	Returns the bounds of the UI as a Rect value.
	<strong>ui:</strong> UI to get bounds of.
]]
function module.GetBounds(ui: GuiObject): Rect
	if typeof(ui) ~= "Instance" then error("Argument is not of type GuiObject") end
	assert(ui:IsA("GuiObject"), "Argument is not of type GuiObject")
	return Rect.new(ui.AbsolutePosition, ui.AbsolutePosition + ui.AbsoluteSize)
end
  
--[[
	Returns whether the all UI in the table overlap each other.
	<strong>uis:</strong> UIs to check.
]]
function module.Overlaps(uis: {GuiObject}): boolean
	local Length: number = #uis
	
	assert(Length > 0, "Table is empty")
	
	local Current: GuiObject
	
	for i: number = 1, Length - 1 do
		Current = uis[i]
		
		for k: number = i + 1, Length do
			if not __Overlaps(Current, uis[k]) then return false end
		end
	end
	
	return true
end

--[[
	Converts X and Y from scale to offset.
	<strong>x:</strong> X value to convert.
	<strong>y:</strong> Y value to convert.
	<strong>parent:</strong> optional parent size. Defaults to viewport size if unspecified.
]]
function module.ScaleToOffset(x: number, y: number, parent: Vector2?): UDim2
	assert(typeof(x) == "number" and typeof(y) == "number", "Argument is not of type number")
	if parent ~= nil then assert(typeof(parent) ==  "Vector2", "Argument is not of type Vector2") end
	
	local ParentSize: Vector2 = parent or Camera.ViewportSize
	local Offset: UDim2 = UDim2.fromOffset(x * ParentSize.X, y * ParentSize.Y)
	
	return Offset
end

--[[
	Converts X and Y from offset to scale.
	<strong>x:</strong> X value to convert.
	<strong>y:</strong> Y value to convert.
	<strong>parent:</strong> optional parent size. Defaults to viewport size if unspecified.
]]
function module.OffsetToScale(x: number, y: number, parent: Vector2?): UDim2
	assert(typeof(x) == "number" and typeof(y) == "number", "Argument is not of type number")
	if parent ~= nil then assert(typeof(parent) ==  "Vector2", "Argument is not of type Vector2") end
	
	local ParentSize: Vector2 = parent or Camera.ViewportSize
	local Scale: UDim2 = UDim2.fromScale(x / ParentSize.X, y / ParentSize.Y)
	
	return Scale
end
  
--[[
	Returns text that the local player has selected from the text box, if any.
	<strong>textbox:</strong> text box to get text from.
	NOTE: Returns empty string ("") if no text is selected.
]]
function module.GetSelectedText(textbox: TextBox): string
	assert(typeof(textbox) == "Instance", "Argument is not of type TextBox")
	assert(textbox.ClassName == "TextBox", "Argument is not of type TextBox")
	
	local SelectionStart: number = textbox.SelectionStart
	local CursorPosition: number = textbox.CursorPosition
	
	--Returns nil if no text is selected
	if SelectionStart == -1 then return "" end
	
	local CurrentText: string = textbox.Text
	local SelectedText: string = string.sub(CurrentText, SelectionStart, CursorPosition - 1)	
	local BackwardsSelectedText: string = string.sub(CurrentText, CursorPosition, SelectionStart - 1)
	
	if SelectedText ~= "" then return SelectedText end
	if BackwardsSelectedText ~= "" then return BackwardsSelectedText end
	
	return ""
end
  
--[[
	Writes to a UI element that contains text as if it is being done by a typewriter.
	<strong>ui:</strong> UI element to typewrite to.
	<strong>text:</strong> text to write.
	<strong>interval:</strong> delay between each letter.
	NOTE: Does not support HTML formatting.
]]
function module.Typewrite(ui: Typewritable, text: string, interval: number): ()
	assert(typeof(ui) == "Instance", "Argument is not of type Instance")
	assert(ui.ClassName == "TextLabel" or ui.ClassName == "TextButton" or ui.ClassName == "TextBox", "Instance is not typewritable")
	
	local Text: string = ui.Text
	
	for i: number = 1, #text do
		(ui :: any).Text = `{Text}{string.sub(text, 1, i)}`
		task.wait(interval)
	end
end
  
--[[
	Returns position of UI with anchorpoints set to new position without moving the UI element.
	<strong>ui:</strong> UI to get new position of.
	<strong>new:</strong> new anchorpoints that will be used for UI.
	<strong>option:</strong> whether to use scale or offset for position.
]]
function module.GetAnchorpointChangedPosition(ui: GuiObject, new: Vector2, option: ScaleOrOffset): UDim2
	assert(typeof(ui) == "Instance", "Argument is not of type GuiObject")
	assert(ui:IsA("GuiObject"), "Argument is not of type GuiObject")
	assert(ui.Parent, "UI has no parent")
	assert(ui.Parent:IsA("GuiBase2d"), "UI parent must be a GuiBase2d")
	assert(typeof(new) == "Vector2", "Argument is not of type Vector2")
	assert(option == "s" or option == "o", "Invalid position specifier")
	
	local AbsPosition: Vector2 = ui.AbsolutePosition
	local Anchorpoint: Vector2 = ui.AnchorPoint
	local AbsSize: Vector2 = ui.AbsoluteSize
	
	local OriginalPosition: Vector2 = AbsPosition + (Anchorpoint * AbsSize)
	local NewPosition: Vector2 = AbsPosition + (new * AbsSize)
	local Difference: Vector2 = OriginalPosition + (NewPosition - OriginalPosition) - ui.Parent.AbsolutePosition
	
	local NewPosition: UDim2
	
	if option == "o" then
		NewPosition = UDim2.fromOffset(Difference.X, Difference.Y)
	elseif option == "s" then
		NewPosition = module.OffsetToScale(Difference.X, Difference.Y, ui.Parent.AbsoluteSize)
	end
	
	return NewPosition
end
  
return module
