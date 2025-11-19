--[[
	Name: SafeCall
	Description: Lightweight fail-safe wrapper for unsafe function calls
	Repository: text21/SafeCall
	Author: Akira
	Version: 1.3.0
--]]

local SafeCall = {}
SafeCall.__index = SafeCall

local RunService = game:GetService("RunService")

function SafeCall.new(logFunction)
	local self = setmetatable({
		_globalHandlers = {},
		_errorFilters = {},
		_taskScheduler = {},
		_retryHandler = nil,
	}, SafeCall)

	self.Log = logFunction or function(err)
		warn("[SafeCall]:", err)
	end

	self._retryDefaults = {
		attempts = 3,
		delay = 0.1,
		backoff = 1.5,
	}

	self.Promise = nil

	return self
end

function SafeCall:SetLogger(fn)
	self.Log = fn or function() end
	return self
end

function SafeCall:SetRetryDefaults(attempts, delay, backoff)
	self._retryDefaults = {
		attempts = attempts or 3,
		delay = delay or 0.1,
		backoff = backoff or 1.5,
	}
	return self
end

function SafeCall:AddErrorIgnorePattern(pattern)
	table.insert(self._errorFilters, pattern)
end

function SafeCall:SetRetryHandler(fn)
	self._retryHandler = fn
end

function SafeCall:Call(fn, ...)
	local results = { pcall(fn, ...) }
	local success = table.remove(results, 1)

	if not success then
		local msg = tostring(results[1])

		for _, pattern in ipairs(self._errorFilters) do
			if string.match(msg, pattern) then
				return false, msg
			end
		end

		self.Log(msg)

		for _, handler in ipairs(self._globalHandlers) do
			pcall(handler, msg, debug.traceback())
		end
	end

	return success, table.unpack(results)
end

function SafeCall:CallWithTag(tag, fn, ...)
	local results = { pcall(fn, ...) }
	local success = table.remove(results, 1)

	if not success then
		local msg = tostring(results[1])

		for _, pattern in ipairs(self._errorFilters) do
			if string.match(msg, pattern) then
				return false, msg
			end
		end

		local prefix = tag and ("[" .. tag .. "] ") or ""
		self.Log(prefix .. msg)

		for _, handler in ipairs(self._globalHandlers) do
			pcall(handler, msg, debug.traceback(), prefix)
		end
	end

	return success, table.unpack(results)
end

function SafeCall:CallWithRetry(fn, attempts, delay, backoff, ...)
	attempts = attempts or self._retryDefaults.attempts
	delay = delay or self._retryDefaults.delay
	backoff = backoff or self._retryDefaults.backoff

	local args = { ... }
	local currentDelay = delay

	for i = 1, attempts do
		local success, result = pcall(fn, table.unpack(args))
		if success then return true, result end

		if self._retryHandler and not self._retryHandler(result) then
			break
		end

		self.Log(string.format("[Retry %d/%d] %s", i, attempts, tostring(result)))

		if i < attempts then
			task.wait(currentDelay)
			currentDelay = currentDelay * backoff
		end
	end

	return false, "All retry attempts failed"
end

function SafeCall:SetPromiseModule(promise)
	self.Promise = promise
end

function SafeCall:CallAsync(fn, ...)
	if not self.Promise then
		error("No Promise module provided")
	end

	local args = { ... }

	return self.Promise.new(function(resolve, reject)
		local ok, res = pcall(fn, table.unpack(args))
		if ok then resolve(res) else reject(res) end
	end)
end

function SafeCall:CallWithThread(deferred, fn, ...)
	local args = { ... }
	if deferred then
		return task.defer(function()
			self:Call(fn, table.unpack(args))
		end)
	else
		return task.spawn(function()
			self:Call(fn, table.unpack(args))
		end)
	end
end

function SafeCall:CallDelayed(delay, fn, ...)
	task.wait(delay)
	return self:Call(fn, ...)
end

function SafeCall:ProtectTable(tbl)
	local oldMt = getmetatable(tbl)
	local newMt = oldMt and table.clone(oldMt) or {}

	local oldIndex = oldMt and oldMt.__index or function(self, idx)
		return rawget(self, idx)
	end

	local oldCall = oldMt and oldMt.__call or function(self, ...)
		return self(...)
	end

	newMt.__index = function(_, idx)
		local val = oldIndex(tbl, idx)

		if typeof(val) == "function" then
			return function(...)
				return select(2, self:Call(val, ...))
			end
		end

		return val
	end

	newMt.__call = function(_, ...)
		return select(2, self:Call(oldCall, tbl, ...))
	end

	return setmetatable({}, newMt)
end

function SafeCall:WrapEvent(remote, callback)
	assert(typeof(callback) == "function", "callback must be a function")

	if remote:IsA("RemoteEvent") then
		if RunService:IsServer() then
			return remote.OnServerEvent:Connect(function(player, ...)
				self:Call(callback, player, ...)
			end)
		else
			return remote.OnClientEvent:Connect(function(...)
				self:Call(callback, ...)
			end)
		end
	elseif remote:IsA("BindableEvent") then
		return remote.Event:Connect(function(...)
			self:Call(callback, ...)
		end)
	else
		error("Expected RemoteEvent or BindableEvent")
	end
end

function SafeCall:WrapFunction(remote, callback)
	assert(typeof(callback) == "function", "callback must be a function")

	if remote:IsA("RemoteFunction") then
		if RunService:IsServer() then
			remote.OnServerInvoke = function(player, ...)
				local ok, res = self:Call(callback, player, ...)
				return ok and res or nil
			end
		else
			remote.OnClientInvoke = function(...)
				local ok, res = self:Call(callback, ...)
				return ok and res or nil
			end
		end
	elseif remote:IsA("BindableFunction") then
		remote.OnInvoke = function(...)
			local ok, res = self:Call(callback, ...)
			return ok and res or nil
		end
	else
		error("Expected RemoteFunction or BindableFunction")
	end
end

function SafeCall:CallBatch(functions)
	local results = {}
	for i, fn in ipairs(functions) do
		results[i] = { self:Call(fn) }
	end
	return results
end

function SafeCall:CallWithTimeout(timeout, fn, ...)
	local args = { ... }
	local done = false
	local result

	task.spawn(function()
		result = { self:Call(fn, table.unpack(args)) }
		done = true
	end)

	local start = tick()
	while not done and tick() - start < timeout do task.wait() end

	if done then
		return table.unpack(result)
	else
		self.Log("Function call timed out after " .. timeout .. " seconds")
		return false, "Timeout"
	end
end

function SafeCall:CreateCircuitBreaker(threshold, resetTime)
	return {
		failures = 0,
		threshold = threshold or 5,
		resetTime = resetTime or 30,
		lastFailure = 0,
		state = "CLOSED",
	}
end

function SafeCall:CallWithCircuitBreaker(breaker, fn, ...)
	local now = tick()

	if breaker.state == "OPEN" and now - breaker.lastFailure > breaker.resetTime then
		breaker.state = "HALF_OPEN"
		breaker.failures = 0
	end

	if breaker.state == "OPEN" then
		self.Log("Circuit breaker is OPEN")
		return false, "Circuit breaker open"
	end

	local ok, res = self:Call(fn, ...)

	if ok then
		if breaker.state == "HALF_OPEN" then breaker.state = "CLOSED" end
		breaker.failures = 0
	else
		breaker.failures += 1
		breaker.lastFailure = now

		if breaker.failures >= breaker.threshold then
			breaker.state = "OPEN"
			self.Log("Circuit breaker OPENED")
		end
	end

	return ok, res
end

function SafeCall:CreateRateLimiter(maxCalls, timeWindow)
	return {
		calls = {},
		maxCalls = maxCalls or 10,
		timeWindow = timeWindow or 60,
	}
end

function SafeCall:CallWithRateLimit(limiter, fn, ...)
	local now = tick()

	for i = #limiter.calls, 1, -1 do
		if now - limiter.calls[i] > limiter.timeWindow then
			table.remove(limiter.calls, i)
		end
	end

	if #limiter.calls >= limiter.maxCalls then
		self.Log("Rate limit exceeded")
		return false, "Rate limited"
	end

	table.insert(limiter.calls, now)
	return self:Call(fn, ...)
end

function SafeCall:ConnectSafe(signal, callback, options)
	options = options or {}
	local weakRef = options.weakRef
	local connectOnce = options.connectOnce

	local connection

	if connectOnce then
		connection = signal:ConnectOnce(function(...)
			if weakRef and not weakRef.Parent then
				connection:Disconnect()
				return
			end

			self:Call(callback, ...)
		end)
	else
		connection = signal:Connect(function(...)
			if weakRef and not weakRef.Parent then
				connection:Disconnect()
				return
			end

			self:Call(callback, ...)
		end)
	end

	return connection
end

function SafeCall:Memoize(fn, ttl)
	local cache = {}
	ttl = ttl or math.huge

	return function(...)
		local args = { ... }
		local keyParts = {}

		for i, v in ipairs(args) do
			keyParts[i] = typeof(v) .. ":" .. tostring(v)
		end

		local key = table.concat(keyParts, "|")
		local entry = cache[key]

		if entry and tick() - entry.time < ttl then
			return entry.success, entry.result
		end

		local success, result = self:Call(fn, table.unpack(args))
		cache[key] = {
			success = success,
			result = result,
			time = tick(),
		}

		return success, result
	end
end

function SafeCall:CreateProfiler()
	return {
		calls = 0,
		totalTime = 0,
		errors = 0,
		slowCalls = 0,
		slowThreshold = 0.1,
	}
end

function SafeCall:CallWithProfiler(profiler, fn, ...)
	local start = tick()
	profiler.calls += 1

	local ok, res = self:Call(fn, ...)
	local dt = tick() - start

	profiler.totalTime += dt
	if not ok then profiler.errors += 1 end
	if dt > profiler.slowThreshold then profiler.slowCalls += 1 end

	return ok, res
end

function SafeCall:GetProfilerStats(p)
	return {
		calls = p.calls,
		errors = p.errors,
		errorRate = p.calls > 0 and (p.errors / p.calls) or 0,
		avgTime = p.calls > 0 and (p.totalTime / p.calls) or 0,
		slowCalls = p.slowCalls,
		slowCallRate = p.calls > 0 and (p.slowCalls / p.calls) or 0,
	}
end

function SafeCall:AddGlobalHandler(handler)
	table.insert(self._globalHandlers, handler)
end

function SafeCall:RemoveGlobalHandler(handler)
	for i, h in ipairs(self._globalHandlers) do
		if h == handler then
			table.remove(self._globalHandlers, i)
			break
		end
	end
end

function SafeCall:Schedule(name, interval, fn)
	if self._taskScheduler[name] then return end
	self._taskScheduler[name] = true

	task.spawn(function()
		while self._taskScheduler[name] do
			self:CallWithTag(name, fn)
			task.wait(interval)
		end
	end)
end

function SafeCall:StopSchedule(name)
	self._taskScheduler[name] = nil
end

return SafeCall
