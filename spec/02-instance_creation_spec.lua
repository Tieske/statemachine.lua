describe("statemachine instance creation", function()

  local StateMachine

  before_each(function()
    StateMachine = require "statemachine"
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

      EnterClass()

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

end)
