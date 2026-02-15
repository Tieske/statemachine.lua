describe("statemachine", function()
  local StateMachine

  before_each(function()
    StateMachine = require "statemachine"
  end)


  describe("module loading", function()
    it("loads the module", function()
      assert.is.table(StateMachine)
      assert.is.string(StateMachine._VERSION)
      assert.is.string(StateMachine._COPYRIGHT)
      assert.is.string(StateMachine._DESCRIPTION)
    end)
  end)


  describe("class creation", function()
    it("creates a class with minimal config", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            transitions = {},
          },
        },
      })

      assert.is.table(MyClass)
    end)

    it("creates a class with multiple states", function()
      local MyClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              locked = function() end,
            },
          },
        },
      })

      assert.is.table(MyClass)
    end)

    it("rejects config that is not a table", function()
      assert.has_error(function()
        StateMachine("not a table")
      end, "config must be a table")
    end)

    it("rejects config without initial_state", function()
      assert.has_error(function()
        StateMachine({
          states = {
            idle = {
              enter = function() end,
              leave = function() end,
              transitions = {},
            },
          },
        })
      end, "config.initial_state must be a string")
    end)

    it("rejects config without states", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
        })
      end, "config.states must be a table")
    end)

    it("rejects config with empty states", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {},
        })
      end, "config.states must contain at least one state")
    end)

    it("rejects config with non-string state names", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            [1] = {
              enter = function() end,
              leave = function() end,
              transitions = {},
            },
          },
        })
      end, "state names must be strings")
    end)

    it("rejects config with non-existent initial_state", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "nonexistent",
          states = {
            idle = {
              enter = function() end,
              leave = function() end,
              transitions = {},
            },
          },
        })
      end)
    end)

    it("rejects state without enter function", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              leave = function() end,
              transitions = {},
            },
          },
        })
      end, "state 'idle' must have an 'enter' function")
    end)

    it("rejects state without leave function", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              enter = function() end,
              transitions = {},
            },
          },
        })
      end, "state 'idle' must have a 'leave' function")
    end)

    it("rejects state without transitions table", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              enter = function() end,
              leave = function() end,
            },
          },
        })
      end, "state 'idle' must have a 'transitions' table")
    end)

    it("rejects transition with non-function callback", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              enter = function() end,
              leave = function() end,
              transitions = {
                active = "not a function",
              },
            },
            active = {
              enter = function() end,
              leave = function() end,
              transitions = {},
            },
          },
        })
      end, "transition from 'idle' to 'active' must be a function")
    end)

    it("rejects transition to non-existent state", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              enter = function() end,
              leave = function() end,
              transitions = {
                nonexistent = function() end,
              },
            },
          },
        })
      end)
    end)
  end)


  describe("instance creation", function()
    local MyClass

    before_each(function()
      MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            transitions = {},
          },
        },
      })
    end)

    it("creates an instance with default context", function()
      local sm = MyClass()

      assert.is.table(sm)
      assert.equals("idle", sm:get_current_state())
      assert.same({}, sm:get_context())
    end)

    it("creates an instance with provided context", function()
      local ctx = { count = 0 }
      local sm = MyClass(ctx)

      assert.equals(ctx, sm:get_context())
    end)

    it("calls enter callback on initial state", function()
      local entered = false
      local from_state = "NOT_SET"

      local EnterClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function(self, ctx, from)
              entered = true
              from_state = from
            end,
            leave = function() end,
            transitions = {},
          },
        },
      })

      local sm = EnterClass()

      assert.is_true(entered)
      assert.is_nil(from_state)  -- from should be nil on initial state
    end)

    it("rejects non-table context", function()
      assert.has_error(function()
        MyClass("not a table")
      end, "ctx must be a table")
    end)

    it("creates independent instances from the same class", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function(self, ctx) ctx.enters = (ctx.enters or 0) + 1 end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function(self, ctx) ctx.enters = (ctx.enters or 0) + 1 end,
            leave = function() end,
            transitions = {
              locked = function() end,
            },
          },
        },
      })

      local ctx1 = { enters = 0 }
      local ctx2 = { enters = 0 }
      local door1 = DoorClass(ctx1)
      local door2 = DoorClass(ctx2)

      -- both start in locked
      assert.equals("locked", door1:get_current_state())
      assert.equals("locked", door2:get_current_state())

      -- transition door1 only
      door1:transition_to("unlocked")
      assert.equals("unlocked", door1:get_current_state())
      assert.equals("locked", door2:get_current_state())

      -- contexts are independent
      assert.equals(2, ctx1.enters)  -- initial enter + transition enter
      assert.equals(1, ctx2.enters)  -- initial enter only
    end)
  end)


  describe("transitions", function()
    it("transitions to a valid state", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              locked = function() end,
            },
          },
        },
      })
      local sm = DoorClass()

      sm:transition_to("unlocked")
      assert.equals("unlocked", sm:get_current_state())

      sm:transition_to("locked")
      assert.equals("locked", sm:get_current_state())
    end)

    it("rejects transition to invalid state", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              locked = function() end,
            },
          },
        },
      })
      local sm = DoorClass()

      sm:transition_to("unlocked")

      assert.error_matches(function()
        sm:transition_to("locked_again")  -- non-existent state
      end, "unknown state 'locked_again'. Valid states: 'locked', 'unlocked'")
    end)

    it("rejects transition not in current state's transitions", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            transitions = {},  -- no transitions back
          },
        },
      })
      local sm = DoorClass()

      sm:transition_to("unlocked")

      assert.error_matches(function()
        sm:transition_to("locked")
      end, "no transition from 'unlocked' to 'locked'")
    end)

    it("calls callbacks in correct order", function()
      local order = {}

      local MyClass = StateMachine({
        initial_state = "state_a",
        states = {
          state_a = {
            enter = function() table.insert(order, "a_enter") end,
            leave = function() table.insert(order, "a_leave") end,
            transitions = {
              state_b = function() table.insert(order, "a_to_b") end,
            },
          },
          state_b = {
            enter = function() table.insert(order, "b_enter") end,
            leave = function() table.insert(order, "b_leave") end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      -- initial state should have called enter
      assert.same({ "a_enter" }, order)

      order = {}
      sm:transition_to("state_b")

      -- order should be: transition callback, leave old, enter new
      assert.same({ "a_to_b", "a_leave", "b_enter" }, order)
    end)

    it("passes self, context, and target/source to callbacks", function()
      local ctx = { value = 42 }
      local enter_args = {}
      local leave_args = {}
      local transition_args = {}

      local MyClass = StateMachine({
        initial_state = "state_a",
        states = {
          state_a = {
            enter = function(self, c, from)
              enter_args = { self, c, from }
            end,
            leave = function(self, c, to)
              leave_args = { self, c, to }
            end,
            transitions = {
              state_b = function(self, c, to)
                transition_args = { self, c, to }
              end,
            },
          },
          state_b = {
            enter = function(self, c, from)
              enter_args = { self, c, from }
            end,
            leave = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass(ctx)

      -- reset after initial enter
      enter_args = {}

      sm:transition_to("state_b")

      assert.equals(sm, transition_args[1])
      assert.equals(ctx, transition_args[2])
      assert.equals("state_b", transition_args[3])

      assert.equals(sm, leave_args[1])
      assert.equals(ctx, leave_args[2])
      assert.equals("state_b", leave_args[3])

      assert.equals(sm, enter_args[1])
      assert.equals(ctx, enter_args[2])
      assert.equals("state_a", enter_args[3])
    end)

    it("allows context modification during transitions", function()
      local ctx = { count = 0 }

      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function(self, c) c.count = c.count + 1 end,
            leave = function(self, c) c.count = c.count + 10 end,
            transitions = {
              active = function(self, c) c.count = c.count + 100 end,
            },
          },
          active = {
            enter = function(self, c) c.count = c.count + 1000 end,
            leave = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass(ctx)

      -- initial enter: 0 + 1 = 1
      assert.equals(1, ctx.count)

      sm:transition_to("active")
      -- transition: 1 + 100 = 101
      -- leave: 101 + 10 = 111
      -- enter: 111 + 1000 = 1111
      assert.equals(1111, ctx.count)
    end)
  end)


  describe("can_transition_to", function()
    it("returns true for valid transitions", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              unlocked = function() end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            transitions = {
              locked = function() end,
            },
          },
        },
      })
      local sm = DoorClass()

      assert.is_true(sm:can_transition_to("unlocked"))
      assert.is_false(sm:can_transition_to("locked"))

      sm:transition_to("unlocked")

      assert.is_false(sm:can_transition_to("unlocked"))
      assert.is_true(sm:can_transition_to("locked"))
    end)

    it("returns false for invalid transitions", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.is_false(sm:can_transition_to("nonexistent"))
      assert.is_false(sm:can_transition_to("idle"))
    end)
  end)


  describe("state isolation", function()
    it("prevents adding states after creation", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.has_error(function()
        sm._states.new_state = {}
      end, "the states table is read-only")
    end)

    it("provides helpful error for accessing non-existent state", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.error_matches(function()
        local _ = sm._states.nonexistent
      end, "unknown state 'nonexistent'. Valid states: 'idle'")
    end)
  end)


  describe("complex state machine", function()
    it("handles multi-state workflow", function()
      local ctx = { log = {} }

      local WorkflowClass = StateMachine({
        initial_state = "init",
        states = {
          init = {
            enter = function(self, c) table.insert(c.log, "init") end,
            leave = function() end,
            transitions = {
              ready = function() end,
            },
          },
          ready = {
            enter = function(self, c) table.insert(c.log, "ready") end,
            leave = function() end,
            transitions = {
              running = function() end,
              error = function() end,
            },
          },
          running = {
            enter = function(self, c) table.insert(c.log, "running") end,
            leave = function() end,
            transitions = {
              done = function() end,
              error = function() end,
            },
          },
          done = {
            enter = function(self, c) table.insert(c.log, "done") end,
            leave = function() end,
            transitions = {
              ready = function() end,
            },
          },
          error = {
            enter = function(self, c) table.insert(c.log, "error") end,
            leave = function() end,
            transitions = {
              ready = function() end,
            },
          },
        },
      })
      local sm = WorkflowClass(ctx)

      assert.equals("init", sm:get_current_state())

      sm:transition_to("ready")
      sm:transition_to("running")
      sm:transition_to("done")
      sm:transition_to("ready")
      sm:transition_to("error")
      sm:transition_to("ready")

      assert.same({ "init", "ready", "running", "done", "ready", "error", "ready" }, ctx.log)
      assert.equals("ready", sm:get_current_state())
    end)
  end)

end)
