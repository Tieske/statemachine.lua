# Guidance for AI agents

This file is the main entry point for AI tools working in this repository. It provides project context and points to authoritative sources for conventions.

## What this project is

statemachine.lua is a finite state machine library for Lua. It uses a two-level class/instance architecture: `StateMachine(config)` creates a class (validates and copies config once), and calling the class creates cheap instances with their own context.

## Project layout

| Path | Purpose |
|------|---------|
| `src/statemachine/` | Lua source (module entry point: `init.lua`) |
| `spec/` | Tests (Busted); see [`spec/AGENTS.md`](spec/AGENTS.md) for test conventions |
| `examples/` | Example scripts |
| `.luacheckrc` | LuaCheck lint configuration (authoritative for lint) |
| `.editorconfig` | Editor/formatting preferences |
| `config.ld` | ldoc configuration for API docs |

## Testing

Testing is done using [Busted](https://lunarmodules.github.io/busted/) and [LuaCheck](https://github.com/mpeterv/luacheck):

- Run tests: `busted`
- Run linter: `luacheck .`

**Every new feature, bug fix, or behavioural change MUST be accompanied by tests.** Do not submit code changes without corresponding test coverage. If a test is genuinely not applicable, document the reason.

For test file conventions, isolation rules, code style, and vertical whitespace rules, see **[spec/AGENTS.md](spec/AGENTS.md)**.

## Lua compatibility

All code MUST be compatible with the Lua versions specified in the [rockspec](statemachine-scm-1.rockspec). This includes LuaJIT. Do not use features specific to a single Lua version without a compatibility shim. Common pitfalls:

## Code style

Code style is defined by [.luacheckrc](.luacheckrc) and [.editorconfig](.editorconfig). Ensure `luacheck .` passes with zero warnings before committing.
