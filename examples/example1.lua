#!/usr/bin/env lua
--- Example: A smart door lock state machine
--
-- This example demonstrates a door lock system with three states:
-- - locked: Door is locked and closed
-- - unlocked: Door is unlocked but still closed
-- - open: Door is open
--
-- The state machine tracks failed unlock attempts and auto-locks
-- after the door closes.

-- Add src directory to package path
package.path = "./src/?.lua;./src/?/init.lua;" .. package.path

local StateMachine = require "statemachine"

-- Create a state machine for a smart door lock
local door = StateMachine({
  initial_state = "locked",

  -- Context holds shared state across all callbacks
  ctx = {
    failed_attempts = 0,
    max_attempts = 3,
    log = {},
  },

  states = {
    locked = {
      enter = function(self, ctx, from)
        table.insert(ctx.log, string.format("Door locked (from: %s)", from or "init"))
        if from == "unlocked" then
          print("🔒 Door auto-locked after closing")
        else
          print("🔒 Door is locked")
        end
      end,

      leave = function(self, ctx, to)
        if to == "unlocked" then
          print("✓ Unlock successful!")
        end
      end,

      transitions = {
        unlocked = function(self, ctx, to)
          -- Simulate checking a passcode
          if ctx.failed_attempts >= ctx.max_attempts then
            error("Too many failed attempts. Lock is disabled.")
          end

          table.insert(ctx.log, "Transition: locked -> unlocked")
        end,
      },
    },

    unlocked = {
      enter = function(self, ctx, from)
        table.insert(ctx.log, string.format("Door unlocked (from: %s)", from))
        print("🔓 Door is unlocked. You can now open it.")
        ctx.failed_attempts = 0  -- Reset failed attempts
      end,

      leave = function(self, ctx, to)
        if to == "open" then
          print("🚪 Opening door...")
        end
      end,

      transitions = {
        locked = function(self, ctx, to)
          table.insert(ctx.log, "Transition: unlocked -> locked")
        end,

        open = function(self, ctx, to)
          table.insert(ctx.log, "Transition: unlocked -> open")
        end,
      },
    },

    open = {
      enter = function(self, ctx, from)
        table.insert(ctx.log, string.format("Door opened (from: %s)", from))
        print("🚪 Door is now open")
      end,

      leave = function(self, ctx, to)
        print("🚪 Closing door...")
      end,

      transitions = {
        unlocked = function(self, ctx, to)
          table.insert(ctx.log, "Transition: open -> unlocked")
        end,
      },
    },
  },
})

-- Demonstrate the state machine
print("\n=== Smart Door Lock Demo ===\n")

-- Try to open without unlocking
print("\n1. Trying to open a locked door:")
if door:can_transition_to("open") then
  door:transition_to("open")
else
  print("❌ Cannot open: door is locked!")
end

-- Unlock the door
print("\n2. Unlocking the door:")
door:transition_to("unlocked")

-- Now open it
print("\n3. Opening the unlocked door:")
door:transition_to("open")

-- Close it
print("\n4. Closing the door:")
door:transition_to("unlocked")

-- Auto-lock when going back to locked
print("\n5. Locking the door:")
door:transition_to("locked")

-- Show the current state
print(string.format("\n📊 Current state: %s", door:get_current_state()))

-- Show the activity log
print("\n📜 Activity log:")
local ctx = door:get_context()
for i, entry in ipairs(ctx.log) do
  print(string.format("  %d. %s", i, entry))
end

-- Demonstrate error handling
print("\n6. Attempting invalid transition:")
local success, err = pcall(function()
  door:transition_to("open")  -- Can't go directly from locked to open
end)

if not success then
  print(string.format("❌ Error: %s", err:match("([^\n]+)")))
end

print("\n=== Demo Complete ===")
