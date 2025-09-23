--!strict
--!native
--[[
	Author: D4ng3rous351
	Created: 2025/04/29
	Updated: 2025/09/06
	
	The purpose of this module is to create object oriented, generic 2D grids.
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
type Symbols = {
	X: {string},
	Y: {string},
}

type Grid2DPrivate<T> = {
	__Size: vector,
	__Symbols: Symbols,
	__Grid: {{T}},
}

export type Grid2D<T> = {
	Inserted: Signals.Signal<T>,
	Removed: Signals.Signal<T>,
	
	Insert: (self: Grid2D<T>, value: T, coordinates: vector) -> (),
	Remove: (self: Grid2D<T>, coordinates: vector) -> (T?),
	GetValueFromCoordinates: (self: Grid2D<T>, coordinates: vector) -> (T?),
	GetCoordinatesFromValue: (self: Grid2D<T>, value: T) -> (vector?),
	GetCoordinateString: (self: Grid2D<T>, coordinates: vector) -> (string?),
	SetXSymbols: (self: Grid2D<T>, symbols: {string}) -> (),
	GetXSymbols: (self: Grid2D<T>) -> ({string}),
	SetYSymbols: (self: Grid2D<T>, symbols: {string}) -> (),
	GetYSymbols: (self: Grid2D<T>) -> ({string}),
	SetSize: (self: Grid2D<T>, newsize: vector) -> (),
	Destroy: (self: Grid2D<T>) -> (),
}

type __Grid2D<T> = Grid2DPrivate<T> & Grid2D<T>
type GenericGrid = __Grid2D<any>

--Methods--
local Class: GenericGrid = {} :: GenericGrid

--Inserts value into provided coordinates
function Class.Insert<T>(self: Grid2D<T>, value: T, coordinates: vector): ()
	assert(value, "Value cannot be nil")
	assert(type(coordinates) == "vector", "Argument is not of type vector")
	assert(coordinates.x >= 1, "Values cannot be smaller than one")
	assert(coordinates.y >= 1, "Values cannot be smaller than one")
	
	local __self: __Grid2D<T> = self :: __Grid2D<T>
	coordinates = vector.floor(coordinates)
	
	if coordinates.x > __self.__Size.x or coordinates.y > __self.__Size.y then error("Coordinates violate size limit") end
	
	__self.__Grid[coordinates.x][coordinates.y] = value
	__self.Inserted:Fire(value)
end

--Removes value at provided coordinates from grid, if any
function Class.Remove<T>(self: Grid2D<T>, coordinates: vector): T
	assert(type(coordinates) == "vector", "Argument is not of type vector")
	assert(coordinates.x >= 1, "Values cannot be smaller than one")
	assert(coordinates.y >= 1, "Values cannot be smaller than one")
	
	local __self: GenericGrid = self :: GenericGrid
	coordinates = vector.floor(coordinates)
	
	if coordinates.x > __self.__Size.x or coordinates.y > __self.__Size.y then error("Coordinates violate size limit") end
	
	local Value: any = __self.__Grid[coordinates.x][coordinates.y]
	
	__self.__Grid[coordinates.x][coordinates.y] = nil
	__self.Removed:Fire(Value)
	
	return Value
end

--Returns value at provided coordinates
function Class.GetValueFromCoordinates<T>(self: Grid2D<T>, coordinates: vector): T
	assert(type(coordinates) == "vector", "Argument is not of type vector")
	
	local __self: GenericGrid = self :: GenericGrid
	coordinates = vector.floor(coordinates)
	
	if coordinates.x > __self.__Size.x or coordinates.y > __self.__Size.y then error("Coordinates violate size limit") end
	
	return __self.__Grid[coordinates.x][coordinates.y]
end

--Returns coordinates of provided value
function Class.GetCoordinatesFromValue<T>(self: Grid2D<T>, value: T): vector?
	assert(value, "Value cannot be nil")
	
	local __self: __Grid2D<T> = self :: __Grid2D<T>
	
	for x: number = 1, #__self.__Grid do
		for y: number = 1, #__self.__Grid[x] do
			if __self.__Grid[x][y] == value then return vector.create(x, y) end
		end
	end
	
	return nil
end

--Returns X symbol concatenated with Y symbol that correspond to provided coordinates, if any
function Class.GetCoordinateString<T>(self: Grid2D<T>, coordinates: vector): string?
	assert(type(coordinates) == "vector", "Argument is not of type vector")
	
	local __self: GenericGrid = self :: GenericGrid
	coordinates = vector.floor(coordinates)
	
	if coordinates.x > __self.__Size.x or coordinates.y > __self.__Size.y then error("Coordinates violate size limit") end
	
	local Symbols: Symbols = __self.__Symbols
	local XCoord: string = if Symbols.X[coordinates.x] then Symbols.X[coordinates.x] else ""
	local YCoord: string = if Symbols.Y[coordinates.y] then Symbols.Y[coordinates.y] else ""
	
	local CoordString: string = `{XCoord}{YCoord}`
	if CoordString == "" then return nil end
	
	return CoordString
end
    
--Sets X symbols table to provided value
function Class.SetXSymbols<T>(self: Grid2D<T>, symbols: {string}): ()
	assert(typeof(symbols) == "table", "Argument is not of type table");
	(self :: GenericGrid).__Symbols.X = symbols
end
    
--Returns symbols table for X
function Class.GetXSymbols<T>(self: Grid2D<T>): {string}
	return (self :: GenericGrid).__Symbols.X
end
    
--Sets Y symbols table to provided value
function Class.SetYSymbols<T>(self: Grid2D<T>, symbols: {string}): ()
	assert(typeof(symbols) == "table", "Argument is not of type table");
	(self :: GenericGrid).__Symbols.Y = symbols
end
    
--Returns symbols table for Y
function Class.GetYSymbols<T>(self: Grid2D<T>): {string}
	return (self :: GenericGrid).__Symbols.Y
end
    
--Changes size of grid.
--NOTE: Will remove any values past new size's index if new size
--is smaller than original size
function Class.SetSize<T>(self: Grid2D<T>, newsize: vector): ()
	assert(type(newsize) == "vector", "Argument is not of type vector")
	assert(newsize.x >= 1, "Values cannot be smaller than one")
	assert(newsize.y >= 1, "Values cannot be smaller than one")
	
	local __self: GenericGrid = self :: GenericGrid
	newsize = vector.floor(newsize)
	
	if newsize.x > __self.__Size.x then
		for x: number = newsize.x + 1, __self.__Size.x do
			__self.__Grid[x] = nil
		end
	end
	
	if newsize.y > __self.__Size.y then
		for x: number = 1, newsize.x do
			for y: number = newsize.y + 1, __self.__Size.y do
				__self.__Grid[x][y] = nil
			end
		end
	end
	
	__self.__Size = newsize
end
    
--Removes instance from memory
function Class.Destroy<T>(self: Grid2D<T>): ()
	self.Inserted:Destroy()
	self.Removed:Destroy()
	table.clear(self)
end
    
--Constructor--
    
--[[
	Returns new 2D grid with corresponding size.
	<strong>size:</strong> size for the grid (only x and y will be used).
]]
function module.New(size: vector): Grid2D<any>
	assert(type(size) == "vector", "Argument is not of type vector")
	
	size = vector.floor(size)
	
	local self: GenericGrid = TableUtilities.DeepCopy(Class)
	self.Inserted = Signals.New()
	self.Removed = Signals.New()
	
	self.__Size = size
	self.__Symbols = {
		X = {},
		Y = {},
	}
	
	self.__Grid = {}
	
	for x: number = 1, size.x do
		self.__Grid[x] = {}
	end
	
	return self :: Grid2D<any>
end
    
return module
