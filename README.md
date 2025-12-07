![image|500x500, 100%](upload://hSePoNhAhKYQI5QSoKvPupRKso0.png)

# Safecall

## Overview

**SafeCall** is a lightweight, great error handling wrapper for Roblox Lua. It simplifies safe function execution by automatically handling errors, retries, async support, rate limiting, profiling, and more, reducing crashes and improving debugging.

It works standalone or integrates seamlessly with other frameworks (e.g. Promise, ProfileStore, Knit)

## Installation

- Download the rbxm
- Ungroup the **ReplicatedStorage model** and place the `Main` folder inside `ReplicatedStorage`.
- Also, place `SafeCallExample` content inside `ServerScriptService`.

Require it:

```
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeCall = require(ReplicatedStorage.Main.Modules.SafeCall)
local safe = SafeCall.new()
```

## API Reference

### Constructor

- `SafeCall.new(logFunction: function?) -> SafeCall`

Creates a new SafeCall instance.

- `logFunction` (optional): custom error logger, defaults to `warn`.

### Instance Methods

<details>
<summary><strong>Call Method</strong></summary>

**Call**

```
success, result = safe:Call(fn: function, ...any) -> (bool, any)
```

Calls `fn` safely with arguments. Returns success status and result or error.

Note: `Call` and related helpers preserve the full tuple of return values from `fn` (including `nil` values). If `fn` returns multiple values, `safe:Call(fn)` will return the same tuple.

**CallWithRetry**

```
success, result = safe:CallWithRetry(fn: function, attempts?: number, delay?: number, backoff?: number, ...any)
```

Calls `fn` with retry logic on failure.

- `attempts`: number of retries (default 3)
- `delay`: initial wait between retries (default 0.1s)
- `backoff`: multiplier to increase delay after each retry (default 1.5)

Extras:

- The retry handler (set via `safe:SetRetryHandler`) receives `(err, attempt, attempts, delay)` and may return `false` to abort further retries or a numeric value to override the next delay. This lets you implement dynamic backoff or conditional aborts.
- `CallWithRetry` preserves full multi-value returns when the wrapped function succeeds.

**CallAsync**

```
promise = safe:CallAsync(fn: function, ...any) -> Promise
```

Calls `fn` async, returns a Promise that resolves or rejects based on call success.
Requires the `Promise` library.

Note: `CallAsync` resolves with the full tuple returned by `fn` (preserving `nil` values). The project marks `CallAsync` and `SetPromiseModule` as deprecated in favor of `CallWithThread` for simple deferred execution — keep using a Promise adapter only if you need Promise-based flows.

**Use case**: Run a function asynchronously and handle its result with Promises.
**Best for**: Async workflows like data fetching or web requests.

## Example

```
safe:CallAsync(function()
	return someAsyncFunction()
end):andThen(function(result)
	print("Got result:", result)
end):catch(warn)
```

Requires the Promise library. Errors are caught and passed to `.catch`.

**CallDeferred**

```
safe:CallDeferred(fn: function, ...any)
Schedules `fn` to be called safely in a deferred (non-blocking) manner.
```

**Use case**: Runs your function safely after the current thread yields.
**Best for**: Non-blocking operations like safe event dispatching.

## Example

```
safe:CallDeferred(function()
	print("Runs later, but safely!")
end)
```

It’s like `task.defer` but with error safety built-in.

**CallDelayed**

```
success, result = safe:CallDelayed(delay: number, fn: function, ...any)
```

Waits `delay` seconds then calls `fn` safely.

## Example

```
safe:CallDelayed(2, function()
	print("Called after 2 seconds.")
end)
```

**Use case**: Automatically wraps **all functions inside a table** with SafeCall error handling.
**Best for**: Making whole utility modules or service interfaces crash-safe without rewriting every function.

**ProtectTable**

```
protectedTable = safe:ProtectTable(tbl: table)
```

Returns a version of `tbl` where all functions are wrapped with safe calls.
**Behavior changes**: `ProtectTable` now returns a proxy that preserves colon-call (`:`) semantics and respects metamethods on the original table. Methods will be invoked with the original table as `self`, and non-function fields remain accessible and writable on the original table.
**Use case**: Automatically wraps **all functions inside a table** with SafeCall error handling while preserving method bindings.
**Best for**: Making whole utility modules or service interfaces crash-safe without rewriting every function.

## Example

```
local unsafeUtils = {
	PrintHello = function()
		print("Hello")
	end,
	BreakIt = function()
		error("This will crash!")
	end
}

local safeUtils = safe:ProtectTable(unsafeUtils)

safeUtils.PrintHello() --> works normally
safeUtils.BreakIt()    --> error is caught, doesn't crash
```

**WrapEvent**

```
connection = safe:WrapEvent(remote: RemoteEvent | BindableEvent, callback: function)
```

Wraps a remote or bindable event callback with safe error handling.
**Use case**: Wraps RemoteEvent or BindableEvent connections with SafeCall.
**Best for**: Secure remote handling to prevent crashes from bad data.

## Example

```
safe:WrapEvent(RemoteEvent, function(player, data)
	print(player.Name, data)
end)

```

**WrapFunction**

```
safe:WrapFunction(remote: RemoteFunction | BindableFunction, callback: function)
```

Wraps a remote or bindable function invocation callback safely.
**Use case**: Wraps RemoteFunction or BindableFunction callbacks.
**Best for**: Validating or securing remote/bindable invokes.

## Example

```
safe:WrapFunction(RemoteFunction, function(player, request)
	return processRequest(request)
end)
```

**CallBatch**

```
results = safe:CallBatch(functions: {function})
```

Calls a list of functions safely, returning a table of success/result pairs.
**Use case**: Executes a batch of functions safely, returns all results.
**Best for**: Running multiple tasks (e.g. setup, cleanup) with error isolation.

Details: Each entry in `results` is a packed-result table (use `table.unpack(results[i], 1, results[i].n)` to retrieve the full return tuple for that function). This preserves multiple return values per function in the batch.

## Example

```
local results = safe:CallBatch({
	function() return "ok1" end,
	function() error("bad2") end,
	function() return "ok3" end,
})
```

**CallWithTimeout**

```
success, result = safe:CallWithTimeout(timeout: number, fn: function, ...any)
```

Calls `fn` safely but aborts if it exceeds `timeout` seconds.
**Use case**: Ensures a function doesn’t run forever — fails if it takes too long.
**Best for**: External service calls, long waits.

Note: `CallWithTimeout` preserves the full return tuple from the function if it completes before the timeout.

## Example

```
local success, result = safe:CallWithTimeout(5, function()
	while true do task.wait() end
end)
```

**Circuit Breaker**

```
breaker = safe:CreateCircuitBreaker(threshold?: number, resetTime?: number)

success, result = safe:CallWithCircuitBreaker(breaker, fn: function, ...any)
```

Creates a circuit breaker to stop calling `fn` if repeated failures occur, then resets after cooldown.
**Use case**: Temporarily disables a failing function after repeated errors.
**Best for**: External APIs, datastores, unstable services.

## Example

```
local breaker = safe:CreateCircuitBreaker(3, 10) -- 3 fails, 10s cooldown

safe:CallWithCircuitBreaker(breaker, function()
	return ExternalAPI()
end)
```

**Rate Limiter**

```
limiter = safe:CreateRateLimiter(maxCalls?: number, timeWindow?: number)

success, result = safe:CallWithRateLimit(limiter, fn: function, ...any)
```

Safely connects to Roblox events/signals with automatic error handling and optional weak reference disconnect.
**Use case**: Limits how often a function can run within a time window.
**Best for**: Anti-spam, cooldowns, external APIs.

## Example

```
local limiter = safe:CreateRateLimiter(5, 10) -- Max 5 calls per 10s

safe:CallWithRateLimit(limiter, function()
	print("Allowed call")
end)
```

**ConnectSafe**

```
connection = safe:ConnectSafe(
	signal: RBXScriptSignal,
	callback: (...any) -> (),
	options: {
		weakRef: Instance?,
		usePromise: boolean?
	}?
)
```

Safely connects to Roblox events/signals with automatic error handling and optional weak reference disconnect.
**Use case**: Safely connects to events/signals.
**Best for**: Cleaner `.Changed`, `.Touched`, or custom signal connections.

## Example

```
Baisc
safe:ConnectSafe(part.Touched, function(hit)
	print("Touched:", hit)
	error("Test error") -- will be caught and logged
end)

With weakRef
safe:ConnectSafe(button.MouseButton1Click, function()
	print("Button clicked")
end, {
	weakRef = button,
})


With Promise mode
safe:SetPromiseModule(Promise)

safe:ConnectSafe(remote.OnClientEvent, function(data)
	print("Got data:", data)
	error("Promise test")
end, {
	usePromise = true,
})

```

**Memoize**

```
memoizedFn = safe:Memoize(fn: function, ttl?: number)
```

Returns a memoized version of `fn` with cache TTL (time-to-live).
**Use case**: Caches results from a function to avoid repeating work.
**Best for**: Expensive calculations, function caching.

## Example

```
local slowFn = safe:Memoize(function(x)
	task.wait(2)
	return x * 2
end, 10)
```

**Profiling**

```
profiler = safe:CreateProfiler()

success, result = safe:CallWithProfiler(profiler, fn: function, ...any)

stats = safe:GetProfilerStats(profiler)
```

Profile calls for performance and error stats.
**Use case**: Measure performance and error stats of your functions.
**Best for**: Debugging slow or unstable code.

```
local profiler = safe:CreateProfiler()

safe:CallWithProfiler(profiler, function()
	task.wait(0.5)
	error("whoops")
end)

print(safe:GetProfilerStats(profiler))
```

**Global Error Handlers**

```
safe:AddGlobalHandler(handler: function)
safe:RemoveGlobalHandler(handler: function)
```

Add or remove global error handlers that are called on every error.
A **global error handler** is a function that runs **every time any `safe:Call()` fails**, no matter where it's called in your game.

Think of it like a **global listener** for all uncaught errors in SafeCall.

## Example

```
local function globalLogger(err, traceback)
	print("GLOBAL ERROR:", err)
	print("Traceback:\n", traceback)
end

safe:AddGlobalHandler(globalLogger)

safe:Call(function()
	error("Something broke!")
end)
```

## Advanced Features

Experimental: SafeSandbox
SafeCall now includes an optional sandbox environment that allows running untrusted or user-generated code safely with a locked-down environment.

The sandbox prevents access to dangerous globals and wraps all executed code with SafeCall internally.

## Create a sandbox

```lua
local sandbox = safe:CreateSandbox({
	allowGlobals = false,
	allowedEnv = {
		math = math,
		string = string,
	},
})
```

## Run code inside the sandbox

```lua
sandbox:Run(function(env)
	env.print("Hello from sandbox")
	env.error("This will be caught safely")
end)
```

## Beta Features

- Isolated environment table
- No access to Roblox globals unless explicitly added
- All sandboxed calls pass through SafeCall
- Prevents runaway infinite loops (soft protection)
- Perfect for plugin dev, hot-reload systems, inspectable code, or unsafe 3rd-party logic

### Experimental: SafeRemote

SafeRemote adds security wrappers for RemoteEvent and RemoteFunction:

- Rate limiting per-player
- Argument validation
- Auto SafeCall protection
- Carries over full error logs
- Prevents client spam & exploit payloads
- Drop-in replacement for normal remotes

### Create a SafeRemoteEvent

```lua
local SafeRemoteEvent = safe:CreateSafeRemoteEvent(remote, {
	maxCallsPerMinute = 60,
	validate = function(player, arg1, arg2)
		return typeof(arg1) == "string"
	end,
})
```

## Listen

```lua
SafeRemoteEvent:OnServer(function(player, msg)
	print("Player said:", msg)
end)
```

## Client send

```lua
SafeRemoteEvent:Fire("Hello world")
```

## Create a SafeRemoteFunction

```lua
local SafeRemoteFunction = safe:CreateSafeRemoteFunction(remote, {
	validate = function(player, input)
		return typeof(input) == "number"
	end,
})
```

## Server implementation

```lua
SafeRemoteFunction:OnInvoke(function(player, num)
	return num * 2
end)
```

## Client call

```lua
local result = SafeRemoteFunction:Invoke(21)
print(result) --> 42
```

> The following features are experimental and currently in beta.
> They may change before becoming part of the stable 1.5 release.
> Use in production at your own risk.

</details>

<details>
<summary><strong>Usage Examples</strong></summary>

## Usage Examples

# Simple safe call

```
safe:Call(function()
	error("Oops!")
end)
-- Output: Warning printed, no crash
```

# Safe remote event handling

```
local remote = game.ReplicatedStorage:WaitForChild("SomeEvent")
safe:WrapEvent(remote, function(player, data)
	print(player.Name, data)
end)
```

# Safe async Promise call

```
safe:CallAsync(function()
	return Promise.new(function(resolve, reject)
		-- async logic here
		resolve("Done")
	end)
end):andThen(print):catch(warn)
```

# Use with retry

```
safe:CallWithRetry(function()
	-- unstable operation
end, 5, 0.2, 2)
```

# webhook

```
local HttpService = game:GetService("HttpService")
local webhookUrl = "YOUR_DISCORD_WEBHOOK_URL"

local function webhookLogger(err)
    local payload = HttpService:JSONEncode({
        username = "SafeCall Logger",
        embeds = {{
            title = "SafeCall Error",
            description = tostring(err),
            color = 16711680, -- red
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })

    pcall(function()
        HttpService:PostAsync(webhookUrl, payload, Enum.HttpContentType.ApplicationJson)
    end)
end

local safe = SafeCall.new(webhookLogger)
```

--

### Experimental Features Examples

## SafeSandbox – Usage Examples

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeCall = require(ReplicatedStorage.SafeCall)

local safe = SafeCall.new()

-- Create a sandbox with a minimal allowed environment
local sandbox = safe:CreateSandbox({
	allowGlobals = false,
	allowedEnv = {
		math = math,
		string = string,
	},
})

sandbox:Run(function(env)
	env.print("Hello from sandbox!")
	env.print("Sin(1):", env.math.sin(1))

	-- This will throw, but be caught by SafeCall internally
	error("Sandboxed error")
end)
```

## Sandbox with extra utilities and tagging

```lua
local sandbox = safe:CreateSandbox({
	tag = "PluginSandbox",
	allowGlobals = false,
	allowedEnv = {
		print = print,
		math = math,
		tick = tick,
	},
})

-- You can pass data into the sandboxed function too
sandbox:Run(function(env, code)
	env.print("[Sandbox] Executing snippet:", code)

	-- You could run compiled chunks or interpreted snippets here
	local fn = loadstring(code)
	if fn then
		fn()
	else
		error("Invalid code")
	end
end, "print('Hello from inside snippet!')")
```

## SafeRemote – Usage Examples

## SafeRemoteEvent – chat / action example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeCall = require(ReplicatedStorage.Main.Modules.SafeCall)

local safe = SafeCall.new()

local ChatEvent = ReplicatedStorage:WaitForChild("ChatEvent")

-- Server-side
local SafeChat = safe:CreateSafeRemoteEvent(ChatEvent, {
	tag = "ChatRemote",
	maxCallsPerMinute = 60, -- per player
	validate = function(player, message)
		if typeof(message) ~= "string" then
			return false, "Message must be a string"
		end
		if #message == 0 or #message > 150 then
			return false, "Message length out of range"
		end
		return true
	end,
})

SafeChat:OnServer(function(player, message)
	print(("[Chat] %s: %s"):format(player.Name, message))
	-- broadcast, log, etc
end)

-- Client-side
-- (same wrapper API, just require SafeCall and create the SafeRemoteEvent using the same RemoteEvent)
local safe = SafeCall.new()
local ChatEvent = ReplicatedStorage:WaitForChild("ChatEvent")
local SafeChat = safe:CreateSafeRemoteEvent(ChatEvent)

SafeChat:Fire("Hello world!")
```

## SafeRemoteFunction – validated request / response

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeCall = require(ReplicatedStorage.Main.Modules.SafeCall)

local safe = SafeCall.new()

local DamageRequest = ReplicatedStorage:WaitForChild("DamageRequest")

-- Server-side
local SafeDamage = safe:CreateSafeRemoteFunction(DamageRequest, {
	tag = "DamageRequest",
	validate = function(player, targetId, amount)
		if typeof(targetId) ~= "number" or typeof(amount) ~= "number" then
			return false, "Invalid argument types"
		end

		if amount < 0 or amount > 50 then
			return false, "Damage out of range"
		end

		return true
	end,
	maxCallsPerWindow = 10,
	windowSeconds = 5,
})

SafeDamage:OnInvoke(function(player, targetId, amount)
	-- You’re guaranteed validated args here
	print(player.Name, "requested", amount, "damage on", targetId)

	-- Apply damage, look up target, etc.
	local success = true
	local newHealth = 80

	return success, newHealth
end)

-- Client-side
local safe = SafeCall.new()
local DamageRequest = ReplicatedStorage:WaitForChild("DamageRequest")
local SafeDamage = safe:CreateSafeRemoteFunction(DamageRequest)

local ok, success, newHealth = safe:Call(function()
	return SafeDamage:Invoke(1234, 20)
end)

if ok and success then
	print("New health:", newHealth)
else
	warn("Damage request failed:", success or newHealth)
end
```
