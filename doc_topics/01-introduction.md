# 1. Introduction

## 1.1 Overview

statemachine.lua is a finite state machine library for Lua. It provides a simple,
callback-driven API for defining states, transitions, and shared context. There is an optional `step` mechanism to drive progress.

Key features:

- **Guarded transitions** — transitions can be conditionally blocked at runtime.
  Return `nil, "reason"` from a transition callback to reject it; the caller
  receives the error and the state is left unchanged.
- **Time-driven states** — states can drive retry and timeout logic through a
  `step` callback. An external loop (timer, coroutine, event loop) calls
  `machine:step()` and uses the returned delay to schedule the next call.
- **Shared context** — all callbacks receive the same context table, making it
  easy to share data across states without global variables.
- **Cheap instances** — the config is validated and copied once when the class
  is created; individual instances are lightweight and fast to create.

## 1.2 Synopsis

The library uses a class/instance pattern:

1. **Class creation** — `StateMachine(config)` validates the configuration and copies the states table. This is the expensive step, done once.
2. **Instance creation** — Calling the class with an optional context table creates an instance. This is cheap and can be done many times.

```lua
local StateMachine = require "statemachine"

-- Create a class (done once)
local DoorLock = StateMachine({
    initial_state = "locked",
    states = {
        locked = {
            enter = function(self, ctx, from) -- Note: from is `nil` when first started!
                -- Executed when this state is entered (called from `transition_to`).
                -- The return value from this callback is passed back to user code as the result
                -- from `transition_to`.
                -- When using the `step` method to drive progress, then by convention the
                -- return value should be the number of seconds before the next call to `step`.
                return 1  -- call the step method in 1 second (return nil to not call `step`)
            end,
            leave = function(self, ctx, to)
                -- executed when the state is changing away from this state (called from `transition_to`).
                -- No relevant return values.
            end,
            step = function(self, ctx)
                -- This callback can be used to drive the progress from an external runloop.
                -- This is optional. If used then this callback should (by convention) return
                -- the delay until the next time `step` should be called.
                -- If `transition_to` is called from this callback, then you probably want to
                -- return its results (the result from the new-state's `enter` callback). Since
                -- that will be the delay the new-state has requested for calling its `step`
                -- method.
                if ctx.some_condition then
                    local ok_delay, err = self:transition_to("unlocked")
                    if ok_delay then
                        -- the transition is allowed
                        return ok_delay -- return the delay to call `step`
                    else
                        -- The transition was not allowed
                        print("failed to transition to 'unlocked': " .. err)
                    end
                end
                return 1  -- call the step method again in 1 second to retry (return nil to not call it again)
            end,
            transitions = {
                -- this table defines the allowed transition from this state (static)
                unlocked = function(self, ctx, to)
                    -- The callback should check if the transition can be made (dynamic).
                    -- If not it should return nil+"reason". If ok, then return true.
                    if not ctx.key_available then
                        return nil, "no key available"
                    end
                    return true  -- allow the transition
                end,
            },
        },
        unlocked = {
            enter = function(self, ctx, from) end,
            leave = function(self, ctx, to) end,
            transitions = {
                locked = function(self, ctx, to) return true end,
            },
        },
    },
})

-- Create instances (cheap, each with its own context)
local door1 = DoorLock({ count = 0 })
local door2 = DoorLock({ count = 0 })
```

## 1.3 Callbacks and order

Each state can define `enter`, `leave`,and `step` callbacks, and each transition defines a callback that also acts as a **guard**. When transitioning from state A to state B, the sequence is:

1. **Transition callback (guard)** — must return a truthy value to allow the transition. Return `nil, "reason"` to block it; `transition_to` will then return `nil, err` without touching the states.
2. **Leave callback**
3. The current state is updated (`get_current_state()` now returns the new state)
4. **Enter callback**

_Note:_ On initial state entry (during instance creation), only the `enter` callback fires with `source_state` as `nil`.


## 1.4 Time-driven states and the step loop

The enables easy retry and timeout implementations.

State can define a `step(self, ctx)` callback alongside `enter` and `leave`.
Calling `machine:step()` invokes the current state's `step` callback and returns its
result.

By convention the return value is the number of seconds the caller should wait before
calling `step` again, or `nil` when no further stepping is needed. States that
have no time-driven behaviour simply return nothing:

```lua
step = function(self, ctx) end  -- no-op; signals no stepping needed
```

`transition_to` returns whatever the `enter` callback of the new state returns (or
`true` when `enter` returns nothing). This means that when `step` calls
`transition_to`, it must `return` that result so the new state's requested delay
propagates back to the external loop:

```lua
step = function(self, ctx)
    if timed_out(ctx) then
        return self:transition_to("failed")  -- 'return' is required here (assumes transition always succeeds)
    end
    return 1
end
```

The external loop is entirely user code; the state machine imposes no scheduler.

```lua
local now = os.time  -- replace with a higher-resolution clock if needed

-- A state machine that retries a task up to 3 times before failing.
local Retrier = StateMachine({
    initial_state = "trying",
    states = {
        trying = {
            enter = function(self, ctx, from)
                ctx.attempts = (ctx.attempts or 0) + 1
                ctx.deadline = now() + ctx.timeout
                start_task(ctx)
                return 1  -- request first step in 1 second
            end,
            leave = function(self, ctx) end,
            step = function(self, ctx)
                if ctx.done then
                    return self:transition_to("succeeded")   -- task completed
                end
                if now() < ctx.deadline then
                    return 1                                 -- retry in 1 second
                end
                if ctx.attempts >= 3 then
                    return self:transition_to("failed")      -- give up
                end
                return self:transition_to("trying")          -- retry (re-enter)
            end,
            transitions = {
                trying    = function(self, ctx) return true end,
                succeeded = function(self, ctx) return true end,
                failed    = function(self, ctx) return true end,
            },
        },
        succeeded = {
            enter = function(self, ctx)
                print("done after "..ctx.attempts.." attempt(s)")
            end,
            leave = function(self, ctx) end,
            step  = function(self, ctx) end,
            transitions = {},
        },
        failed = {
            enter = function(self, ctx)
                print("failed after "..ctx.attempts.." attempt(s)")
            end,
            leave = function(self, ctx) end,
            step  = function(self, ctx) end,
            transitions = {},
        },
    },
})


-- External loop: the caller decides how to wait (sleep, coroutine yield, libuv timer…)
local machine = Retrier({ timeout = 5, done = false })
local delay = machine:step()
while delay do
    os.execute("sleep "..delay)
    delay = machine:step()
end
```

The step logic and timing are plain user code inside the callbacks. The state machine
only provides the `step` delegation and the return-value propagation through
`transition_to` — everything else is up to the caller.
