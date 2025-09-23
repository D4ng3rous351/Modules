--!strict
--[[
	Author: D4ng3rous351 (1618460770)
	Created: 2025/09/06
	Updated: -
	
	The purpose of this module is to serve as an easy way to control purchases of gamepasses and developer products.
]]

assert(game:GetService("RunService"):IsServer(), "The module can only be required on the server.")

local module = {}

--Services--
local MarketplaceService = game:GetService("MarketplaceService")


--Variables--
--Misc
local PurchaseCallbacks: PurchaseCallbacks = {
	Gamepasses = {},
	Products = {},
}


--Types--
--Private types--
type Callback<A...> = (A...) -> ()

--[[
	Player: Player who made purchase.
	number: ID of purchased product.
]]
type PassCallback = Callback<Player, number>
type ProductCallback = Callback<Receipt>
type CallbackPair<A...> = {
	ID: number,
	Callbacks: {Callback<A...>},
}

type PassCallbackPair = CallbackPair<Player, number>
type ProductCallbackPair = CallbackPair<Receipt>
type PurchaseCallbacks = {
	Gamepasses: {PassCallbackPair},
	Products: {ProductCallbackPair},
}
type ProductOrPass = "p" | "g"
type AsyncResult = {
	Success: boolean,
	Error: string?,
}

--Public types--
export type Receipt = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	ProductPurchaseChannel: Enum.ProductPurchaseChannel,
}

export type RequestInfo<A...> = {
	Attempts: number,
	Interval: number,
	OnFail: Callback<A...>?,
}

export type ProductInfo = {
	AssetId: number,
	AssetTypeId: number,
	Created: string,
	Creator: {
		CreatorTargetId: number,
		Id: number,
	},
	Description: string,
	DisplayDescription: string,
	DisplayIconImageAssetId: number,
	DisplayName: string,
	IconImageAssetId: number,
	IsForSale: boolean,
	IsLimited: boolean,
	IsLimitedUnique: boolean,
	IsNew: boolean,
	IsPublicDomain: boolean,
	MinimumMembershipLevel: number,
	Name: string,
	PriceInRobux: number,
	ProductId: number,
	ProductType: string,
	TargetId: number,
	UniverseId: number,
	Updated: string
}


--Private--

--Calls async function and returns results
local function CallAsync<A..., R...>(f: (A...) -> R..., info: RequestInfo<(string, A...)>, ...: A...): (AsyncResult, R...) | (AsyncResult)
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
local function Catch<A...>(info: RequestInfo<(string, A...)>, message: string, ...: A...): ()
	if not info.OnFail then return end
	info.OnFail(message, ...)
end

--Calls appropriate callbacks for when a dev product is purchased
local function ProcessReceipt(receipt: Receipt): Enum.ProductPurchaseDecision
	for i: number = 1, #PurchaseCallbacks.Products do
		if PurchaseCallbacks.Products[i].ID ~= receipt.ProductId then continue end
		
		for _: number, callback: ProductCallback in PurchaseCallbacks.Products[i].Callbacks do
			coroutine.resume(coroutine.create(callback), receipt)
		end
	end
	
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--Handles calling appropriate functions when a gamepass is purchased
local function GamepassPurchasedHandler(player: Player, ID: number, purchased: boolean): ()
	if not purchased then return end
	
	for i: number = 1, #PurchaseCallbacks.Gamepasses do
		if PurchaseCallbacks.Gamepasses[i].ID ~= ID then continue end
		
		for _: number, callback: PassCallback in PurchaseCallbacks.Gamepasses[i].Callbacks do
			coroutine.resume(coroutine.create(callback), player, ID)
		end
	end
end

--Sets up and returns module
local function Setup(): typeof(module)
	MarketplaceService.ProcessReceipt = ProcessReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(GamepassPurchasedHandler)
	return module
end

--Returns index of callback pair based on product ID and its type, if found
@native local function GetPairIndexByID(ID: number, option: ProductOrPass): number?
	if option == "g" then
		for i: number = 1, #PurchaseCallbacks.Gamepasses do
			if PurchaseCallbacks.Gamepasses[i].ID == ID then return i end
		end
	else
		for i: number = 1, #PurchaseCallbacks.Products do
			if PurchaseCallbacks.Products[i].ID == ID then return i end
		end
	end
	
	return nil
end


--Public--

--[[
	Returns whether player owns gamepass with specified ID.
	<strong>player:</strong> player to query.
	<strong>ID:</strong> gamepass ID.
	<strong>info:</strong> additional parameters for making the request.
	<strong>...:</strong> optional extra arguments to pass to the callback.
]]
function module.OwnsGamepassAsync<A...>(player: Player, ID: number, info: RequestInfo<(string, A...)>, ...: A...): boolean?
	assert(typeof(player) == "Instance" or player.ClassName == "Player", "Argument is not of type Player")
	assert(typeof(ID) == "number", "Argument is not of type number")
	assert(typeof(info) == "table", "Argument is not of type RequestInfo")
	
	local Result: AsyncResult, Owned: boolean? = CallAsync(MarketplaceService.UserOwnsGamePassAsync, info, MarketplaceService, player.UserId, ID)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
	end
	
	return Owned
end

--[[
	Returns product info based on asset ID.
	<strong>ID:</strong> ID of asset.
	<strong>info:</strong> additional parameters for making the request.
]]
function module.GetProductInfoAsync<A...>(ID: number, infotype: Enum.InfoType?, info: RequestInfo<(string, A...)>, ...: A...): ProductInfo?
	assert(typeof(ID) == "number", "Argument is not of type number")
	if infotype ~= nil then assert(typeof(infotype) == "EnumItem", "Argument is not of type EnumItem") end
	assert(typeof(info) == "table", "Argument is not of type RequestInfo")
	
	local Result: AsyncResult, Info: ProductInfo? = CallAsync(MarketplaceService.GetProductInfo, info, MarketplaceService, ID, infotype)
	
	if not Result.Success then
		Catch(info, Result.Error :: string, ...)
	end
	
	return Info
end

--[[
	Adds a callback function for a gamepass or product being purchased and returns the pair's index.
	<strong>f:</strong> callback function to be called when purchased.
	<strong>ID:</strong> asset ID of the gamepass or product.
	<strong>purchasetype:</strong> whether it is a gamepass or product.
]]
@native function module.AddPurchaseCallback(f: PassCallback | ProductCallback, ID: number, purchasetype: ProductOrPass): number
	assert(typeof(f) == "function", "Argument is not of type function")
	assert(typeof(ID) == "number", "Argument is not of type number")
	assert(purchasetype == "g" or purchasetype == "p", "Invalid purchase type")
	
	local Callbacks: {ProductCallbackPair} | {PassCallbackPair} = if purchasetype == "p" then PurchaseCallbacks.Products else PurchaseCallbacks.Gamepasses
	local Index: number = GetPairIndexByID(ID, purchasetype) or -1
	
	if Index ~= -1 then
		if not table.find(Callbacks[Index].Callbacks, f) then
			Callbacks[Index].Callbacks[#Callbacks[Index].Callbacks + 1] = f
		end
	else
		local Pair: ProductCallbackPair | PassCallbackPair = {
			Callbacks = {},
			ID = ID,
		}
		
		Index = #Callbacks + 1
		Callbacks[Index] = Pair
		Pair.Callbacks[1] = f
	end
	
	return Index
end
  
--[[
	Removes a callback function for a specific gamepass or product.
	<strong>ID:</strong> id of product to remove callback for.
	<strong>index:</strong> index of callback to remove. If ommitted, it will remove all callbacks for the product.
	<strong>purchasetype:</strong> whether it is a gamepass or product.
]]
@native function module.RemovePurchaseCallback(ID: number, index: number?, purchasetype: ProductOrPass): ()
	assert(typeof(ID) == "number", "Argument is not of type number")
	if index ~= nil then assert(typeof(index) == "number", "Argument is not of type number") end
	assert(purchasetype == "g" or purchasetype == "p", "Invalid purchase type")
	
	local Callbacks: {ProductCallbackPair} | {PassCallbackPair} = if purchasetype == "p" then PurchaseCallbacks.Products else PurchaseCallbacks.Gamepasses
	local PairIndex: number? = GetPairIndexByID(ID, purchasetype)
	if not PairIndex then return end
	
	if not index then
		table.remove(Callbacks, PairIndex)
		return
	end
	
	if Callbacks[PairIndex].Callbacks[index] then
		table.remove(Callbacks[PairIndex].Callbacks, index)
	end
end
    
--[[
	Returns all purchases' callbacks.
]]
function module.GetPurchaseCallbacks(): PurchaseCallbacks
	return PurchaseCallbacks
end
    
return Setup()
