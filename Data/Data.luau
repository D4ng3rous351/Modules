--!strict
--[[
	Author: D4ng3rous351
	Created: 2025/06/12
	Updated: 2025/09/06
	
	The purpose of this module is to be an all-round system for saving and loading
	player data.
]]

assert(game:GetService("RunService"):IsServer(), "The module can only be required on the server.")

local module = {}

--Variables--
--Folders
local Utility = script.Utility

--Utility
local TableUtilities = require(Utility.TableUtilities)


--Types--
--Private Types
type SortedEntry = {
	key: string,
	value: number,
}

export type SortedPages = {[number]: {SortedEntry}}
type ErrorHandler<A...> = (A...) -> ()
type Transform<T> = (T?, DataStoreKeyInfo) -> (T, DataStoreKeyInfo)
type AsyncResult = {
	Success: boolean,
	Error: string?,
}

--[[
	Attempts:	amount of times to retry the operation if it fails.
	Interval:	amount of seconds to yield after a failed attempt.
	OnFail:		called when the function fails on all attempts.
]]
type BaseRequest<A...> = {
	Attempts: number,
	Interval: number,
	OnFail: ErrorHandler<A...>?,
}

type SortedRequest = {
	Store: OrderedDataStore,
	Amount: number,
	Ascending: boolean,
}

--[[
	Template:		the data to use if the player has no data (never played before). The template can be any
					datastore compatible value (no instances or functions or nil, etc).
	Transform:		optional transform function for UpdateAsync.
	UpdateOldKeys:	Whether new keys in template should be added to data if not found.
	RemoveOldKeys:	Whether old keys not found in template should be removed from data.
]]
type DataStoreRequest<T> = {
	Template: T,
	Store: DataStore,
	GetOptions: DataStoreGetOptions?,
	Transform: Transform<T>?,
	UpdateOldKeys: boolean,
	RemoveOldKeys: boolean,
}

type OrderedStoreRequest = {
	Store: OrderedDataStore,
	GetOptions: DataStoreGetOptions?,
	Transform: Transform<number>?,
}

--Public Types
export type DataStoreRequestInfo<T, A...> = DataStoreRequest<T> & BaseRequest<A...>
export type SortedRequestInfo<A...> = BaseRequest<A...> & SortedRequest
export type OrderedStoreRequestInfo<A...> = BaseRequest<A...> & OrderedStoreRequest


--Private--
--Calls async function and returns results
local function CallAsync<A..., R...>(f: (A...) -> R..., info: BaseRequest<...any>, ...: A...): (AsyncResult, R...) | (AsyncResult)
	local Returns: {any}
	local Attempts: number = 0
	local Result: AsyncResult = {Success = false}
	repeat
		Returns = {pcall(f, ...)}
		Result.Success = Returns[1]
		Attempts += 1
		task.wait(info.Interval)
	until Result.Success or Attempts >= info.Attempts
	
	if not Result.Success then
		Result.Error = Returns[2]
		return Result
	end
	
	table.remove(Returns, 1)
	
	return Result, table.unpack(Returns)
end

--Catches any errors and calls error handler
local function Catch<A...>(info: BaseRequest<(string, A...)>, message: string, ...: A...): ()
	if not info.OnFail then return end
	info.OnFail(message, ...)
end


--Public--

--[[
	Returns player's data from the datastore.
	<strong>player:</strong> player whose data to retrieve.
	<strong>info:</strong> meta data to pass about the request.
	<strong>...:</strong> additional arguments to pass to the callback.
]]
function module.GetAsync<T, A...>(player: Player, info: DataStoreRequestInfo<T, (string, A...)>, ...: A...): (T?, DataStoreKeyInfo?)
	assert(typeof(player) == "Instance" or player.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(info) == "table", "Argument is not of type table")
	if info.OnFail ~= nil then assert(typeof(info.OnFail) == "function") end
	if info.GetOptions ~= nil then
		assert(
			typeof(info.GetOptions) == "Instance" or info.GetOptions.ClassName == "DataStoreGetOptions",
			"Argument is not of type DataStoreGetOptions"
		)
	end
	
	local Result: AsyncResult, PlayerData: any, KeyInfo: DataStoreKeyInfo? = CallAsync(
		info.Store.GetAsync,
		info :: any,
		info.Store,
		tostring(player.UserId),
		info.GetOptions
	)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
		return nil, nil
	end
	
	local TypeOfData: string = typeof(PlayerData)
	
	if TypeOfData == typeof(info.Template) then
		if TypeOfData == "table" and info.UpdateOldKeys then
			TableUtilities.UpdateTable(PlayerData, info.Template, true, info.RemoveOldKeys)
		end
	else
		if typeof(info.Template) == "table" then
			PlayerData = TableUtilities.DeepCopy(info.Template)
		else
			PlayerData = info.Template
		end
	end
	
	return PlayerData, KeyInfo
end

--[[
	Updates a player's data to newly provided value in the datastore.
	<strong>player:</strong> player whose data to update.
	<strong>new:</strong> new value of player's data.
	<strong>info:</strong> meta data to pass about the request.
	<strong>transform:</strong> optional transform function for UpdateAsync.
	<strong>...:</strong> additional arguments to pass to the callback.
]]
function module.UpdateAsync<T, A...>(player: Player, new: T, info: DataStoreRequestInfo<T, (string, A...)>, ...: A...): ()
	assert(typeof(player) == "Instance" or player.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(info) == "table", "Argument is not of type table")
	if info.OnFail ~= nil then assert(typeof(info.OnFail) == "function", "Argument is not of type function") end
	if info.Transform ~= nil then assert(typeof(info.Transform) == "function", "Argument is not of type function") end
	
	local Result: AsyncResult = CallAsync(
		info.Store.UpdateAsync,
		info :: any,
		info.Store,
		tostring(player.UserId),
		info.Transform or function(): T return new end
	)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
	end
end

--[[
	Returns a player's data from the ordered data store with provided name.
	<strong>player:</strong> player whose data to retrieve from ordered datastore.
	<strong>info:</strong> meta data to pass about the request
	<strong>...:</strong> additional arguments to pass to the callback.
]]
function module.GetOrderedAsync<A...>(player: Player, info: OrderedStoreRequestInfo<(string, A...)>, ...: A...): (number?, DataStoreKeyInfo?)
	assert(typeof(player) == "Instance" or player.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(info) == "table", "Argument is not of type table")
	if info.OnFail ~= nil then assert(typeof(info.OnFail) == "function", "Argument is not of type function") end
	if info.GetOptions ~= nil then
		assert(
			typeof(info.GetOptions) == "Instance" or info.GetOptions.ClassName == "DataStoreGetOptions",
			"Argument is not of type DataStoreGetOptions"
		)
	end
	
	local Result: AsyncResult, PlayerData: number?, KeyInfo: DataStoreKeyInfo? = CallAsync(
		info.Store.GetAsync,
		info :: any,
		info.Store,
		tostring(player.UserId),
		info.GetOptions
	)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
		return nil, nil
	end
	
	return PlayerData or 0, KeyInfo
end

--[[
	Sets player's data in ordered data store to provided value
	<strong>player:</strong> player whose data to update in the ordered data store.
	<strong>new:</strong> new value of player's data.
	<strong>info:</strong> meta data to pass about the request
	<strong>transform:</strong> optional transform function for UpdateAsync.
	<strong>...:</strong> additional arguments to pass to the callback.
]]
function module.UpdateOrderedAsync<A...>(player: Player, new: number, info: OrderedStoreRequestInfo<(string, A...)>, ...: A...): ()
	assert(typeof(player) == "Instance" or player.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(new) == "number", "Argument is not of type number")
	assert(typeof(info) == "table", "Argument is not of type table")
	if info.OnFail ~= nil then assert(typeof(info.OnFail) == "function", "Argument is not of type function") end
	if info.Transform ~= nil then assert(typeof(info.Transform) == "function", "Argument is not of type function") end
	
	local Result: AsyncResult = CallAsync(
		info.Store.UpdateAsync,
		info :: any,
		info.Store,
		tostring(player.UserId),
		info.Transform or function(): number return new end
	)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
	end
end

--[[
	Returns the specified amount of players' data from the ordered data store with the provided name.
	<strong>info:</strong> meta data to pass about the request.
	<strong>...:</strong> additional arguments to pass to the callback.
]]
function module.GetSortedAsync<A...>(info: SortedRequestInfo<(string, A...)>, ...: A...): SortedPages?
	assert(typeof(info) == "table", "Argument is not of type table")
	if info.OnFail ~= nil then assert(typeof(info.OnFail) == "function", "Argument is not of type function") end
	
	local Result: AsyncResult, Temp: DataStorePages? = CallAsync(info.Store.GetSortedAsync, info :: any, info.Store, info.Ascending, info.Amount)
	local Attempts: number = 0
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
		return nil
	end
	
	local Sorted: DataStorePages = Temp :: DataStorePages
	local Pages: SortedPages = {}
	
	Pages[1] = Sorted:GetCurrentPage()
	
	if not Sorted.IsFinished then
		local CurrentPage: number = 2
		
		while not Sorted.IsFinished do
			Pages[CurrentPage] = Sorted:GetCurrentPage()
			CurrentPage += 1
			Sorted:AdvanceToNextPageAsync()
		end
	end
	
	return Pages
end

--[[
	Creates a new base request to create other requests with.
	<strong>attempts:</strong> amount of times to attempt the operation before failing.
	<strong>interval:</strong> amount of seconds to wait between each failed attempt.
	<strong>callback:</strong> optional callback function to call when all attempts fail.
	NOTE: This function is not necessary to call, you can just create requests through assignment too.
]]
function module.CreateBaseRequest<A...>(attempts: number, interval: number, callback: ErrorHandler<A...>?): BaseRequest<A...>
	assert(typeof(attempts) == "number", "Argument is not of type number")
	assert(typeof(interval) == "number", "Argument is not of type number")
	if callback ~= nil then assert(typeof(callback) == "function", "Argument is not of type function") end
	
	return {
		Attempts = attempts,
		Interval = interval,
		callback = callback,
	}
end

return module
