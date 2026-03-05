describe("statemachine transitions", function()

  local StateMachine

  before_each(function()
    StateMachine = require "statemachine"
  end)



  describe("transitions", function()

    it("transitions to a valid state", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              unlocked = function() return true end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              locked = function() return true end,
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
            step = function() end,
            transitions = {
              unlocked = function() return true end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              locked = function() return true end,
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
            step = function() end,
            transitions = {
              unlocked = function() return true end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
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
            step = function() end,
            transitions = {
              state_b = function() table.insert(order, "a_to_b") return true end,
            },
          },
          state_b = {
            enter = function() table.insert(order, "b_enter") end,
            leave = function() table.insert(order, "b_leave") end,
            step = function() end,
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
      local enter_args
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
            step = function() end,
            transitions = {
              state_b = function(self, c, to)
                transition_args = { self, c, to }
                return true
              end,
            },
          },
          state_b = {
            enter = function(self, c, from)
              enter_args = { self, c, from }
            end,
            leave = function() end,
            step = function() end,
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
            step = function() end,
            transitions = {
              active = function(self, c) c.count = c.count + 100 return true end,
            },
          },
          active = {
            enter = function(self, c) c.count = c.count + 1000 end,
            leave = function() end,
            step = function() end,
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


    it("guard blocks transition and returns nil+err", function()
      local MyClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              unlocked = function(self, ctx)
                if not ctx.has_key then
                  return nil, "key required"
                end
                return true
              end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {},
          },
        },
      })

      local sm = MyClass({ has_key = false })
      local ok, err = sm:transition_to("unlocked")

      assert.is_nil(ok)
      assert.equals("key required", err)
      assert.equals("locked", sm:get_current_state())  -- state unchanged
    end)


    it("transition_to returns enter's return value on success", function()
      local MyClass = StateMachine({
        initial_state = "a",
        states = {
          a = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              b = function() return true end,
              c = function() return true end,
              d = function() return true end,
            },
          },
          b = {
            enter = function() return 5 end,  -- requests 5s delay
            leave = function() end,
            step = function() end,
            transitions = {},
          },
          c = {
            enter = function() end,  -- returns nothing
            leave = function() end,
            step = function() end,
            transitions = {},
          },
          d = {
            enter = function() return false end,  -- explicitly returns false
            leave = function() end,
            step = function() end,
            transitions = {},
          },
        },
      })
      local sm_b = MyClass()
      assert.equals(5, sm_b:transition_to("b"))  -- enter returned 5

      local sm_c = MyClass()
      assert.is_true(sm_c:transition_to("c"))  -- enter returned nothing → true

      local sm_d = MyClass()
      assert.is_false(sm_d:transition_to("d"))  -- enter returned false, preserved
    end)

  end)



  describe("has_transition_to", function()

    it("returns true for valid transitions", function()
      local DoorClass = StateMachine({
        initial_state = "locked",
        states = {
          locked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              unlocked = function() return true end,
            },
          },
          unlocked = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {
              locked = function() return true end,
            },
          },
        },
      })
      local sm = DoorClass()

      assert.is_true(sm:has_transition_to("unlocked"))
      assert.is_false(sm:has_transition_to("locked"))

      sm:transition_to("unlocked")

      assert.is_false(sm:has_transition_to("unlocked"))
      assert.is_true(sm:has_transition_to("locked"))
    end)


    it("returns false for invalid transitions", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.is_false(sm:has_transition_to("nonexistent"))
      assert.is_false(sm:has_transition_to("idle"))
    end)

  end)



  describe("step", function()

    it("calls the current state's step callback and returns its result", function()
      local MyClass = StateMachine({
        initial_state = "waiting",
        states = {
          waiting = {
            enter = function() end,
            leave = function() end,
            step = function() return 2 end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.equals(2, sm:step())
    end)


    it("returns nil when step callback returns nothing", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            enter = function() end,
            leave = function() end,
            step = function() end,
            transitions = {},
          },
        },
      })
      local sm = MyClass()

      assert.is_nil(sm:step())
    end)


    it("propagates delay from new state's enter when step triggers a transition", function()
      local MyClass = StateMachine({
        initial_state = "sending",
        states = {
          sending = {
            enter = function() return 1 end,
            leave = function() end,
            step = function(self, ctx)
              if ctx.done then
                return self:transition_to("done")  -- propagates enter's return
              end
              return 1
            end,
            transitions = {
              done = function() return true end,
            },
          },
          done = {
            enter = function() return 99 end,  -- signals "call me in 99s"
            leave = function() end,
            step = function() end,
            transitions = {},
          },
        },
      })

      local ctx = { done = false }
      local sm = MyClass(ctx)

      assert.equals(1, sm:step())   -- not done yet

      ctx.done = true
      local result = sm:step()      -- triggers transition to "done"
      assert.equals(99, result)     -- enter("done") returned 99
      assert.equals("done", sm:get_current_state())
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
            step = function() end,
            transitions = {
              ready = function() return true end,
            },
          },
          ready = {
            enter = function(self, c) table.insert(c.log, "ready") end,
            leave = function() end,
            step = function() end,
            transitions = {
              running = function() return true end,
              error = function() return true end,
            },
          },
          running = {
            enter = function(self, c) table.insert(c.log, "running") end,
            leave = function() end,
            step = function() end,
            transitions = {
              done = function() return true end,
              error = function() return true end,
            },
          },
          done = {
            enter = function(self, c) table.insert(c.log, "done") end,
            leave = function() end,
            step = function() end,
            transitions = {
              ready = function() return true end,
            },
          },
          error = {
            enter = function(self, c) table.insert(c.log, "error") end,
            leave = function() end,
            step = function() end,
            transitions = {
              ready = function() return true end,
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
