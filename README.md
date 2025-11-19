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

**CallWithRetry**

```
success, result = safe:CallWithRetry(fn: function, attempts?: number, delay?: number, backoff?: number, ...any)
```

Calls `fn` with retry logic on failure.

- `attempts`: number of retries (default 3)
- `delay`: initial wait between retries (default 0.1s)
- `backoff`: multiplier to increase delay after each retry (default 1.5)

**CallAsync**

```
promise = safe:CallAsync(fn: function, ...any) -> Promise
```

Calls `fn` async, returns a Promise that resolves or rejects based on call success.
Requires the `Promise` library.

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
**Use case**: Automatically wraps **all functions inside a table** with SafeCall error handling.
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
