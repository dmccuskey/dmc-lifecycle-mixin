# Changelog

## 0.1.1 (2026-09-29)

### Fixed

- A value set during an update, by a setter called from `__commitProperties__()` or `onUpdate`, was held back until some other change asked for an update. The mixin now keeps listening to frames and commits it on the next frame.
- `patch()` raised `assertion failed!` and, past that, left out methods the lifecycle needs. It now adds the whole lifecycle to a plain table, with `onUpdate` and `onProperty` as methods (`obj:onUpdate( func )`).
- Removing an object with no update waiting printed Solar2D's `listener not found` warning.
- `onProperty`'s event had no `target`; it now has the object, like `onUpdate`'s.

### Added

- `VERSION` in the table the module returns.
- The module loads the boot loader (`dmc_corona_boot`), like the other DMC Solar2D libraries.
- Unit tests: `tests/run_unit.sh`, plain Lua 5.1.

### Changed

- Rebuilt with dmc-corona-boot 1.6.0 and the current DMC-Lua-Library.
