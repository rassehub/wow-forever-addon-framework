-- Game data: the emulator's C_EncodingUtil, and the QuestieDB / Auctionator bridges against
-- stand-ins of their public APIs (the real QuestieDB is exercised by `fk data`, not here:
-- tests must not depend on what is installed).
local KIT = ROOT .. "/tests/fixtures/KitTest"

test("encoding: base64, zlib inflate and CBOR decode", function()
	local E = C_EncodingUtil
	eq(E.DecodeBase64("aGVsbG8gd29ybGQ="), "hello world")
	eq(E.DecodeBase64(E.EncodeBase64("ab\0c")), "ab\0c")
	-- zlib.compress(b"hello hello hello hello", 9) and a dynamic-Huffman block of a longer text
	eq(E.DecompressString(E.DecodeBase64("eNrLSM3JyVfIQCcBaAMIsQ=="), 1), "hello hello hello hello")
	-- dynamic Huffman block (random words, Python zlib level 9), and a stored block
	local long = E.DecompressString(E.DecodeBase64("eNplVVtiwjAMu0pPsNP0ArB1K4zRjZbn6YctO5LLRwOJE1uRZWceLsOx259/fuduHG7d33n3/t1tT9P12H1Ot+66e2xOH3OsL+NQduynw+EeI1YOm8e9GLHdXLkJU0aSRYC4jrvDkI59xWH46nQZTj41HInM5ghIjFuzvIWX2a/4NA5LjHkUXh2CuxbwMIUf9RCGRhBi+PFZuCwIlDJswpg4YjMCYBvGj+krjXpFYFA8Rmh668dhdc/GGwMFUcG2Q/bbmyP7SlQ/D5dmM1Q4guv53P9lQNvl7oIMepFQPvTMltvNF0CZRaOkb2UZFyEy/eS+lJuLw9EsjaXGTktzCJYItBL64sJcY48jT2HVxNrxSr/lORjGj8qKMYFIVOBYDYFWAPb3LZ3UThFATpx3ePa/5qrlvq0kLrm1fYLF/iqMVW0lBWwLrQmEAzsMHBKwf43NYjOEy0oxWuTYGekOTYj4RIHMLXaWqq3E8oB9XvMiyyWSkeSwqoRnVojqthKndoYUiRKy3EMUBqdBxHq55dWgUOJwT0ljzqTEbsrV/eQ9lTrAzySpH1GAvhQkipRW4tln4K6JSBoU+7aIwezRJlqOavuIJi/ifn0l+ijv6NWrvt/AsNpIbWtl6zbJdlGeFvqQ80qWmZglL8L1c2uLNaVKQeEy9WDbG1SJzNRg5FzkqP2lL8LKUpFKzWf+eZiPJmz/QDofQQ=="), 1)
	eq(#long, 2178)
	eq(long:sub(1, 30), "seven jumps hex quick brown fo")
	eq(E.DecompressString(E.DecodeBase64("eAEBAwD8/2FiYwJNASc="), 1), "abc")
	-- CBOR: {1, -2, "x", true, {a = 1.5}} = 85 01 21 61 78 f5 a1 61 61 f9 3e 00
	local v = E.DeserializeCBOR(string.char(0x85, 0x01, 0x21, 0x61, 0x78, 0xf5, 0xa1, 0x61, 0x61, 0xf9, 0x3e, 0x00))
	eq(v, { 1, -2, "x", true, { a = 1.5 } })
	eq(E.DeserializeCBOR(string.char(0x1a, 0x00, 0x01, 0x86, 0xa0)), 100000)
	eq(E.DeserializeCBOR(string.char(0xfb, 0x40, 0x09, 0x21, 0xfb, 0x54, 0x44, 0x2d, 0x18)), math.pi)
end)

-- A stand-in with QuestieDB's public shape: Q.RequireContract, Q.<Entity>.Exists/Get/GetAll/IdsByName.
local function fakeQuestie(contractOk)
	local rows = {
		Item = { [2589] = { name = "Linen Cloth", objectDrops = { 2039 }, vendors = nil } },
		Npc = { [448] = { name = "Hogger", spawns = { [12] = { { 25.0, 92.9 } } } } },
	}
	local Q = { RequireContract = function(n) return contractOk and n == 4, contractOk and nil or "too old" end }
	for entity, byId in pairs(rows) do
		Q[entity] = {
			Exists = function(id) return byId[id] ~= nil end,
			Get = function(id, field) return byId[id][field] end,
			GetAll = function(id, fields)
				local out = {}
				for i, f in ipairs(fields) do out[i] = byId[id][f] end
				return out
			end,
			IdsByName = function(name)
				local ids = {}
				for id, r in pairs(byId) do if r.name == name then ids[#ids + 1] = id end end
				return ids
			end,
		}
	end
	return Q
end

test("questie bridge: absent, present, wrong contract, failing call", function()
	local FK = H.Start(KIT).FK
	ok(not FK.Questie.Available())
	ok(FK.Questie.Get("Item", 2589, "name") == nil)
	rawset(_G, "LibQuestieDB", fakeQuestie(true))
	ok(FK.Questie.Available(), "loading later is noticed")
	eq(FK.Questie.Get("Item", 2589, "name"), "Linen Cloth")
	eq(FK.Questie.Find("Item", "Linen Cloth"), { 2589 })
	eq(FK.Questie.ItemSources(2589), { npcs = {}, objects = { 2039 }, items = {}, vendors = {} })
	eq(FK.Questie.Spawns(448), { { zoneID = 12, x = 25.0, y = 92.9 } })
	ok(FK.Questie.Get("Item", 1, "name") == nil, "unknown id")
	LibQuestieDB.Item.Get = function() error("changed API") end
	ok(FK.Questie.Get("Item", 2589, "name") == nil)
	ok(FK.warnings[#FK.warnings]:find("questie%-error"))

	FK = H.Start(KIT).FK
	FK = H.Reload().FK
	rawset(_G, "LibQuestieDB", fakeQuestie(false))
	ok(not FK.Questie.Available())
	ok(FK.warnings[#FK.warnings]:find("questie%-contract"))
end)

test("auction bridge: price by id and link, missing addon, failing call", function()
	local FK = H.Start(KIT).FK
	ok(not FK.Auction.Available() and FK.Auction.Price(2589) == nil)
	local calls = {}
	rawset(_G, "Auctionator", { API = { v1 = {
		GetAuctionPriceByItemID = function(caller, id) calls[#calls + 1] = caller return id == 2589 and 1250 or nil end,
		GetAuctionPriceByItemLink = function(caller, link) return link:find("item:2589") and 1250 or nil end,
		MultiSearch = function(caller, names) calls.search = names end,
	} } })
	eq(FK.Auction.Price(2589), 1250)
	eq(calls[1], "KitTest", "the caller id is the addon's name")
	eq(FK.Auction.Price(FK.Items.Info(2589).link), 1250)
	ok(FK.Auction.Price(6948) == nil, "never scanned")
	ok(FK.Auction.Search({ "Linen Cloth" }))
	eq(calls.search, { "Linen Cloth" })
	Auctionator.API.v1.MultiSearch = function() error("AH closed") end
	ok(not FK.Auction.Search({ "x" }))
end)
