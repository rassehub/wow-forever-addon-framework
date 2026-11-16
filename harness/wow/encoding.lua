-- C_EncodingUtil for the emulator: Base64, zlib/deflate inflate and CBOR decoding in plain
-- Lua 5.1 (no bit library). Enough to run addons that ship data the way the client decodes it
-- (QuestieDB's baked mode). Written from RFC 4648, RFC 1950/1951 and RFC 8949.

local byte, char, sub, concat, floor, ldexp = string.byte, string.char, string.sub, table.concat, math.floor, math.ldexp

local E = {}

-----------------------------------------------------------------------------------------------
-- Base64
-----------------------------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local dec64 = {}
for i = 1, 64 do dec64[byte(B64, i)] = i - 1 end
dec64[byte("-")], dec64[byte("_")] = 62, 63 -- URL-safe alphabet too

function E.DecodeBase64(s)
	local out, n, acc, bits = {}, 0, 0, 0
	for i = 1, #s do
		local v = dec64[byte(s, i)]
		if v then
			acc, bits = acc * 64 + v, bits + 6
			if bits >= 8 then
				bits = bits - 8
				local b = floor(acc / 2 ^ bits)
				acc = acc - b * 2 ^ bits
				n = n + 1
				out[n] = char(b)
			end
		end
	end
	return concat(out)
end

function E.EncodeBase64(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = byte(s, i, i + 2)
		local v = a * 65536 + (b or 0) * 256 + (c or 0)
		local q = { floor(v / 262144) % 64, floor(v / 4096) % 64, floor(v / 64) % 64, v % 64 }
		out[#out + 1] = sub(B64, q[1] + 1, q[1] + 1) .. sub(B64, q[2] + 1, q[2] + 1)
			.. (b and sub(B64, q[3] + 1, q[3] + 1) or "=") .. (c and sub(B64, q[4] + 1, q[4] + 1) or "=")
	end
	return concat(out)
end

-----------------------------------------------------------------------------------------------
-- Inflate (RFC 1951), puff-style canonical Huffman decoding
-----------------------------------------------------------------------------------------------
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function huffman(lengths, n)
	local count, symbol, offs = {}, {}, {}
	for len = 0, 15 do count[len] = 0 end
	for s = 0, n - 1 do count[lengths[s] or 0] = count[lengths[s] or 0] + 1 end
	offs[1] = 0
	for len = 1, 14 do offs[len + 1] = offs[len] + count[len] end
	for s = 0, n - 1 do
		local len = lengths[s] or 0
		if len ~= 0 then symbol[offs[len]] = s offs[len] = offs[len] + 1 end
	end
	return { count = count, symbol = symbol }
end

local function inflate(data, pos)
	local out, outn = {}, 0
	local bitbuf, bitcnt = 0, 0
	local function bits(n)
		while bitcnt < n do
			local b = byte(data, pos) or error("inflate: unexpected end of data", 0)
			pos = pos + 1
			bitbuf = bitbuf + b * 2 ^ bitcnt
			bitcnt = bitcnt + 8
		end
		local p = 2 ^ n
		local v = bitbuf % p
		bitbuf, bitcnt = (bitbuf - v) / p, bitcnt - n
		return v
	end
	local function decode(h)
		local code, first, index = 0, 0, 0
		local count, symbol = h.count, h.symbol
		for len = 1, 15 do
			code = code + bits(1)
			local c = count[len]
			if code - c < first then return symbol[index + code - first] end
			index, first = index + c, (first + c) * 2
			code = code * 2
		end
		error("inflate: bad Huffman code", 0)
	end
	local fixedL, fixedD
	repeat
		local final, kind = bits(1), bits(2)
		if kind == 0 then
			bitbuf, bitcnt = 0, 0 -- skip to a byte boundary
			local len = byte(data, pos) + byte(data, pos + 1) * 256
			pos = pos + 4
			for i = pos, pos + len - 1 do outn = outn + 1 out[outn] = byte(data, i) end
			pos = pos + len
		elseif kind == 3 then
			error("inflate: invalid block type", 0)
		else
			local lcode, dcode
			if kind == 1 then
				if not fixedL then
					local l = {}
					for s = 0, 143 do l[s] = 8 end
					for s = 144, 255 do l[s] = 9 end
					for s = 256, 279 do l[s] = 7 end
					for s = 280, 287 do l[s] = 8 end
					fixedL = huffman(l, 288)
					local d = {}
					for s = 0, 29 do d[s] = 5 end
					fixedD = huffman(d, 30)
				end
				lcode, dcode = fixedL, fixedD
			else
				local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
				local lengths = {}
				for i = 1, 19 do lengths[ORDER[i]] = i <= ncode and bits(3) or 0 end
				local lencode = huffman(lengths, 19)
				local all, i = {}, 0
				while i < nlen + ndist do
					local sym = decode(lencode)
					if sym < 16 then all[i] = sym i = i + 1
					else
						local rep, val = 0, 0
						if sym == 16 then val, rep = all[i - 1], 3 + bits(2)
						elseif sym == 17 then rep = 3 + bits(3)
						else rep = 11 + bits(7) end
						for _ = 1, rep do all[i] = val i = i + 1 end
					end
				end
				local l, d = {}, {}
				for s = 0, nlen - 1 do l[s] = all[s] end
				for s = 0, ndist - 1 do d[s] = all[nlen + s] end
				lcode, dcode = huffman(l, nlen), huffman(d, ndist)
			end
			while true do
				local sym = decode(lcode)
				if sym < 256 then outn = outn + 1 out[outn] = sym
				elseif sym == 256 then break
				else
					sym = sym - 256
					local len = LBASE[sym] + bits(LEXT[sym])
					local ds = decode(dcode) + 1
					local from = outn - (DBASE[ds] + bits(DEXT[ds]))
					for k = 1, len do out[outn + k] = out[from + k] end
					outn = outn + len
				end
			end
		end
	until final == 1
	local parts = {}
	for i = 1, outn, 4096 do parts[#parts + 1] = char(unpack(out, i, math.min(i + 4095, outn))) end
	return concat(parts)
end

-- method: 0 = raw deflate, 1 = zlib (Enum.CompressionMethod.Deflate / Zlib)
function E.DecompressString(s, method)
	if method == 1 or (method == nil and byte(s, 1) == 0x78) then return inflate(s, 3) end
	return inflate(s, 1)
end

-----------------------------------------------------------------------------------------------
-- CBOR (RFC 8949): integers, strings, arrays (1-based tables), maps, simple values, floats
-----------------------------------------------------------------------------------------------
local function float(bytes, expBits, fracBits)
	-- the top 32 bits hold sign, exponent and the high fraction; the rest is added exactly
	-- (a 64-bit integer does not fit a Lua number without losing the low bits)
	local hi, lo = 0, 0
	local n = #bytes
	for i = 1, math.min(n, 4) do hi = hi * 256 + byte(bytes, i) end
	for i = 5, n do lo = lo * 256 + byte(bytes, i) end
	local hiBits, loBits = math.min(n, 4) * 8, math.max(n - 4, 0) * 8
	local sign = hi >= 2 ^ (hiBits - 1) and -1 or 1
	if sign < 0 then hi = hi - 2 ^ (hiBits - 1) end
	local hiFrac = fracBits - loBits
	local e = floor(hi / 2 ^ hiFrac)
	local f = (hi - e * 2 ^ hiFrac) * 2 ^ loBits + lo
	local bias = 2 ^ (expBits - 1) - 1
	if e == 0 then return sign * ldexp(f, 1 - bias - fracBits) end
	if e == 2 ^ expBits - 1 then return f == 0 and sign * math.huge or 0 / 0 end
	return sign * ldexp(f + 2 ^ fracBits, e - bias - fracBits)
end

function E.DeserializeCBOR(s)
	local pos = 1
	local item
	local function uint(n)
		local v = 0
		for i = pos, pos + n - 1 do v = v * 256 + byte(s, i) end
		pos = pos + n
		return v
	end
	local function arg(info)
		if info < 24 then return info end
		if info == 24 then return uint(1) end
		if info == 25 then return uint(2) end
		if info == 26 then return uint(4) end
		if info == 27 then return uint(8) end
		if info == 31 then return nil end -- indefinite length
		error("CBOR: bad additional info " .. info, 0)
	end
	local BREAK = {}
	function item()
		local ib = byte(s, pos) or error("CBOR: unexpected end", 0)
		pos = pos + 1
		local major, info = floor(ib / 32), ib % 32
		if major == 7 then
			if info == 20 then return false elseif info == 21 then return true
			elseif info == 22 or info == 23 then return nil
			elseif info == 25 then pos = pos + 2 return float(sub(s, pos - 2, pos - 1), 5, 10)
			elseif info == 26 then pos = pos + 4 return float(sub(s, pos - 4, pos - 1), 8, 23)
			elseif info == 27 then pos = pos + 8 return float(sub(s, pos - 8, pos - 1), 11, 52)
			elseif info == 31 then return BREAK end
			return arg(info)
		end
		local n = arg(info)
		if major == 0 then return n end
		if major == 1 then return -1 - n end
		if major == 6 then return item() end -- tags carry no meaning here
		if major == 2 or major == 3 then
			if n then pos = pos + n return sub(s, pos - n, pos - 1) end
			local parts = {}
			while true do local p = item() if p == BREAK then break end parts[#parts + 1] = p end
			return concat(parts)
		end
		local t = {}
		if major == 4 then
			local i = 0
			while not n or i < n do
				local v = item()
				if v == BREAK then break end
				i = i + 1
				t[i] = v
			end
		else
			local i = 0
			while not n or i < n do
				local k = item()
				if k == BREAK then break end
				t[k] = item()
				i = i + 1
			end
		end
		return t
	end
	return item()
end

return E
