local _, ns = ...
local FK = ns.FK

---@module Secret  Helpers for Midnight "secret values" (combat data the addon may show but not compute on). FK.Secret.Is(v), FK.Secret.Readable(...) (true when no argument is secret), FK.Secret.Use(v, fn, fallback) (fn(v) only when v is readable, else fallback), FK.Secret.Text(v, fmt) (display string that works on secrets: string.format and .. are allowed on them).
local Secret = {}
FK.Secret = Secret

local isSecret = issecretvalue or function() return false end

function Secret.Is(v) return isSecret(v) == true end

function Secret.Readable(...)
	for i = 1, select("#", ...) do
		if isSecret((select(i, ...))) then return false end
	end
	return true
end

-- Compute with a value only when it is readable: FK.Secret.Use(UnitHealth("target"), function(hp) return hp < 100 end, false)
function Secret.Use(v, fn, fallback)
	if isSecret(v) then return fallback end
	return fn(v)
end

-- A display string; safe for secrets because it only formats (pass it straight to SetText).
function Secret.Text(v, fmt) return string.format(fmt or "%s", v) end
