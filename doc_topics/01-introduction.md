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
                unlocked = function(self, ctx, to) end,
            },
        },
        unlocked = {
            enter = function(self, ctx, from) end,
            leave = function(self, ctx, to) end,
            transitions = {
                locked = function(self, ctx, to) end,
            },
        },
    },
})

-- Create instances (cheap, each with its own context)
local door1 = DoorLock({ count = 0 })
local door2 = DoorLock({ count = 0 })
```

## 1.3 Callbacks and order

Each state defines `enter` and `leave` callbacks, and each transition defines a callback. When transitioning from state A to state B, the callbacks fire in this order:

1. **Transition callback**
2. **Leave callback**
3. The current state is updated (`get_current_state()` now returns the state transitioned to)
4. **Enter callback**

_Note:_ On initial state entry (during instance creation), only the `enter` callback fires with `source_state` as `nil`.
