# Changelog

## [1.0] - 28/01/2026

Initial release of LibEventBus-1.0.

- Added event bus creation via `lib:NewBus(name, safe)` and a global singleton via `lib:GetGlobalBus()`.
- Event registration and management:
	- `RegisterEvent(event, fn)` returns an unregister function.
	- `UnregisterEvent(event, fn)` and `UnregisterAll(event)` for handler cleanup.
	- `RegisterEventOnce(event, fn)` for one-shot handlers.
	- `IsRegistered(event)` to check active handlers.
	- `TriggerEvent(event, ...)` to dispatch custom events.
- Safe dispatch with error handling using `safeCall`; optional fast path when `safe` is false.
- Native WoW event integration via a backing `Frame` (`CreateFrame("Frame")`) with lazy registration and automatic unregistration when no handlers remain.
- Handler list compaction and duplicate prevention to reduce allocations and keep dispatch efficient.
- Hooking support:
	- `HookSecureFunc(frameOrGlobalName, funcName?, handler)` for secure function hooks.
	- `HookScript(frame, scriptName, handler)` for frame script hooks (tracks hooks per-frame to avoid duplicates).
- Requirements: relies on LibStub; library registered as `LibEventBus-1.0` (minor version 1).

### Notes
- Versioning follows LibStub major/minor, with this being the first minor release.
- API is designed for safety-first usage by default (`safe = true`).
