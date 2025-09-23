--!strict
--!native

local module: Funcs = {
	Read = {},
	Write = {},
	Size = {},
}

--Variables--
--Folders
local Data = script.Parent
local Utility = Data.Parent.Utility

--Data
local TypesData = require(Data.TypesData)

--Utility
local TableUtilities = require(Utility.TableUtilities)

--Misc
local NumberTypes = TypesData.NumberTypes
local Datatypes = TypesData.Datatypes
local ReadWrite = TypesData.ReadWrite
local NumberSizes = TypesData.NumberSizes
local TableTypes = TypesData.TableTypes
local AllEnums: {Enum} = Enum:GetEnums()


--Types--
type Funcs = {
	Write: {TypesData.WriteValue},
	Read: {TypesData.ReadValue},
	Size: {TypesData.GetSize},
}

type ReadData = {
	Read: TypesData.Read,
	Size: number,
}


--Private--

--Returns the size of a number in bytes.
local function GetNumberSize(num: number): number
	assert(typeof(num) == "number" and num == num, "Argument is not of type number")
	
	if num > 2^64 - 1 then
		warn("Precision lost due to number being greater than 2^64 - 1")
		return 8
	end
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

--Creates read components from the given buffer's offset value
local function CreateNumberReadData(b: TypesData.ActiveBuffer): ReadData
	local EnumVal: number = buffer.readu8(b.Buffer, b.Offset)
	b.Offset += 1
	
	local New: ReadData = {
		Read = ReadWrite.Read[EnumVal],
		Size = NumberSizes[EnumVal],
	}
	
	return New
end

--Returns the numerical components of a Vector or UDim in a table
local function GetComponents(data: Vector3 | Vector2 | vector | UDim | UDim2): {number}
	local DataType: string = typeof(data)
	local Components: {number}
	if DataType == "Vector3" then
		Components = {
			(data :: Vector3).X,
			(data :: Vector3).Y,
			(data :: Vector3).Z,
		}
	elseif DataType == "Vector2" then
		Components = {
			(data :: Vector2).X,
			(data :: Vector2).Y,
		}
	elseif DataType == "vector" then
		Components = {
			(data :: vector).x,
			(data :: vector).y,
			(data :: vector).z,
		}
	elseif DataType == "UDim" then
		Components = {
			(data :: UDim).Scale,
			(data :: UDim).Offset,
		}
	elseif DataType == "UDim2" then
		Components = {
			(data :: UDim2).X.Scale,
			(data :: UDim2).X.Offset,
			(data :: UDim2).Y.Scale,
			(data :: UDim2).Y.Offset,
		}
	end
	return Components
end

--Cached function to use when comparing numbers
local function __Compare(a: number, b: number): boolean
	return GetNumberSize(a) < GetNumberSize(b)
end

--Returns value of component with largest size in bytes in a Vector or UDim
local function GetLargestComponent(data: Vector3 | Vector2 | vector | UDim | UDim2): number
	local Components: {number} = GetComponents(data)
	for _: number, v: number in Components do
		if v % 1 ~= 0 then return v end
	end
	local _: number, Largest: number = TableUtilities.Filter(Components, __Compare)
	return Largest
end

--Returns string name of number
local function GetNumberType(num: number): string
	if num % 1 ~= 0 then return "f32" end
	local TypeName: string = if num < 0 then "i" else "u"
	return `{TypeName}{GetNumberSize(num) * 8}`
end
  
--Returns the string name of the table's type
local function GetTableType(t: TypesData.CompatTable): number
	local FirstKey: string? | number? = next(t)
	if not FirstKey then return TypesData.TableTypes.Empty end
	local KeyType: string = typeof(FirstKey)
	local Type: number
	if KeyType == "number" then
		Type = TypesData.TableTypes.Array
	else
		Type = TypesData.TableTypes.Dictionary
	end
	return Type
end
  
--Returns appropriate function for writing the provided number to a buffer
local function GetWrite(n: number): TypesData.Write
	local EnumValue: number = TypesData.NumberTypes[GetNumberType(n)]
	return TypesData.ReadWrite.Write[EnumValue]
end
  
--Returns appropriate function for reading the provided number from a buffer
local function GetRead(n: number): TypesData.Read
	local EnumValue: number = TypesData.NumberTypes[GetNumberType(n)]
	return TypesData.ReadWrite.Read[EnumValue]
end

  
--Public--
  
--Writes string to a buffer
local function WriteString(b: TypesData.ActiveBuffer, data: string): ()
	assert(string.find(data, "\0") == nil, "Cannot write null terminator")
	buffer.writestring(b.Buffer, b.Offset, data)
	b.Offset += string.len(data)
	buffer.writeu8(b.Buffer, b.Offset, 0)
	b.Offset += 1
end
  
--Reads string value from buffer
local function ReadString(b: TypesData.ActiveBuffer): string
	local Length: number = buffer.len(b.Buffer)
	local Result: string = ""
	local Current: string
	
	while b.Offset < Length do
		Current = buffer.readstring(b.Buffer, b.Offset, 1)
		b.Offset += 1
		
		if Current == "\0" then break end
		
		Result ..= Current
	end
	
	return Result
end
  
--Returns bytes required for string
local function StringSize(a: string): number
	return string.len(a) + 1
end
  
--Writes either a Vector3, Vector2 or vector to a buffer
local function WriteVector(b: TypesData.ActiveBuffer, data: Vector3 | Vector2 | vector): ()
	local Largest: number = GetLargestComponent(data)
	local LargestSize: number = GetNumberSize(Largest)
	local Write: TypesData.Write = GetWrite(Largest)
	local Components: {number} = GetComponents(data)
	
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(Largest)])
	b.Offset += 1
	
	for i: number = 1, #Components do
		Write(b.Buffer, b.Offset, Components[i])
		b.Offset += LargestSize
	end
end
  
--Reads Vector3 value from buffer
local function ReadVector3(b: TypesData.ActiveBuffer): Vector3
	local Read: ReadData = CreateNumberReadData(b)
	local Components: {number} = {}
	
	for i: number = 1, 3 do
		Components[i] = Read.Read(b.Buffer, b.Offset)
		b.Offset += Read.Size
	end
	
	return Vector3.new(Components[1], Components[2], Components[3])
end
  
--Returns bytes required for Vector3
local function Vector3Size(a: Vector3): number
	return (GetNumberSize(GetLargestComponent(a)) * 3) + 1
end
  
--Reads vector value from buffer
local function ReadVector(b: TypesData.ActiveBuffer): vector
	local Read: ReadData = CreateNumberReadData(b)
	local Components: {number} = {}
	for i: number = 1, 3 do
		Components[i] = Read.Read(b.Buffer, b.Offset)
		b.Offset += Read.Size
	end
	return vector.create(Components[1], Components[2], Components[3])
end
  
--Returns bytes required for vector
local function VectorSize(a: vector): number
	return (GetNumberSize(GetLargestComponent(a)) * 3) + 1
end
  
--Reads Vector2 value from buffer
local function ReadVector2(b: TypesData.ActiveBuffer): Vector2
	local Read: ReadData = CreateNumberReadData(b)
	local Components: {number} = {}
	for i: number = 1, 2 do
		Components[i] = Read.Read(b.Buffer, b.Offset)
		b.Offset += Read.Size
	end
	return Vector2.new(Components[1], Components[2])
end
  
--Returns bytes required for Vector2
local function Vector2Size(a: Vector2): number
	return (GetNumberSize(GetLargestComponent(a)) * 2) + 1
end
  
--Writes CFrame to buffer
local function WriteCFrame(b: TypesData.ActiveBuffer, data: CFrame): ()
	local Rotation: {number} = {data:ToOrientation()}
	WriteVector(b, data.Position)
	
	for i: number = 1, #Rotation do
		buffer.writef32(b.Buffer, b.Offset, math.deg(Rotation[i]))
		b.Offset += 4
	end
end
  
--Reads CFrame value from buffer
local function ReadCFrame(b: TypesData.ActiveBuffer): CFrame
	local Position: vector = ReadVector(b)
	local Rotations: {number} = {}
	
	for i: number = 1, 3 do
		Rotations[i] = math.rad(buffer.readf32(b.Buffer, b.Offset))
		b.Offset += 4
	end
	
	return CFrame.new(Position :: any) * CFrame.fromOrientation(table.unpack(Rotations))
end
  
--Returns bytes required for CFrame
local function CFrameSize(a: CFrame): number
	return module.Size[Datatypes.Vector3](a.Position) + (4 * 3) + 1
end
  
--Writes either a UDim to a buffer
local function WriteUDim(b: TypesData.ActiveBuffer, data: UDim): ()
	local Largest: number = GetLargestComponent(data)
	local LargestSize: number = GetNumberSize(Largest)
	local Write: TypesData.Write = GetWrite(Largest)
	local Components: {number} = GetComponents(data)
	
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(Largest)])
	b.Offset += 1
	
	for i: number = 1, #Components do
		Write(b.Buffer, b.Offset, Components[i])
		b.Offset += LargestSize
	end
end
  
--Reads UDim value from buffer
local function ReadUDim(b: TypesData.ActiveBuffer): UDim
	local Read: ReadData =  CreateNumberReadData(b)
	local Components: {number} = {}
	
	for i: number = 1, 2 do
		Components[i] = Read.Read(b.Buffer, b.Offset)
		b.Offset += Read.Size
	end
	
	return UDim.new(Components[1], Components[2])
end
  
--Returns bytes required for CFrame
local function UDimSize(a: UDim): number
	return (GetNumberSize(GetLargestComponent(a)) * 2) + 1
end
  
--Writes a UDim2 to a buffer
local function WriteUDim2(b: TypesData.ActiveBuffer, data: UDim2): ()
	WriteUDim(b, data.X)
	WriteUDim(b, data.Y)
end
  
--Reads UDim2 value from buffer
local function ReadUDim2(b: TypesData.ActiveBuffer): UDim2
	return UDim2.new(ReadUDim(b), ReadUDim(b))
end
  
--Returns bytes required for UDim2
local function UDim2Size(a: UDim2): number
	return module.Size[Datatypes.UDim](a.X) + module.Size[Datatypes.UDim](a.Y) + 1
end
  
--Writes color3 to a buffer
local function WriteColor3(b: TypesData.ActiveBuffer, data: Color3): ()
	buffer.writeu8(b.Buffer, b.Offset, (data.R * 255) // 1)
	buffer.writeu8(b.Buffer, b.Offset + 1, (data.G * 255) // 1)
	buffer.writeu8(b.Buffer, b.Offset + 2, (data.B * 255) // 1)
	b.Offset += 3
end
  
--Reads color3 value from buffer
local function ReadColor3(b: TypesData.ActiveBuffer): Color3
	local R: number = buffer.readu8(b.Buffer, b.Offset)
	local G: number = buffer.readu8(b.Buffer, b.Offset + 1)
	local B: number = buffer.readu8(b.Buffer, b.Offset + 2)
	b.Offset += 3
	return Color3.fromRGB(R, G, B)
end
  
--Returns bytes required for Color3
local function Color3Size(a: Color3): number
	return 3
end
  
--Writes rect value to buffer
local function WriteRect(b: TypesData.ActiveBuffer, data: Rect): ()
	WriteVector(b, data.Min)
	WriteVector(b, data.Max)
end
  
--Reads rect value from buffer
local function ReadRect(b: TypesData.ActiveBuffer): Rect
	local Min: Vector2 = ReadVector2(b)
	local Max: Vector2 = ReadVector2(b)
	return Rect.new(Min, Max)
end
  
--Returns bytes required for Rect
local function RectSize(a: Rect): number
	return module.Size[Datatypes.Vector2](a.Min) + module.Size[Datatypes.Vector2](a.Max)
end
  
--Writes tween info to buffer
local function WriteTweenInfo(b: TypesData.ActiveBuffer, data: TweenInfo): ()
	local WriteTime: TypesData.Write = GetWrite(data.Time)
	local TimeSize: number = GetNumberSize(data.Time)
	local WriteDelay: TypesData.Write = GetWrite(data.DelayTime)
	
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(data.Time)])
	WriteTime(b.Buffer, b.Offset + 1, data.Time)
	b.Offset += 1 + TimeSize
	
	buffer.writeu8(b.Buffer, b.Offset, data.EasingStyle.Value)
	buffer.writeu8(b.Buffer, b.Offset + 1, data.EasingDirection.Value)
	buffer.writei8(b.Buffer, b.Offset + 2, data.RepeatCount)
	buffer.writeu8(b.Buffer, b.Offset + 3, if data.Reverses then 1 else 0)
	buffer.writeu8(b.Buffer, b.Offset + 4, NumberTypes[GetNumberType(data.DelayTime)])
	b.Offset += 5
	
	WriteDelay(b.Buffer, b.Offset, data.DelayTime)
	b.Offset += GetNumberSize(data.DelayTime)
end
    
--Reads tween info from buffer
local function ReadTweenInfo(b: TypesData.ActiveBuffer): TweenInfo
	local Time: number, Style: number, Direction: number, Repeats: number, Reverses: boolean, DelayTime: number
	
	local Read: ReadData = CreateNumberReadData(b)
	Time = Read.Read(b.Buffer, b.Offset)
	b.Offset += Read.Size
	
	Style = buffer.readu8(b.Buffer, b.Offset)
	Direction = buffer.readu8(b.Buffer, b.Offset + 1)
	Repeats = buffer.readi8(b.Buffer, b.Offset + 2)
	Reverses = if buffer.readu8(b.Buffer, b.Offset + 3) ~= 0 then true else false
	
	b.Offset += 4
	Read = CreateNumberReadData(b)
	
	DelayTime = Read.Read(b.Buffer, b.Offset)
	b.Offset += Read.Size
	
	return TweenInfo.new(
		Time,
		Enum.EasingStyle:FromValue(Style),
		Enum.EasingDirection:FromValue(Direction),
		Repeats,
		Reverses,
		DelayTime
	)
end
      
--Returns bytes required for TweenInfo
local function TweenInfoSize(a: TweenInfo): number
	return 6 + GetNumberSize(a.Time) + GetNumberSize(a.DelayTime)
end
      
--Writes boolean to buffer
local function WriteBoolean(b: TypesData.ActiveBuffer, data: boolean): ()
	buffer.writeu8(b.Buffer, b.Offset, if data then 1 else 0)
	b.Offset += 1
end
        
--Reads boolean from buffer
local function ReadBoolean(b: TypesData.ActiveBuffer): boolean
	local Bool: boolean = if buffer.readu8(b.Buffer, b.Offset) ~= 0 then true else false
	b.Offset += 1
	return Bool
end
          
--Returns bytes required for boolean
local function BooleanSize(a: boolean): number
	return 1
end
          
--Writes a number to buffer
local function WriteNumber(b: TypesData.ActiveBuffer, data: number): ()
	local Write: TypesData.Write = GetWrite(data)
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(data)])
	Write(b.Buffer, b.Offset + 1, data)
	b.Offset += GetNumberSize(data) + 1
end
          
--Reads a number from buffer
local function ReadNumber(b: TypesData.ActiveBuffer): number
	local Read: ReadData = CreateNumberReadData(b)
	local Num: number = Read.Read(b.Buffer, b.Offset)
	b.Offset += Read.Size
	return Num
end
          
--Returns bytes required for number
local function NumberSize(a: number): number
	return GetNumberSize(a) + 1
end
          
--Writes a table to a buffer
local function WriteTable(b: TypesData.ActiveBuffer, data: TypesData.CompatTable): ()
	local Items: number = TableUtilities.GetLength(data)
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(Items)])
	GetWrite(Items)(b.Buffer, b.Offset + 1, Items)
	b.Offset += 1 + GetNumberSize(Items)
	
	local TableType: number = GetTableType(data)
	buffer.writeu8(b.Buffer, b.Offset, TableType)
	b.Offset += 1
	
	local EnumVal: number
	
	if TableType == TableTypes.Array then
		for k: any, v: any in data :: any do
			EnumVal = Datatypes[typeof(v)]
			buffer.writeu8(b.Buffer, b.Offset, EnumVal)
			b.Offset += 1
			module.Write[EnumVal](b, v)
		end
	elseif TableType == TableTypes.Dictionary then
		for k: any, v: any in data :: any do
			EnumVal = Datatypes[typeof(k)]
			buffer.writeu8(b.Buffer, b.Offset, EnumVal)
			b.Offset += 1
			module.Write[EnumVal](b, k)
			
			EnumVal = Datatypes[typeof(v)]
			buffer.writeu8(b.Buffer, b.Offset, EnumVal)
			b.Offset += 1
			module.Write[EnumVal](b, v)
		end
	end
end
          
--Reads a table from a buffer
local function ReadTable(b: TypesData.ActiveBuffer): TypesData.CompatTable
	local ItemsNumType: number = buffer.readu8(b.Buffer, b.Offset)
	b.Offset += 1
	
	local Items: number = ReadWrite.Read[ItemsNumType](b.Buffer, b.Offset)
	b.Offset += GetNumberSize(Items)
	
	local TableType: number = buffer.readu8(b.Buffer, b.Offset)
	b.Offset += 1
	
	local Result: TypesData.CompatTable = {}
	local ValueType: number
	
	if TableType == TableTypes.Array then
		for i: number = 1, Items do
			ValueType = buffer.readu8(b.Buffer, b.Offset)
			b.Offset += 1
			Result[i] = module.Read[ValueType](b)
		end
	elseif TableType == TableTypes.Dictionary then
		local KeyType: number
		local Key: any, Value: any
		
		for i: number = 1, Items do
			KeyType = buffer.readu8(b.Buffer, b.Offset)
			b.Offset += 1
			Key = module.Read[KeyType](b)
			ValueType = buffer.readu8(b.Buffer, b.Offset)
			b.Offset += 1
			Value = module.Read[ValueType](b)
			
			Result[Key] = Value
		end
	end
	
	return Result
end
          
--Returns bytes required for table
local function TableSize(a: TypesData.CompatTable): number
	if not next(a) then return 3 end
	local Size: number = 2 + GetNumberSize(TableUtilities.GetLength(a))
	local TableType: number = GetTableType(a)
	if TableType == TypesData.TableTypes.Array then
		for _: any, v: any in a :: any do
			Size += module.Size[Datatypes[typeof(v)]](v) + 1
		end
	elseif TableType == TypesData.TableTypes.Dictionary then
		for k: any, v: any in a :: any do
			Size += module.Size[Datatypes[typeof(k)]](k) + 1 + module.Size[Datatypes[typeof(v)]](v) + 1
		end
	end
	return Size
end
          
--Writes a brick color to buffer
local function WriteBrickColor(b: TypesData.ActiveBuffer, data: BrickColor): ()
	WriteColor3(b, data.Color)
end
          
--Reads a brick color from buffer
local function ReadBrickColor(b: TypesData.ActiveBuffer): BrickColor
	local Color: Color3 = ReadColor3(b)
	return BrickColor.new(Color)
end
          
--Returns bytes required for BrickColor
local function BrickColorSize(a: BrickColor): number
	return 3
end
          
--Writes enum item to buffer
local function WriteEnumItem(b: TypesData.ActiveBuffer, data: EnumItem): ()
	buffer.writeu16(b.Buffer, b.Offset, table.find(AllEnums, data.EnumType) :: number)
	b.Offset += 2
	buffer.writeu16(b.Buffer, b.Offset, data.Value)
	b.Offset += 2
end
          
--Reads enum item from buffer
local function ReadEnumItem(b: TypesData.ActiveBuffer): EnumItem
	local Parent: Enum = AllEnums[buffer.readu16(b.Buffer, b.Offset)]
	b.Offset += 2
	
	local Item: EnumItem = (Parent :: any):FromValue(buffer.readu16(b.Buffer, b.Offset))
	b.Offset += 2
	
	return Item
end
          
--Returns bytes required for EnumItem
local function EnumItemSize(a: EnumItem): number
	return 4
end
          
--Writes buffer to buffer
local function WriteBuffer(b: TypesData.ActiveBuffer, data: buffer): ()
	local Length: number = buffer.len(data)
	buffer.writeu8(b.Buffer, b.Offset, NumberTypes[GetNumberType(Length)])
	b.Offset += 1
	
	GetWrite(Length)(b.Buffer, b.Offset, Length)
	b.Offset += GetNumberSize(Length)
	
	buffer.copy(b.Buffer, b.Offset, data, 0)
	b.Offset += Length
end
          
--Reads buffer from buffer
local function ReadBuffer(b: TypesData.ActiveBuffer): buffer?
	local Read: TypesData.Read = ReadWrite.Read[buffer.readu8(b.Buffer, b.Offset)]
	b.Offset += 1
	
	local Length: number = Read(b.Buffer, b.Offset)
	
	b.Offset += GetNumberSize(Length)
	
	local Buffer: buffer = buffer.create(Length)
	buffer.copy(Buffer, 0, b.Buffer, b.Offset, Length)
	
	return Buffer
end
          
--Returns bytes required for buffer
local function BufferSize(a: buffer): number
	local Length: number = buffer.len(a)
	return GetNumberSize(Length) + Length + 1
end
          
--Returns bytes required for nil
local function NilSize(a: nil): number
	return 0
end
          
module.Write[Datatypes.string] = WriteString
module.Read[Datatypes.string] = ReadString
module.Size[Datatypes.string] = StringSize
module.Write[Datatypes.CFrame] = WriteCFrame
module.Read[Datatypes.CFrame] = ReadCFrame
module.Size[Datatypes.CFrame] = CFrameSize
module.Write[Datatypes.Vector3] = WriteVector
module.Read[Datatypes.Vector3] = ReadVector3
module.Size[Datatypes.Vector3] = Vector3Size
module.Write[Datatypes.Vector2] = WriteVector
module.Read[Datatypes.Vector2] = ReadVector2
module.Size[Datatypes.Vector2] = Vector2Size
module.Write[Datatypes.vector] = WriteVector
module.Read[Datatypes.vector] = ReadVector
module.Size[Datatypes.vector] = VectorSize
module.Write[Datatypes.UDim] = WriteUDim
module.Read[Datatypes.UDim] = ReadUDim
module.Size[Datatypes.UDim] = UDimSize
module.Write[Datatypes.UDim2] = WriteUDim2
module.Read[Datatypes.UDim2] = ReadUDim2
module.Size[Datatypes.UDim2] = UDim2Size
module.Write[Datatypes.Color3] = WriteColor3
module.Read[Datatypes.Color3] = ReadColor3
module.Size[Datatypes.Color3] = Color3Size
module.Write[Datatypes.Rect] = WriteRect
module.Read[Datatypes.Rect] = ReadRect
module.Size[Datatypes.Rect] = RectSize
module.Write[Datatypes.TweenInfo] = WriteTweenInfo
module.Read[Datatypes.TweenInfo] = ReadTweenInfo
module.Size[Datatypes.TweenInfo] = TweenInfoSize
module.Write[Datatypes.boolean] = WriteBoolean
module.Read[Datatypes.boolean] = ReadBoolean
module.Size[Datatypes.boolean] = BooleanSize
module.Write[Datatypes.number] = WriteNumber
module.Read[Datatypes.number] = ReadNumber
module.Size[Datatypes.number] = NumberSize
module.Write[Datatypes.table] = WriteTable
module.Read[Datatypes.table] = ReadTable
module.Size[Datatypes.table] = TableSize
module.Write[Datatypes.BrickColor] = WriteBrickColor
module.Read[Datatypes.BrickColor] = ReadBrickColor
module.Size[Datatypes.BrickColor] = BrickColorSize
module.Write[Datatypes.EnumItem] = WriteEnumItem
module.Read[Datatypes.EnumItem] = ReadEnumItem
module.Size[Datatypes.EnumItem] = EnumItemSize
module.Write[Datatypes.buffer] = WriteBuffer
module.Read[Datatypes.buffer] = ReadBuffer
module.Size[Datatypes.buffer] = BufferSize
module.Size[Datatypes["nil"]] = NilSize
          
return module
