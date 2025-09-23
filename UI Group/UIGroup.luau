--!strict
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/03/25
	Updated: 2025/09/06
	
	The purpose of this module is to create object oriented groups that control many UI elements at once.
]]

local module = {}

--Services--
local TweenService = game:GetService("TweenService")


--Variables--
--Folders
local Utility = script.Utility
local Classes = script.Classes

--Utility
local TableUtilities = require(Utility.TableUtilities)

--Classes
local Signals = require(Classes.Signals)


--Types--
export type DockingInfo = {
	Open: UDim2,
	Close: UDim2,
}

export type GroupTweenInfo = {
	Open: TweenInfo?,
	Close: TweenInfo?,
}

type UIGroupPrivate = {
	__UIs: {GuiObject},
	__Open: GuiObject?,
	__OpenPosition: UDim2,
	__ClosePosition: UDim2,
	__OpenTween: TweenInfo?,
	__CloseTween: TweenInfo?,
}

export type UIGroup = {
	MenuOpened: Signals.Signal<GuiObject>,
	MenuClosed: Signals.Signal<GuiObject>,
	MenuAdded: Signals.Signal<GuiObject>,
	MenuRemoved: Signals.Signal<GuiObject>,
	
	GetOpenMenu: (self: UIGroup) -> GuiObject?,
	OpenMenu: (self: UIGroup, menu: GuiObject) -> (),
	CloseMenu: (self: UIGroup) -> (),
	AddMenu: (self: UIGroup, new: GuiObject) -> (),
	RemoveMenu: (self: UIGroup, menu: GuiObject) -> (),
	ContainsMenu: (self: UIGroup, menu: GuiObject) -> boolean,
	GetDockPositions: (self: UIGroup) -> DockingInfo,
	SetDockPositions: (self: UIGroup, new: DockingInfo) -> (),
	SetTweens: (self: UIGroup, new: GroupTweenInfo) -> (),
	GetTweens: (self: UIGroup) -> GroupTweenInfo,
	Destroy: (self: UIGroup) -> (),
}

type __UIGroup = UIGroupPrivate & UIGroup

--Methods--
local Class: __UIGroup = {} :: __UIGroup

--Returns currently open menu, if any
function Class.GetOpenMenu(self: UIGroup): GuiObject?
	return (self :: __UIGroup).__Open
end

--Opens menu and tweens it to docking position if an applicable tween info is set.
--NOTE: If another menu from the same group is open, it will be closed
function Class.OpenMenu(self: UIGroup, menu: GuiObject): ()
	assert(typeof(menu) == "Instance", "Argument is not of type GuiObject")
	assert(menu.ClassName == "GuiObject", "Argument is not of type GuiObject")
	
	local __self: __UIGroup = self :: __UIGroup
	
	assert(table.find(__self.__UIs, menu), "Specified menu is not a valid member of UI group")
	
	if __self.__Open then __self:CloseMenu() end
	
	(menu :: GuiObject).Visible = true
	(menu :: GuiObject).Interactable = true
	
	if __self.__OpenTween then
		TweenService:Create(menu, __self.__OpenTween, {Position = __self.__OpenPosition}):Play()
	else
		(menu :: GuiObject).Position = __self.__OpenPosition
	end
	
	__self.__Open = menu
	__self.MenuOpened:Fire(menu)
end

--Closes currently open menu if any and tweens it to docking position if an applicable tween info is set
function Class.CloseMenu(self: UIGroup): ()
	local __self: __UIGroup = self :: __UIGroup
	
	if not __self.__Open then return end
	
	if __self.__CloseTween then
		TweenService:Create(__self.__Open, __self.__CloseTween, {Position = __self.__ClosePosition}):Play()
	else
		__self.__Open.Visible = false
		__self.__Open.Interactable = false
		__self.__Open.Position = __self.__ClosePosition
	end
	
	__self.MenuClosed:Fire(__self.__Open)
	__self.__Open = nil
end

--Adds a GUI object to the UI group
function Class.AddMenu(self: UIGroup, new: GuiObject): ()
	assert(typeof(new) == "Instance", "Argument is not of type GuiObject")
	assert(new.ClassName == "GuiObject", "Argument is not of type GuiObject")
	
	local __self: __UIGroup = self :: __UIGroup
	
	if table.find(__self.__UIs, new) then warn("Menu is already part of UI group") return end
	
	table.insert(__self.__UIs, new)
	new.Position = __self.__ClosePosition
	__self.MenuAdded:Fire(new)
end

--Removes the specified GUI object from the UI group
function Class.RemoveMenu(self: UIGroup, menu: GuiObject): ()
	assert(typeof(menu) == "Instance", "Argument is not of type GuiObject")
	assert(menu.ClassName == "GuiObject", "Argument is not of type GuiObject")
	
	local __self: __UIGroup = self :: __UIGroup
	
	local Index: number = table.find(__self.__UIs, menu) :: number
	assert(Index, "Specified menu is not a valid member of UI group")
	
	table.remove(__self.__UIs, Index)
	__self.MenuRemoved:Fire(menu)
end

--Returns whether the UI group contains the provided menu or not
function Class.ContainsMenu(self: UIGroup, menu: GuiObject): boolean
	assert(typeof(menu) == "Instance", "Argument is not of type GuiObject")
	assert(menu.ClassName == "GuiObject", "Argument is not of type GuiObject")
	return table.find((self :: __UIGroup).__UIs, menu) ~= nil
end

--Returns the currently set docking positions
function Class.GetDockPositions(self: UIGroup): DockingInfo
	local __self: __UIGroup = self :: __UIGroup
	
	local DockingInfo: DockingInfo = {
		Open = __self.__OpenPosition,
		Close = __self.__ClosePosition
	}
	
	return DockingInfo
end

--Sets docking positions to new values.
--NOTE: If a menu is currently open and the "Open" docking position is updated, the open menu will update as well
function Class.SetDockPositions(self: UIGroup, new: DockingInfo): ()
	assert(typeof(new) == "table", "Argument is not of type DockingInfo")
	
	local __self: __UIGroup = self :: __UIGroup
	
	__self.__OpenPosition = new.Open or __self.__OpenPosition
	__self.__ClosePosition = new.Close or __self.__ClosePosition
	
	if __self.__Open then
		__self.__Open.Position = __self.__OpenPosition
	end
	
	if new.Close then
		for _, menu in __self.__UIs do
			if menu == __self.__Open then continue end
			menu.Position = new.Close
		end
	end
end

--Sets tweens to newly provided one
function Class.SetTweens(self: UIGroup, new: GroupTweenInfo): ()
	assert(typeof(new) == "table", "Argument is not of type GroupTweenInfo")
	
	local __self: __UIGroup = self :: __UIGroup
	
	__self.__OpenTween = new.Open or nil
	__self.__CloseTween = new.Close or nil
end

--Returns the currently set tween info
function Class.GetTweens(self: UIGroup): GroupTweenInfo
	local __self: __UIGroup = self :: __UIGroup
	
	local Tweens: GroupTweenInfo = {
		Open = __self.__OpenTween,
		Close = __self.__CloseTween
	}
	
	return Tweens
end

--Removes instance from memory
--NOTE: Will also destroy all UI objects
function Class.Destroy(self: UIGroup): ()
	for _: number, ui: GuiObject in (self :: __UIGroup).__UIs do
		ui:Destroy()
	end
	
	self.MenuOpened:Destroy()
	self.MenuAdded:Destroy()
	self.MenuClosed:Destroy()
	self.MenuRemoved:Destroy()
	table.clear(self)
end

--Constructor--

--[[
	Creates new UI group.
	<strong>open:</strong> opened docking position.
	<strong>close:</strong> closed docking position.
	<strong>guis:</strong> optional GUIs to start with.
]]
function module.New(open: UDim2, close: UDim2, guis: {GuiObject}?): UIGroup
	assert(typeof(open) == "UDim2", "Argument is not of type UDim2")
	assert(typeof(close) == "UDim2", "Argument is not of type UDim2")
	if guis ~= nil then assert(typeof(guis) == "table", "Argument is not of type table") end
	
	local self: __UIGroup = TableUtilities.DeepCopy(Class)
	self.MenuOpened = Signals.New()
	self.MenuClosed = Signals.New()
	self.MenuAdded = Signals.New()
	self.MenuRemoved = Signals.New()
	
	self.__UIs = {}
	self.__OpenPosition = open
	self.__ClosePosition = close
	
	if guis then
		for _: number, gui: GuiObject in guis do
			gui.Position = close
			self.__UIs[#self.__UIs + 1] = gui
		end
	end
	
	return self :: UIGroup
end

return module
