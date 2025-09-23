--!strict
--!native
--[[
	Author: D4ng3rous351
	Created: 2025/06/07
	Updated: 2025/09/23
	The purpose of this module is to be an all purpose module for replicating data to and from clients
	and to provide all necessary features and optimization.
	
	NOTE: When receiving data from remotes, argument types should still be verified.
]]

local module = {}

--Services--
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")


--Variables--
--Folders
local Remotes: Folder
local Utility = script.Utility

--Utility
local Serialize = require(Utility.Serialize)

--Misc
local IsServer: boolean = RunService:IsServer()
local RemoteEvent: RemoteEvent
local RemoteFunction: RemoteFunction
local UnreliableRemoteEvent: UnreliableRemoteEvent
local RemoteConnections: {{GenericConnection}} = {}
local UnreliableConnections: {{GenericConnection}} = {}
local InvokeConnections: {GenericConnection} = {}


--Types--
type Callback<A..., R...> = (A...) -> R...
type LimitPassedCallback = (Player?) -> ()
type Unpacked = {
	Success: boolean,
	Args: {any},
}

--[[
	re: remote event
	u: unreliable remote event
	rf: remote function
]]
type ConnectionTypes = "re" | "u" | "rf"

--[[
	Callback: Function to call when a packet is received.
	SizeLimit: Maximum buffer size allowed to be received in bytes.
	OnLimitPassed: Function to be called when received buffer is over size limit.
]]
export type Connection<A..., R...> = {
	Callback: Callback<A..., R...>,
	SizeLimit: number?,
	OnLimitPassed: LimitPassedCallback?,
}

--[[
	Time: Time in seconds until function times out.
	OnTimeOut: Callback function for when function times out.
		number: Topic number.
		A...: Additional arguments to pass to callback.
]]
export type Timeout<A...> = {
	Time: number,
	Callback: Callback<(number, A...)>,
}

type GenericConnection = Connection<...any, ...any>


--Private--
--Returns whether the length of the buffer is over the size limit of the connection.
local function LimitPassed<A..., R...>(connection: Connection<A..., R...>, bufferlength: number): boolean
	if not connection.SizeLimit or not connection.OnLimitPassed then return false end
	if bufferlength <= connection.SizeLimit then return false end
	return true
end

--Safely unpacks buffer.
local function SafeUnpack(b: buffer, offset: number?): Unpacked
	local Result: {any} = {pcall(Serialize.Deserialize, b, offset)}
	local Success: boolean = table.remove(Result, 1) :: boolean
	
	return {
		Success = Success,
		Args = Result,
	}
end

--Handles a callback for a connection.
local function HandleCallback(connection: GenericConnection, len: number, player: Player?, ...: any): ()
	if LimitPassed(connection, len) then
		(connection.OnLimitPassed :: LimitPassedCallback)(player)
		return
	end
	connection.Callback(...)
end

--Handles calling callbacks and returning from remote function.
local function HandleCallbacks(topic: number, option: ConnectionTypes, result: Unpacked, player: Player?, length: number): buffer?
	local Connection: {GenericConnection} | GenericConnection
	
	if option == "re" then
		if not RemoteConnections[topic] then return end
		Connection = RemoteConnections[topic]
	elseif option == "u" then
		if not UnreliableConnections[topic] then return end
		Connection = UnreliableConnections[topic]
	else
		if not InvokeConnections[topic] then return end
		Connection = InvokeConnections[topic]
	end
	
	if option == "rf" then
		return Serialize.Serialize(nil, (Connection :: GenericConnection).Callback(table.unpack(result.Args)))
	else
		local Thread: thread
		for _: number, connection: GenericConnection in Connection :: {GenericConnection} do
			Thread = coroutine.create(HandleCallback)
			coroutine.resume(Thread, connection, length, player, table.unpack(result.Args))
		end
	end
	
	return nil
end

--Handles any events from the remotes.
local function EventHandler(player: Player?, data: buffer, option: ConnectionTypes): buffer?
	if player ~= nil then if typeof(player) ~= "Instance" or player.ClassName ~= "Player" then return nil end end
	if typeof(data) ~= "buffer" or buffer.len(data) <= 1 then return nil end
	local Topic: number = buffer.readu8(data, 0)
	local Result: Unpacked = SafeUnpack(data, 1)
	if not Result.Success then return nil end
	
	return HandleCallbacks(Topic, option, Result, player, buffer.len(data))
end

--Handles any invokes from the remote function on the server.
local function ReceiveInvokesServer(player: Player, data: buffer): buffer?
	return EventHandler(player, data, "rf")
end

--Handles any events from the remote event on the server.
local function ReceiveEventsServer(player: Player, data: buffer): ()
	EventHandler(player, data, "re")
end

--Handles any events from the unreliable remote event on the server.
local function ReceiveUnreliableServer(player: Player, data: buffer): ()
	EventHandler(player, data, "u")
end

--Handles any invokes from the remote function on the client.
local function ReceiveInvokesClient(data: buffer): buffer?
	return EventHandler(nil, data, "rf")
end

--Handles any events from the remote event on the client.
local function ReceiveEventsClient(data: buffer): ()
	EventHandler(nil, data, "re")
end

--Handles any events from the unreliable remote event on the client.
local function ReceiveUnreliableClient(data: buffer): ()
	EventHandler(nil, data, "u")
end

--Handles response from remote function.
local function HandleResponse(main: thread, out: thread?, player: Player?, b: buffer): ()
	local Response: buffer? = if IsServer then RemoteFunction:InvokeClient(player :: Player, b) else RemoteFunction:InvokeServer(b)
	if out then coroutine.close(out) end
	
	local Result: Unpacked? = if Response then SafeUnpack(Response) else nil
	
	if Result then
		coroutine.resume(main, table.unpack(Result.Args))
	else
		coroutine.resume(main)
	end
end
    
--Handles response timing out.
local function HandleTimeout(topic: number, main: thread, response: thread, out: Timeout<()>): ()
	task.wait(out.Time)
	coroutine.close(response)
	coroutine.resume(main)
	out.Callback(topic)
end
    
--Sets up folders and returns module.
local function Setup(): typeof(module)
	if IsServer then
		Remotes = script.Remotes
		Remotes.Parent = ReplicatedStorage
	else
		Remotes = ReplicatedStorage.Remotes
	end
	
	RemoteEvent = (Remotes :: any).RemoteEvent
	RemoteFunction = (Remotes :: any).RemoteFunction
	UnreliableRemoteEvent = (Remotes :: any).UnreliableRemoteEvent
	
	if IsServer then
		RemoteFunction.OnServerInvoke = ReceiveInvokesServer
		RemoteEvent.OnServerEvent:Connect(ReceiveEventsServer)
		UnreliableRemoteEvent.OnServerEvent:Connect(ReceiveUnreliableServer)
	else
		RemoteFunction.OnClientInvoke = ReceiveInvokesClient
		RemoteEvent.OnClientEvent:Connect(ReceiveEventsClient)
		UnreliableRemoteEvent.OnClientEvent:Connect(ReceiveUnreliableClient)
	end
	
	return module
end

    
--Public--
    
--[[
	Adds the provided connection to the topic.
	<strong>topic:</strong> topic to add connection to. Can be any integer value. (acts like enum values)
	<strong>connection:</strong> connection to add to topic.
	<strong>option:</strong> remote to add connection to.
	Warning: Will overwrite existing connection if there is already one for the remote function.
]]
function module.Add<A..., R...>(topic: number, connection: Connection<A..., R...>, option: ConnectionTypes): ()
	assert(typeof(topic) == "number", "Argument is not of type number")
	assert(topic % 1 == 0, "Topic must be an integer")
	assert(typeof(connection) == "table", "Argument is not of type Connection")
	assert(option == "rf" or option == "re" or option == "u", "Invalid connection type specifier")
	
	local Connections: {GenericConnection} = {}
	
	if option == "rf" then
		InvokeConnections[topic] = connection
	elseif option == "re" then
		if not RemoteConnections[topic] then
			RemoteConnections[topic] = Connections
		else
			Connections = RemoteConnections[topic]
		end
		
		Connections[#Connections + 1] = connection
	else
		if not UnreliableConnections[topic] then
			UnreliableConnections[topic] = Connections
		else
			Connections = UnreliableConnections[topic]
		end
		Connections[#Connections + 1] = connection
	end
end
    
--[[
	Returns connection or table of connections associated with the provided topic.
	<strong>topic:</strong> topic to return the connections of.
	<strong>option:</strong> determines which remote's connections should be returned.
]]
function module.Get(topic: number, option: ConnectionTypes): ({GenericConnection} | GenericConnection)
	assert(typeof(topic) == "number", "Argument is not of type number")
	assert(option == "rf" or option == "re" or option == "u", "Invalid connection type specifier")
	
	if option == "rf" then return InvokeConnections[topic]
	elseif option == "re" then return RemoteConnections[topic]
	else return UnreliableConnections[topic]
	end
end
    
--[[
	Removes the connection for a certain topic for a remote.
	<strong>topic:</strong> topic to remove the connection(s) for.
	<strong>option:</strong> remote to remove connection from.
	<strong>connection:</strong> connection to remove.
	Warning: If connection is omitted, all connections to the topic for specified remote will be removed.
	If option is omitted, ALL connections to the topic will be removed.
]]
function module.Remove<A..., R...>(topic: number, option: ConnectionTypes?, connection: Connection<A..., R...>?): ()
	assert(typeof(topic) == "number", "Argument is not of type number")
	if option ~= nil then assert(option == "rf" or option == "re" or option == "u", "Invalid connection type specifier") end
	if connection ~= nil then assert(typeof(connection) == "table", "Argument is not of type Connection") end
	
	if option == "rf" then
		InvokeConnections[topic] = nil
	elseif option == "u" then
		if not UnreliableConnections[topic] then return end
		
		local Index: number? = table.find(UnreliableConnections[topic], connection :: GenericConnection)
		if not Index then return end
		
		UnreliableConnections[topic][Index] = nil
	elseif option == "re" then
		if not RemoteConnections[topic] then return end
		
		local Index: number? = table.find(RemoteConnections[topic], connection :: GenericConnection)
		if not Index then return end
		RemoteConnections[topic][Index] = nil
	elseif option == nil then
		InvokeConnections[topic] = nil
		RemoteConnections[topic] = nil
		UnreliableConnections[topic] = nil
	end
end
    
--[[
	Invokes the server on the specified topic and returns the result.
	<strong>topic:</strong> topic to invoke.
	<strong>timeout:</strong> time out that will be used if specified.
	<strong>...:</strong> arguments to fire to server.
]]
function module.Invoke(client: Player?, topic: number, timeout: Timeout<()>?, ...: any): ...any
	if IsServer then
		assert(typeof(client) == "Instance", "Argument is not of type player")
		assert(client.ClassName == "Player", "Argument is not of type player")
	else
		assert(client == nil, "Cannot invoke client from client")
	end
	
	assert(typeof(topic) == "number", "Argument is not of type number")
	if timeout ~= nil then assert(typeof(timeout) == "table", "Argument is not of type Timeout") end
	
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	
	local MainThread: thread = coroutine.running()
	local ResponseThread: thread = coroutine.create(HandleResponse)
	local TimeoutThread: thread? = if timeout then coroutine.create(HandleTimeout) else nil
	
	coroutine.resume(ResponseThread, MainThread, TimeoutThread, client, Buffer)
	if TimeoutThread then coroutine.resume(TimeoutThread :: thread, topic, MainThread, ResponseThread, timeout) end
	
	return coroutine.yield()
end
      
--[[
	Fires topic and arguments to server.
	<strong>topic:</strong> topic to fire.
	<strong>unreliable:</strong> whether or not the unreliable remote event should be used.
	<strong>...:</strong> arguments to fire.
]]
function module.FireServer(topic: number, unreliable: boolean?, ...: any): ()
	assert(IsServer == false, "FireServer can only be called from the client")
	assert(typeof(topic) == "number", "Argument is not of type number")
	if unreliable ~= nil then assert(typeof(unreliable) == "boolean", "Argument is not of type boolean") end
	
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	
	if not unreliable then
		RemoteEvent:FireServer(Buffer)
	else
		UnreliableRemoteEvent:FireServer(Buffer)
	end
end
      
--[[
	Fires arguments to specified player.
	<strong>client:</strong> player to fire.
	<strong>topic:</strong> topic to fire to.
	<strong>unreliable:</strong> whether or not the unreliable remote event should be used.
	<strong>...:</strong> arguments to fire to player.
]]
function module.FireClient(client: Player, topic: number, unreliable: boolean, ...: any): ()
	assert(IsServer == true, "FireClient can only be called from the server")
	assert(typeof(client) == "Instance", "Argument is not of type Player")
	assert(client.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(topic) == "number", "Argument is not of type number")
	if unreliable ~= nil then assert(typeof(unreliable) == "boolean", "Argument is not of type boolean") end
	
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	
	if not unreliable then
		RemoteEvent:FireClient(client, Buffer)
	else
		UnreliableRemoteEvent:FireClient(client, Buffer)
	end
end
      
--[[
	Fires arguments to all players.
	<strong>topic:</strong> topic to fire to.
	<strong>unreliable:</strong> whether or not the unreliable remote event should be used.
	<strong>...:</strong> arguments to fire to players.
]]
function module.FireAllClients(topic: number, unreliable: boolean, ...: any): ()
	assert(IsServer == true, "FireAllClients can only be called from the server")
	assert(typeof(topic) == "number", "Argument is not of type number")
	if unreliable ~= nil then assert(typeof(unreliable) == "boolean", "Argument is not of type boolean") end
	
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	
	if not unreliable then
		RemoteEvent:FireAllClients(Buffer)
	else
		UnreliableRemoteEvent:FireAllClients(Buffer)
	end
end
      
--[[
	Fires arguments to all players except ones in the array.
	<strong>blacklist:</strong> players to not fire.
	<strong>topic:</strong> topic to fire to.
	<strong>unreliable:</strong> whether or not the unreliable remote event should be used.
	<strong>...:</strong> arguments to fire to players.
]]
function module.FireAllExcept(blacklist: {Player}, topic: number, unreliable: boolean, ...: any): ()
	assert(IsServer == true, "FireAllExcept can only be called from the server")
	assert(typeof(blacklist) == "table", "Argument is not of type table")
	assert(typeof(topic) == "number", "Argument is not of type number")
	if unreliable ~= nil then assert(typeof(unreliable) == "boolean", "Argument is not of type boolean") end
	
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	
	local Clients: {Player} = Players:GetPlayers()
	
	for _: number, player: Player in Clients do
		if table.find(blacklist, player) then continue end
		
		if unreliable then
			UnreliableRemoteEvent:FireClient(player, Buffer)
		else
			RemoteEvent:FireClient(player, Buffer)
		end
	end
end
      
--[[
	Fires arguments to selected clients.
	<strong>clients:</strong> clients to fire.
	<strong>topic:</strong> topic to fire to.
	<strong>unreliable:</strong> whether or not the unreliable remote event should be used.
	<strong>...:</strong> arguments to fire to players.
]]
function module.FireClients(clients: {Player}, topic: number, unreliable: boolean, ...: any): ()
	assert(IsServer == true, "FireAllExcept can only be called from the server")
	assert(typeof(clients) == "table", "Argument is not of type table")
	assert(typeof(topic) == "number", "Argument is not of type number")
	if unreliable ~= nil then assert(typeof(unreliable) == "boolean", "Argument is not of type boolean") end
	local Buffer: buffer = Serialize.Serialize(1, ...)
	buffer.writeu8(Buffer, 0, topic)
	for _: number, player: Player in clients do
		if unreliable then
			UnreliableRemoteEvent:FireClient(player, Buffer)
		else
			RemoteEvent:FireClient(player, Buffer)
		end
	end
end
      
--[[
	Returns new blank connection with provided function as callback.
	<strong>callback:</strong> function to pass as callback.
	<strong>limit:</strong> buffer size limit.
	<strong>limitpassed:</strong> function to call when size limit is passed.
]]
function module.CreateConnection<A..., R...>(callback: Callback<A..., R...>, limit: number?, limitpassed: LimitPassedCallback?): Connection<A..., R...>
	assert(typeof(callback) == "function", "Argument is not of type function")
	
	if limit ~= nil then assert(typeof(limit) == "number" and limit > 0, "Invalid limit") end
	if limitpassed ~= nil then assert(typeof(limitpassed) == "function", "Argument is not of type function") end
	
	return {
		Callback = callback,
		SizeLimit = limit,
		OnLimitPassed = limitpassed,
	}
end
      
--[[
	Creates new timeout.
	<strong>timeout:</strong> time in seconds until time out.
	<strong>callback:</strong> called upon time out.
	<strong>...:</strong> additional arguments to pass to callback function.
]]
function module.CreateTimeout(timeout: number, callback: Callback<(number)>): Timeout<()>
	assert(typeof(timeout) == "number" and timeout == timeout, "Argument is not of type number")
	assert(typeof(callback) == "function", "Argument is not of type function")
	
	return {
		Time = timeout,
		Callback = callback,
	}
end
      
return Setup()
