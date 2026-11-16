local _, ns = ...
local FK = ns.FK

---@module Timer  FK:After(seconds, fn) and FK:Every(seconds, fn, times) return cancellable timers; FK:Debounce(seconds, fn) runs after a burst ends (search boxes, BAG_UPDATE); FK:Throttle(seconds, fn) at most once per window, plus once at its end.

function FK:After(seconds, fn) return C_Timer.NewTimer(seconds, fn) end
function FK:Every(seconds, fn, times) return C_Timer.NewTicker(seconds, fn, times) end

-- Returns a function that runs fn once, `seconds` after the last call. For bursts of events
-- (BAG_UPDATE, typing in a search box) where only the final state matters.
function FK:Debounce(seconds, fn)
	local timer, args, n
	return function(...)
		args, n = { ... }, select("#", ...)
		if timer then timer:Cancel() end
		timer = C_Timer.NewTimer(seconds, function()
			timer = nil
			fn(unpack(args, 1, n))
		end)
	end
end

-- Returns a function that runs fn at most once per `seconds`: immediately on the first call,
-- and once more at the end of the window if calls arrived meanwhile.
function FK:Throttle(seconds, fn)
	local last, pending, args, n = -math.huge, false, nil, 0
	return function(...)
		args, n = { ... }, select("#", ...)
		local now = GetTime()
		if now - last >= seconds then
			last = now
			fn(...)
		elseif not pending then
			pending = true
			C_Timer.After(seconds - (now - last), function()
				pending, last = false, GetTime()
				fn(unpack(args, 1, n))
			end)
		end
	end
end
