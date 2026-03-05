# 1. Introduction

## 1.1 Overview

statemachine.lua is a finite state machine library for Lua. It provides a simple, callback-driven API for defining states, transitions, and shared context.

## 1.2 Two-level architecture

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
            enter = function(self, ctx, from) end,  -- Note: from is `nil` when first started!
            leave = function(self, ctx, to) end,
            transitions = {
                unlocked = function(self, ctx, to) return true end,
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

Each state defines `enter` and `leave` callbacks, and each transition defines a callback that also acts as a **guard**. When transitioning from state A to state B, the sequence is:

1. **Transition callback (guard)** — must return a truthy value to allow the transition. Return `nil, "reason"` to block it; `transition_to` will then return `nil, err` without touching the states.
2. **Leave callback**
3. The current state is updated (`get_current_state()` now returns the new state)
4. **Enter callback**

_Note:_ On initial state entry (during instance creation), only the `enter` callback fires with `source_state` as `nil`.

```lua
transitions = {
    unlocked = function(self, ctx, to)
        if not ctx.has_key then
            return nil, "key required to unlock"
        end
        return true
    end,
}

local ok, err = instance:transition_to("unlocked")
-- ok = true, or ok = nil and err = "key required to unlock"
```

## 1.4 Initializing context with a virtual init state

Instead of passing a pre-populated context table, you can use a virtual `_init` state
that sets up the context and immediately transitions to the first real state:

```lua
local StateMachine = require "statemachine"
local allow = function() return true end  -- transition guard that always permits

local Counter = StateMachine({
    initial_state = "_init",
    states = {
        _init = {
            enter = function(self, ctx)  -- initialize and move on
                ctx.count = 0
                ctx.log = {}
                return self:transition_to("do_work")
            end,
            transitions = {
                do_work = allow,
            },
        },
        do_work = {
            enter = function(self, ctx, from)
                table.insert(ctx.log, "entered do_work")
                -- at some point:
                return self:transition_to("_done")
            end,
            transitions = {
              _done = allow,
            },
        },
        _done = {  -- no way out of this state...
          -- potentially do some teardown and cleanup in enter here
          transitions = {}
        }
    },
})

-- Context is initialized by _init, no need to pass values
local c = Counter()
print(c:get_current_state())         -- "do_work"
print(c:get_context().count)         -- 0
```

This pattern keeps the context initialization co-located with the state machine
definition, so callers can create instances with just `Counter()` and get a
fully initialized context.

Similarly, a `_done` state can be defined that has no transitions out of that state, to ensure it doesn't get used beyond its lifetime.

## 1.5 Time-driven states and the step loop

Every state must define a `step(self, ctx)` callback alongside `enter` and `leave`.
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
        return self:transition_to("failed")  -- 'return' is required here
    end
    return 1
end
```

Without the `return`, the delay from the new state's `enter` is discarded and the
external loop receives `nil`, stopping the loop prematurely.

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
                if now() < ctx.deadline then return 1 end   -- still waiting
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
    -- wait `delay` seconds here (os.execute("sleep "..delay), coroutine.yield, etc.)
    delay = machine:step()
end
```

The step logic and timing are plain user code inside the callbacks. The state machine
only provides the `step` delegation and the return-value propagation through
`transition_to` — everything else is up to the caller.
