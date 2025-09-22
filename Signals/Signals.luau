--!strict
--!native
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/03/25
	Updated: 2025/09/22
	
	The purpose of this module is to create signals and connections similiar to those of
	Roblox (RBXScriptConnections and RBXScriptSignals) but without the need of having to deal with actual instances.
]]

local module = {}

--Variables--
local Utility = script.Utility
local TableUtilities = require(Utility.TableUtilities)


--Types--
type Callback<A...> = (A...) -> ()
type ConnectionType = "c" | "o" | "p" -- Connected/Once/Parallel

type ConnectionPrivate<A...> = {
	__Previous: Connection?,
	__Next: Connection?,
	__Signal: __Signal<A...>,
	__Func: Callback<A...>,
}

export type Connection = {
	Connected: boolean,
	Type: ConnectionType,
	
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
}

type __Connection<A...> = Connection & ConnectionPrivate<A...>

type SignalPrivate<A...> = {
	__Head: __Connection<A...>?,
	__Tail: __Connection<A...>?,
	__Yielded: {thread},
	__YieldedCount: number,
	__Cached: thread?,
}

export type Signal<A...> = {
	Connect: (self: Signal<A...>, f: Callback<A...>) -> Connection,
	ConnectParallel: (self: Signal<A...>, f: Callback<A...>) -> Connection,
	DisconnectAll: (self: Signal<A...>) -> (),
	Wait: (self: Signal<A...>) -> A...,
	Once: (self: Signal<A...>, f: Callback<A...>) -> Connection,
	Fire: (self: Signal<A...>, A...) -> (),
	GetConnections: (self: Signal<A...>) -> {Connection},
	Destroy: (self: Signal<A...>) -> (),
}

type __Signal<A...> = SignalPrivate<A...> & Signal<A...>
type AnySignal = __Signal<...any>
type AnyConnection = __Connection<...any>


--Private--
--Inserts new connection into its signal.
local function Insert<A...>(connection: __Connection<A...>, signal: __Signal<A...>): ()
	if signal.__Head then
		(signal.__Tail :: __Connection<A...>).__Next = connection
		connection.__Previous = signal.__Tail
		signal.__Tail = connection
	else
		signal.__Head = connection
		signal.__Tail = connection
	end
end

--Runs once signal
local function Once<A...>(c: __Connection<A...>, ...: A...): ()
	c.__Func(...)
	c:Disconnect()
end

--Runs parallel signal
local function Parallel<A...>(c: __Connection<A...>, ...: A...): ()
	task.desynchronize()
	c.__Func(...)
	task.synchronize()
end

--Receives events in cached coroutine
local function Receive<A...>(self: __Signal<A...>, f: (A...) -> (), ...: A...): ()
	self.__Cached = nil
	f(...)
	self.__Cached = coroutine.running()
	f(coroutine.yield())
end

--Methods--
--Connection
local Connection: AnyConnection = {} :: AnyConnection

--Disconnects connection from signal, preventing its callback from being called again
function Connection.Disconnect(self: Connection): ()
	self.Connected = false
	
	local __self: AnyConnection = self :: AnyConnection
	
	if not __self.__Previous and not __self.__Next then
		__self.__Signal.__Head = nil
		__self.__Signal.__Tail = nil
		return
	end
	
	if __self.__Previous then
		(__self.__Previous :: AnyConnection).__Next = __self.__Next;
		(__self.__Next :: AnyConnection).__Previous = __self.__Previous
		
		if __self.__Signal.__Tail == __self then
			__self.__Signal.__Tail = __self.__Next :: AnyConnection? or __self.__Previous :: AnyConnection?
		end
	else
		__self.__Signal.__Head = __self.__Next :: AnyConnection?
		
		if __self.__Next then
			(__self.__Next :: AnyConnection).__Previous = nil
		else
			__self.__Signal.__Tail = nil
		end
	end
end

--Clears connection object
function Connection.Destroy(self: Connection): ()
	self:Disconnect()
	table.clear(self)
end

--Signal
local Signal: AnySignal = {} :: AnySignal

--Connects a function to be ran whenever the signal is fired. Returns a connection object
function Signal.Connect<A...>(self: Signal<A...>, f: Callback<A...>): Connection
	assert(typeof(f) == "function", "Argument is not of type function")
	
	local __self: __Signal<A...> = self :: __Signal<A...>
	local Connection: __Connection<A...> = TableUtilities.DeepCopy(Connection)
	Connection.Connected = true
	Connection.Type = "c"
	Connection.__Signal = __self
	Connection.__Func = f
	
	Insert(Connection, __self)
	
	return Connection :: Connection
end

--Connects a function to be ran in parallel whenever the signal is fired. Returns a connection object
function Signal.ConnectParallel<A...>(self: Signal<A...>, f: Callback<A...>): Connection
	assert(typeof(f) == "function", "Argument is not of type function")
	
	local __self: __Signal<A...> = self :: __Signal<A...>
	local Connection: __Connection<A...> = TableUtilities.DeepCopy(Connection)
	Connection.Connected = true
	Connection.Type = "p"
	Connection.__Signal = self :: AnySignal
	Connection.__Func = f
	Insert(Connection, __self)
	return Connection :: Connection
end

--Disconnects ALL related connections
function Signal.DisconnectAll<A...>(self: Signal<A...>): ()
	local Connection: AnyConnection? = (self :: __Signal<A...>).__Head
	
	while Connection do
		Connection:Disconnect()
		Connection = Connection.__Next :: AnyConnection?
	end
end

--Yields current thread until the signal is fired
function Signal.Wait<A...>(self: Signal<A...>): A...
	local CurrentThread: thread = coroutine.running()
	local __self: __Signal<A...> = self :: __Signal<A...>
	
	__self.__YieldedCount += 1
	__self.__Yielded[__self.__YieldedCount] = CurrentThread
	
	return coroutine.yield()
end

--Connects a function that will be called once and then disconnected when signal is fired.
function Signal.Once<A...>(self: Signal<A...>, f: Callback<A...>): Connection
	assert(typeof(f) == "function", "Argument is not of type function")
	
	local __self: __Signal<A...> = self :: __Signal<A...>
	local Connection: __Connection<A...> = TableUtilities.DeepCopy(Connection)
	Connection.Connected = true
	Connection.Type = "o"
	Connection.__Signal = __self
	Connection.__Func = f
	Insert(Connection, __self)
	return Connection :: Connection
end

--Fires signal and creates threads for each connection. Once connections will be ran and then disconnected.
function Signal.Fire<A...>(self: Signal<A...>, ...: A...): ()
	local __self: __Signal<A...> = self :: __Signal<A...>
	
	if __self.__YieldedCount > 0 then
		for i: number = 1, __self.__YieldedCount do
			coroutine.resume(__self.__Yielded[i], ...)
		end
		table.clear(__self.__Yielded)
		__self.__YieldedCount = 0
	end
	
	local Connection: __Connection<A...>? = __self.__Head
	while Connection do
		if Connection.Type == "c" then
			coroutine.resume(__self.__Cached or coroutine.create(Receive), __self, Connection.__Func, ...)
		elseif Connection.Type == "o" then
			coroutine.resume(__self.__Cached or coroutine.create(Receive), __self, Once, Connection, ...)
		elseif Connection.Type == "p" then
			coroutine.resume(__self.__Cached or coroutine.create(Receive), __self, Parallel, Connection, ...)
		end
		
		Connection = Connection.__Next :: __Connection<A...>?
	end
end

--Returns table with all connections
function Signal.GetConnections<A...>(self: Signal<A...>): {Connection}
	local __self: __Signal<A...> = self :: __Signal<A...>
	local Connections: {Connection} = {}
	local Amount: number = 0
	local Current: __Connection<A...>? = __self.__Head
	
	while Current do
		Amount += 1
		Connections[Amount] = Current
		Current = Current.__Next :: __Connection<A...>
	end
	
	return Connections
end

--Clears signal object
function Signal.Destroy<A...>(self: Signal<A...>): ()
	self:DisconnectAll()
	table.clear(self)
end

--Constructor--

--[[
	Creates a new signal object. To use specific arguments for firing the signal, you need to typecast the signal.
	Example: local NewSignal: Signals.Signal<string, number> = Signals.New().
]]
function module.New(): AnySignal
	local NewSignal: AnySignal = TableUtilities.DeepCopy(Signal)
	NewSignal.__Yielded = {}
	NewSignal.__YieldedCount = 0
	NewSignal.__Cached = coroutine.create(Receive)
	return NewSignal
end

return module
