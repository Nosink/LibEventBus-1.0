# LibEventBus-1.0

LibEventBus-1.0 is a lightweight event bus for World of Warcraft addons. It wraps WoW native events behind a clean API, allow pub/sub custom event messages, adds safe dispatch and one-shot listeners, and provides helpers to securely hook functions and frame scripts.

## Features
- Safe-by-default handler dispatch; optional fast path.
- Lazy native event registration with automatic unregistration when no handlers remain.
- One-shot handlers (`RegisterEventOnce`).
- Duplicate prevention and handler list compaction.
- Secure hooks for functions and frame scripts.

## Quick Start

```lua
local bus = LibStub("LibEventBus-1.0")
if not bus then return

-- Register a native event handler
local stop = bus:RegisterEvent("PLAYER_LOGIN", function(event)
	print("Logged in:", event)
end)
```

## One-Shot Example

```lua
bus:RegisterEventOnce("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
	print("Entered world once.", isInitialLogin, isReloadingUi)
end)
```

## Custom Events

```lua
local unsub = bus:RegisterEvent("MY_ADDON_READY", function(event, data)
	print("Custom:", event, data.msg)
end)

bus:TriggerEvent("MY_ADDON_READY", { msg = "Hello" })
unsub()
```

## Hooks

```lua
-- Hook a global function by name
bus:HookSecureFunc("ToggleSpellBook", function()
	print("Spellbook toggled")
end)

-- Hook a frame method
bus:HookSecureFunc(GameMenuFrame, "Show", function()
	print("GameMenuFrame Show")
end)

-- Hook a frame script
bus:HookScript(GameMenuFrame, "OnShow", function(self)
	print("GameMenuFrame OnShow")
end)
```

## Safety vs Speed
- Default `safe = true`: errors reported to `geterrorhandler()`.
- Create fast bus if you trust handlers:

```lua
local fastBus = EB:NewBus("FastBus", false)
```

## API
- `lib:NewBus(name?, safe?)`
- `lib:GetGlobalBus()`
- `bus:RegisterEvent(event, fn)` → `unregister()`
- `bus:RegisterEventOnce(event, fn)` → `unregister()`
- `bus:UnregisterEvent(event, fn)`
- `bus:UnregisterAll(event)`
- `bus:TriggerEvent(event, ...)`
- `bus:IsRegistered(event)`
- `bus:HookSecureFunc(frameOrName, funcName?, handler)`
- `bus:HookScript(frame, script, handler)`

## Notes
- Native events are registered lazily and unregistered automatically when no handlers remain.
- Duplicate handlers are prevented; lists compact after dispatch.

## License
- GPL-3.0 — see LICENSE.