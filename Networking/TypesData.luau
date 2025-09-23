--!strict
--[[
	Contains any data related to data types
]]

--Constants--
local DATATYPES = {
	string = 0,
	CFrame = 1,
	Vector3 = 2,
	Vector2 = 3,
	vector = 4,
	UDim = 5,
	UDim2 = 6,
	Color3 = 7,
	Rect = 8,
	TweenInfo = 9,
	boolean = 10,
	number = 11,
	table = 12,
	BrickColor = 13,
	EnumItem = 14,
	buffer = 15,
	["nil"] = 16,
}

local TABLE_TYPES = {
	Array = 0,
	Dictionary = 1,
	Empty = 2,
}

local NUMBER_TYPES = {
	u8 = 0,
	i8 = 1,
	u16 = 2,
	i16 = 3,
	u32 = 4,
	i32 = 5,
	f32 = 6,
}

local READ_WRITE = {
	Read = {
		[NUMBER_TYPES.u8] = buffer.readu8,
		[NUMBER_TYPES.i8] = buffer.readi8,
		[NUMBER_TYPES.u16] = buffer.readu16,
		[NUMBER_TYPES.i16] = buffer.readi16,
		[NUMBER_TYPES.u32] = buffer.readu32,
		[NUMBER_TYPES.i32] = buffer.readi32,
		[NUMBER_TYPES.f32] = buffer.readf32,
	},
	Write = {
		[NUMBER_TYPES.u8] = buffer.writeu8,
		[NUMBER_TYPES.i8] = buffer.writei8,
		[NUMBER_TYPES.u16] = buffer.writeu16,
		[NUMBER_TYPES.i16] = buffer.writei16,
		[NUMBER_TYPES.u32] = buffer.writeu32,
		[NUMBER_TYPES.i32] = buffer.writei32,
		[NUMBER_TYPES.f32] = buffer.writef32,
	},
}

local NUMBER_SIZES: {number} = {
	[NUMBER_TYPES.u8] = 1,
	[NUMBER_TYPES.i8] = 1,
	[NUMBER_TYPES.u16] = 2,
	[NUMBER_TYPES.i16] = 2,
	[NUMBER_TYPES.u32] = 4,
	[NUMBER_TYPES.i32] = 4,
	[NUMBER_TYPES.f32] = 4,
}


--Types--
export type Read = (b: buffer, offset: number) -> number
export type Write = (b: buffer, offset: number, value: number) -> ()
export type CompatTable = {[any]: any} | {any}
export type ActiveBuffer = {
	Offset: number,
	Buffer: buffer,
}

export type WriteValue = (ActiveBuffer, any) -> ()
export type ReadValue = (ActiveBuffer) -> any
export type GetSize = (any) -> number


--Public--
return {
	Datatypes = DATATYPES,
	TableTypes = TABLE_TYPES,
	NumberTypes = NUMBER_TYPES,
	ReadWrite = READ_WRITE,
	NumberSizes = NUMBER_SIZES,
}
