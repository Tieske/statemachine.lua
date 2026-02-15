--- A finite state machine implementation in Lua.
--
-- State machines are defined as a class from a config table, and then
-- instantiated with a context table. The class validates and copies the
-- config once, and instances are cheap to create.
--
-- @copyright Copyright (c) 2026-2026 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.
-- @usage
-- local StateMachine = require "statemachine"
--
-- -- Step 1: Create a class (validates config, copies states — done once)
-- local DoorLock = StateMachine({
--     initial_state = "locked",
--     states = {
--         locked = {
--             enter = function(self, ctx, from) end,   -- Note: from is nil when first started!
--             leave = function(self, ctx, to) end,
--             transitions = {
--                 unlocked = function(self, ctx, to) end,
--             },
--         },
--         unlocked = {
--             enter = function(self, ctx, from) end,
--             leave = function(self, ctx, to) end,
--             transitions = {
--                 locked = function(self, ctx, to) end,
--             },
--         },
--     },
-- })
--
-- -- Step 2: Create instances (cheap — just stores ctx and enters initial state)
-- local door1 = DoorLock({ count = 0 })
-- local door2 = DoorLock({ count = 0 })

local StateMachine = {}

StateMachine._VERSION = "0.0.1"
StateMachine._COPYRIGHT = "Copyright (c) 2026-2026 Thijs Schreijer"
StateMachine._DESCRIPTION = "a finite state machine implementation in Lua"



-- validates the configuration, returns a string with all valid states, for error messages.
local function validate_config(config)
  assert(type(config) == "table", "config must be a table")
  assert(type(config.initial_state) == "string", "config.initial_state must be a string")
  assert(type(config.states) == "table", "config.states must be a table")

  -- collect valid state names
  local state_names = setmetatable({},{
    __tostring = function(self) return "'" .. table.concat(self, "', '") .. "'" end,
  })

  for name in pairs(config.states) do
    assert(type(name) == "string", "state names must be strings")
    state_names[#state_names + 1] = name
  end
  table.sort(state_names)
  assert(#state_names > 0, "config.states must contain at least one state")

  -- validate initial_state exists
  if not config.states[config.initial_state] then
    error("config.initial_state '%s' does not exist in states. Valid states: " .. tostring(state_names))
  end

  -- validate each state
  for name, state in pairs(config.states) do
    assert(type(state) == "table", ("state '%s' must be a table"):format(name))
    assert(type(state.enter) == "function", ("state '%s' must have an 'enter' function"):format(name))
    assert(type(state.leave) == "function", ("state '%s' must have a 'leave' function"):format(name))
    assert(type(state.transitions) == "table", ("state '%s' must have a 'transitions' table"):format(name))

    -- validate transition targets exist and callbacks are functions
    for target, callback in pairs(state.transitions) do
      assert(type(callback) == "function", ("transition from '%s' to '%s' must be a function"):format(name, target))
      assert(config.states[target], ("transition from '%s' references unknown state '%s'. Valid states: %s"):format(
          name, target, tostring(state_names)))
    end
  end

  return state_names
end



-- copy the config states table.
local function copy_config_states(states, err_string)
  local copy = {}
  for name, state in pairs(states) do
    local transitions = {}
    copy[name] = {
      enter = state.enter,
      leave = state.leave,
      transitions = transitions,
    }
    for target, callback in pairs(state.transitions) do
      transitions[target] = callback
    end
  end

  setmetatable(copy, {
    __index = function(_, key)
      error(("unknown state '%s'. Valid states: %s"):format(
        tostring(key), tostring(err_string)), 2)
    end,
    __newindex = function()
      error("the states table is read-only", 2)
    end,
  })

  return copy
end



-- Instance metatable
local SMInstance = {}
SMInstance.__index = SMInstance



--- Transition to a specific state.
-- Calls the transition callback, then the leave callback on the current state,
-- and finally the enter callback on the target state.
-- @tparam string new_state the target state name
-- @raise error if the state does not exist or the transition is not allowed
function SMInstance:transition_to(new_state)
  local current_state = self._current_state
  local target_state = self._states[new_state] -- will throw an informative error if not found
  local ctx = self:get_context()

  -- check transition is allowed
  if current_state then -- upon initialization this is nil, hence the check
    local transition_fn = self._states[current_state].transitions[new_state]
    if not transition_fn then
      local targets = {}
      for name in pairs(self._states[current_state].transitions) do
        targets[#targets + 1] = name
      end
      table.sort(targets)
      local valid = #targets > 0 and ("'" .. table.concat(targets, "', '") .. "'") or "(none)"
      error(("no transition from '%s' to '%s'. Valid transitions from '%s': %s"):format(
        current_state, new_state, current_state, valid), 2)
    end

    -- leave old state
    transition_fn(self, ctx, new_state)
    self._states[current_state].leave(self, ctx, new_state)
  end

  -- enter new state
  self._current_state = new_state
  target_state.enter(self, ctx, current_state)
end



--- Get the current state name.
-- @treturn string the current state name
function SMInstance:get_current_state()
  return self._current_state
end



--- Check if a transition to the given state is valid from the current state.
-- @tparam string state the target state name
-- @treturn boolean true if the transition is valid
function SMInstance:can_transition_to(state)
  local current_state = self._states[self._current_state]
  return current_state.transitions[state] ~= nil
end



--- Get the shared context table.
-- @treturn table the context table
function SMInstance:get_context()
  return self._ctx
end



-- Class metatable
local SMClass = {}
SMClass.__index = SMClass

--- Create a new instance from this class.
-- @tparam[opt={}] table ctx the shared context table
-- @treturn SMInstance a new state machine instance
-- @name SMClass
function SMClass:__call(ctx)
  ctx = ctx or {}
  assert(type(ctx) == "table", "ctx must be a table")

  local instance = setmetatable({
    _current_state = nil,
    _ctx = ctx,
    _states = self._states,
  }, SMInstance)

  instance:transition_to(self._initial_state)

  return instance
end



--- Create a new state machine class from a config table.
-- @tparam table config the configuration table
-- @tparam string config.initial_state the name of the initial state
-- @tparam table config.states table of state definitions, each with `enter`, `leave`, and `transitions`
-- @treturn SMClass a new state machine class, callable to create instances
local function new(config)
  local err_states = validate_config(config)

  local class = setmetatable({
    _initial_state = config.initial_state,
    _states = copy_config_states(config.states, err_states),
  }, SMClass)

  return class
end



return setmetatable(StateMachine, {
  __call = function(_, config)
    return new(config)
  end,
})
