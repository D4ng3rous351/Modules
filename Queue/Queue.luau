--!strict
--!native
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/03/25
	Updated: 2025/09/06
	
	The purpose of this module is to create fast and efficient object oriented queues.
]]

local module = {}

--Variables--
--Folders
local Classes = script.Classes
local Utility = script.Utility

--Utility
local TableUtilities = require(Utility.TableUtilities)

--Classes
local Signals = require(Classes.Signals)


--Types--
type QueuePrivate<T> = {
	__Items: {T},
	__Amount: number,
	__Length: number?,
}

export type Queue<T> = {	
	ItemAdded: Signals.Signal<T>,
	ItemRemoving: Signals.Signal<T>,
	LengthChanged: Signals.Signal<>,
	
	SetLength: (self: Queue<T>, newlength: number) -> (),
	GetLength: (self: Queue<T>) -> number?,
	GetItems: (self: Queue<T>) -> {T},
	Pop: (self: Queue<T>) -> T?,
	AddItem: (self: Queue<T>, item: T) -> (),
	RemoveItem: (self: Queue<T>, itemindex: number) -> T?,
	Clear: (self: Queue<T>) -> (),
	Destroy: (self: Queue<T>) -> (),
}

type __Queue<T> = Queue<T> & QueuePrivate<T>
type GenericQueue = __Queue<any>

--Methods--
local Queue: GenericQueue = {} :: GenericQueue

--Sets new length of queue and throws out any items past the index of the new length
function Queue.SetLength<T>(self: Queue<T>, newlength: number?): ()
	if newlength ~= nil then assert(typeof(newlength) == "number", "Argument is not of type number") end
	
	local __self: GenericQueue = self :: GenericQueue
	if __self.__Length == newlength then return end
	
	__self.__Length = newlength
	__self.LengthChanged:Fire()
	
	if not newlength then return end
	if #__self.__Items < newlength then return end
	
	for i: number = newlength + 1, #__self.__Items do
		__self.ItemRemoving:Fire(__self.__Items[i])
		__self.__Items[i] = nil
	end
end

--Returns set length of queue. Returns nil if length is infinite
function Queue.GetLength<T>(self: Queue<T>): number?
	return (self :: GenericQueue).__Length
end

--Returns items currently in queue
function Queue.GetItems<T>(self: Queue<T>): {T}
	return (self :: GenericQueue).__Items
end

--Returns top item in queue
function Queue.Pop<T>(self: Queue<T>): T?
	local Item: T? = table.remove((self :: GenericQueue).__Items, 1)
	
	if Item then
		self.ItemRemoving:Fire(Item);
		(self :: GenericQueue).__Amount -= 1
	end
	
	return Item
end

--Adds item to back of queue. Returns boolean indicating whether item was successfully added or not.
function Queue.AddItem<T>(self: Queue<T>, item: T): boolean
	assert(item, "Item cannot be nil")
	
	local __self: GenericQueue = self :: GenericQueue
	
	if __self.__Length then
		if __self.__Amount > __self.__Length then return false end
	end
	
	__self.__Amount += 1
	__self.__Items[__self.__Amount] = item
	__self.ItemAdded:Fire(item)
	
	return true
end

--Removes and returns item with specified index from queue
function Queue.RemoveItem<T>(self: Queue<T>, itemindex: number): T
	assert(typeof(itemindex) == "number", "Argument is not of type number")
	
	local __self: GenericQueue = self :: GenericQueue
	if __self.__Length then assert(itemindex <= __self.__Length, "Index is out of bounds") end
	
	local Removed: T = table.remove(__self.__Items, itemindex) :: T
	
	if Removed then
		__self.__Amount -= 1
		self.ItemRemoving:Fire(Removed)
	end
	
	return Removed
end

--Removes all items from queue
function Queue.Clear<T>(self: Queue<T>): ()
	for index: number, item: any in (self :: GenericQueue).__Items do
		self.ItemRemoving:Fire(item);
		(self :: GenericQueue).__Items[index] = nil
	end
end

--Gets rid of queue object
function Queue.Destroy<T>(self: Queue<T>): ()
	self.ItemAdded:Destroy()
	self.ItemRemoving:Destroy()
	self.LengthChanged:Destroy()
	table.clear(self)
end

--Constructor--
--Creates a new queue object with an optional length.
function module.New(length: number?): Queue<any>
	if length ~= nil then assert(typeof(length) == "number", "Argument is not of type number") end
	
	local NewQueue: GenericQueue = TableUtilities.DeepCopy(Queue)
	NewQueue.ItemAdded = Signals.New()
	NewQueue.ItemRemoving = Signals.New()
	NewQueue.LengthChanged = Signals.New()
	NewQueue.__Items = {}
	NewQueue.__Length = length
	NewQueue.__Amount = 0
	
	return NewQueue :: Queue<any>
end

return module
