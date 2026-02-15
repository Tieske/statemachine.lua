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

end)
