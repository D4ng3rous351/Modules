--!native
--!strict
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/06/11
	Updated: 2025/09/23
	
	The purpose of this module is to serialize data into buffers
	for compression or networking.
]]

local module = {}

--Variables--
--Folders
local Data = script.Data

--Data
local Funcs = require(Data.Funcs)
local TypesData = require(Data.TypesData)

--Misc
local Datatypes = TypesData.Datatypes


--Private--
--Returns size in bytes needed to write all values to a buffer
local function GetSize(...): number
	local Size: number = 0
	local Values: {any} = {...}
	local GetSize: TypesData.GetSize?
	local Current: any
	local CurrentType: string
	
	for i: number = 1, #Values do
		Current = Values[i]
		CurrentType = typeof(Current)
		GetSize = Funcs.Size[Datatypes[CurrentType]]
		
		if GetSize then
			Size += GetSize(Current) + 1
		else
			error(`No size function for type {CurrentType}`)
		end
	end
	
	return Size
end

  
--Public--
  
--[[
	Compresses any applicable values into a buffer.
	<strong>offset:</strong> optional offset to start writing from.
	<strong>...:</strong> values that should be compressed.
	NOTE: Does not work with instances.
]]
function module.Serialize(offset: number?, ...: any): buffer
	if offset ~= nil then
		assert(typeof(offset) == "number" and offset == offset, "Argument is not of type number")
	end
	
	local Buffer: TypesData.ActiveBuffer = {
		Offset = offset or 0,
		Buffer = buffer.create(GetSize(...) + (offset or 0))
	}
	
	local Values: {any} = {...}
	
	if #Values == 0 then
		local Empty: buffer = buffer.create(2)
		buffer.writeu8(Empty, 1, Datatypes["nil"])
		return Empty
	end
	
	local Write: TypesData.WriteValue?
	local CurrentType: string, CurrentValue: any
	
	for i: number = 1, #Values do
		CurrentValue = Values[i]
		CurrentType = typeof(CurrentValue)
		buffer.writeu8(Buffer.Buffer, Buffer.Offset, Datatypes[CurrentType])
		Buffer.Offset += 1
		Write = Funcs.Write[Datatypes[CurrentType]]
		
		if Write then
			Write(Buffer, CurrentValue)
		elseif not Write and CurrentValue ~= nil then
			error(`No write function for type {CurrentType}`)
		end
	end
	
	return Buffer.Buffer
end
    
--[[
	Decompresses a buffer into its original form.
	<strong>b:</strong> buffer to unpack.
	<strong>offset:</strong> optional offset to start reading from.
]]
function module.Deserialize(b: buffer, offset: number?): ...any
	assert(typeof(b) == "buffer", "Argument is not of type buffer")
	if offset ~= nil then assert(typeof(offset) == "number" and offset == offset, "Argument is not of type number") end
	
	local Length: number = buffer.len(b)
	if Length == 1 then return nil end
	
	local Result: {any} = {}
	
	local Active: TypesData.ActiveBuffer = {
		Offset = offset or 0,
		Buffer = b,
	}
	
	local Type: number
	local Read: TypesData.ReadValue?
	local Index: number = 1
	
	while Active.Offset < Length - 1 do
		Type = buffer.readu8(b, Active.Offset)
		Active.Offset += 1
		Read = Funcs.Read[Type]
		Result[Index] = if Read then Read(Active) else nil
		Index += 1
	end
	
	for i: number = 1, table.maxn(Result) do
		if Result[i] == nil then Result[i] = nil end
	end
	
	return table.unpack(Result)
end
      
return module
