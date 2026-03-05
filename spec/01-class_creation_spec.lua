describe("statemachine class creation", function()

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
            transitions = {
              unlocked = function() return true end,
            },
          },
          unlocked = {
            transitions = {
              locked = function() return true end,
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
              transitions = {},
            },
          },
        })
      end)
    end)


    it("accepts state without enter, leave, or step", function()
      local MyClass = StateMachine({
        initial_state = "idle",
        states = {
          idle = {
            transitions = {},
          },
        },
      })

      assert.is.table(MyClass)
    end)


    it("rejects non-function enter", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              enter = "bad",
              transitions = {},
            },
          },
        })
      end, "state 'idle' field 'enter' must be a function")
    end)


    it("rejects non-function leave", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              leave = "bad",
              transitions = {},
            },
          },
        })
      end, "state 'idle' field 'leave' must be a function")
    end)


    it("rejects non-function step", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {
              step = "bad",
              transitions = {},
            },
          },
        })
      end, "state 'idle' field 'step' must be a function")
    end)


    it("rejects state without transitions table", function()
      assert.has_error(function()
        StateMachine({
          initial_state = "idle",
          states = {
            idle = {},
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
              transitions = {
                active = "not a function",
              },
            },
            active = {
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
              transitions = {
                nonexistent = function() return true end,
              },
            },
          },
        })
      end)
    end)

  end)

end)
