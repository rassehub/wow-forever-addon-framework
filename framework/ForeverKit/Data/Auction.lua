local ADDON, ns = ...
local FK = ns.FK

---@module Auction  Auction prices through Auctionator's public API v1 (runtime optional dependency: `## OptionalDeps: Auctionator`; its licence forbids copying, so only these documented calls are used). FK.Auction.Available() -> bool. FK.Auction.Price(itemIDOrLink) -> copper or nil (nil also when never scanned; prices are as old as the user's last scan). FK.Auction.Search({ names }) starts a search; the auction house must be open. Calls are pcall'd: a failure answers nil and warns once.
local Auction = {}
FK.Auction = Auction

local function api() return Auctionator and Auctionator.API and Auctionator.API.v1 end

local function safe(fn, ...)
	local ok, a = pcall(fn, ...)
	if ok then return a end
	FK:Warn("auction-error", "Auctionator call failed: " .. tostring(a))
end

function Auction.Available() return api() ~= nil end

function Auction.Price(item)
	local A = api()
	if not A then return nil end
	if type(item) == "number" then return safe(A.GetAuctionPriceByItemID, ADDON, item) end
	return safe(A.GetAuctionPriceByItemLink, ADDON, item)
end

function Auction.Search(names)
	local A = api()
	if not A then return false end
	local ok, err = pcall(A.MultiSearch, ADDON, names)
	if not ok then FK:Warn("auction-error", "Auctionator call failed: " .. tostring(err)) end
	return ok
end
