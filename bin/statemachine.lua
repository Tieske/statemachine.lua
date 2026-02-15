#!/usr/bin/env lua

--- CLI application.
-- Description goes here.
-- @script statemachine
-- @usage
-- # start the application from a shell
-- statemachine --some --options=here

print("Welcome to the statemachine CLI, echoing arguments:")
for i, val in ipairs(arg) do
  print(i .. ":", val)
end
