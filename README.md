# dmc-lifecycle-mixin

Batch property changes on an object in a Solar2D (formerly Corona SDK) app: however many properties change during a frame, the object redraws once, on the next frame.

dmc-lifecycle-mixin is a mixin for classes made with [lua-class](https://github.com/dmccuskey/lua-class) or [lua-objects](https://github.com/dmccuskey/lua-objects). A setter marks the object as changed with `__invalidateProperties__()`; on the next `enterFrame` the mixin calls the class's `__commitProperties__()`, once. The widgets of [DMC-Corona-UI](https://github.com/dmccuskey/DMC-Corona-UI) are built on it:

```lua
function Score.__setters:points( value )
	self._points = value
	self:__invalidateProperties__()  -- redraw on the next frame
end

function Score:__commitProperties__()
	self._text.text = self._points + self._bonus
end
```

## Features

- One redraw per frame, however many properties were set
- An `onUpdate` callback after each redraw
- Listens to `enterFrame` only while a change is waiting
- Mixes into any lua-class class, alongside other parents such as lua-objects' `ObjectBase`
- One small file, no plugins needed; MIT licensed

## Quick Start

The following code will get you up and running in about 10 minutes in the Solar2D Simulator on macOS or Windows. It makes a score display whose values are set several times in a row but redrawn once, and then changes it every second.

Prerequisites: the [Solar2D](https://solar2d.com/) Simulator and a copy of this repository (`git clone https://github.com/dmccuskey/dmc-lifecycle-mixin.git`, or download the ZIP from GitHub).

### 1. Copy the Library into Your Project

Copy these from this repository into the root of your project folder:

```text
dmc_corona_boot.lua     loader for the DMC libraries
dmc_corona.cfg          configuration
dmc_corona/             dmc-lifecycle-mixin, and lua-objects to build classes with
```

**Going further:** keep the libraries in a subfolder, or combine several DMC libraries ([dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md)).

### 2. Write a Class That Redraws Once

Create `main.lua` in the project folder:

```lua
require 'dmc_corona_boot'  -- lets lua_objects find the modules it needs
local Objects = require 'lib.dmc_lua.lua_objects'
local LifecycleMix = require( 'dmc_corona.dmc_lifecycle_mix' ).LifecycleMix

local Score = Objects.newClass( { Objects.ObjectBase, LifecycleMix }, { name="Score" } )

function Score:__init__( params )
	params = params or {}
	self:superCall( LifecycleMix, '__init__', params )
	self:superCall( Objects.ObjectBase, '__init__', params )
	--==--
	self._points = 0
	self._bonus = 0
	self._text = display.newText( "0", display.contentCenterX, display.contentCenterY, native.systemFont, 64 )
end

function Score:__undoInit__()
	self._text:removeSelf()
	self._text = nil
	--==--
	self:superCall( Objects.ObjectBase, '__undoInit__' )
	self:superCall( LifecycleMix, '__undoInit__' )
end

-- each setter stores its value and asks for an update
function Score.__setters:points( value )
	self._points = value
	self:__invalidateProperties__()
end

function Score.__setters:bonus( value )
	self._bonus = value
	self:__invalidateProperties__()
end

-- called on the next frame, once, however many values changed
function Score:__commitProperties__()
	print( "commit", self._points, self._bonus )
	self._text.text = self._points + self._bonus
end

local score = Score:new()
score.points = 10
score.bonus = 5
score.points = 20
print( "three values set" )
```

Open the project in the Simulator. The screen shows `25`, and the console:

```text
three values set
commit	20	5
```

If the console shows `module 'dmc_corona.dmc_lifecycle_mix' not found` instead, `dmc_corona/` is missing from the root of the project folder.

The three assignments call the setters, and each setter asks for an update, but `__commitProperties__()` runs once, on the next frame, after `main.lua` has finished. It sees only the last values. The class calls the mixin's `__init__` and `__undoInit__` next to `ObjectBase`'s, so the mixin can set itself up and stop listening to frames when the object is removed.

### 3. Watch the Updates

Add this to the end of `main.lua`:

```lua
score.onUpdate = function( event )
	print( "updated", event.type, event.target == score )
end

local round = 0
timer.performWithDelay( 1000, function()
	round = round + 1
	score.points = 20 + round * 10
	score.bonus = round
	if round == 3 then
		timer.performWithDelay( 1000, function()
			score:removeSelf()
			print( "removed" )
		end )
	end
end, 3 )
```

The Simulator restarts the app when the file is saved. The number on screen changes every second, to 31, 42 and 53, then disappears. The console shows:

```text
three values set
commit	20	5
updated	lifecycle-updated-event	true
commit	30	1
updated	lifecycle-updated-event	true
commit	40	2
updated	lifecycle-updated-event	true
commit	50	3
updated	lifecycle-updated-event	true
removed
```

`onUpdate` is called after each commit. Each timer tick sets two values and gets one commit.

To update, copy `dmc_corona_boot.lua` and `dmc_corona/` again from the newer version. Keep your own `dmc_corona.cfg` if you have changed it.

## How the Lifecycle Works

The mixin keeps one flag, "properties changed", for the whole object:

1. `__invalidateProperties__()` sets the flag and, unless an update is already waiting, adds an `enterFrame` listener.
2. On the next frame, `__validate__()` runs: if the flag is set, it clears it, calls `__commitProperties__()` and then `onUpdate`. Then it removes the listener.
3. A value set inside `__commitProperties__()` or `onUpdate` sets the flag again: the listener stays, and that value is committed on the following frame. (So a `__commitProperties__()` that sets a value through a setter every time commits on every frame.)

The flag doesn't say which property changed. `__commitProperties__()` applies them all, or the class keeps its own flags (`self._points_dirty = true` in the setter) and checks them there.

## Reference

`require 'dmc_corona.dmc_lifecycle_mix'` returns a table:

| name | what it is |
|---|---|
| `LifecycleMix` | the mixin: a parent class for `newClass()` |
| `VERSION` | the version, e.g. `'0.1.1'` |
| `patch( obj )` | adds the lifecycle to a plain table and returns it (a new one if `obj` is `nil`); see [Patching a Plain Table](#patching-a-plain-table) |

### Methods a Class Calls or Overrides

| method | what it does |
|---|---|
| `__init__( params )` | sets up the lifecycle; call it from the class's `__init__` with `superCall( LifecycleMix, '__init__', params )`. `params.debug_on` turns on debug output |
| `__undoInit__()` | stops a waiting update; call it from the class's `__undoInit__` |
| `__invalidateProperties__()` | marks the object as changed and asks for an update on the next frame |
| `__commitProperties__()` | override: apply the changed values. The mixin's does nothing |
| `__invalidateNextFrame__()` | asks for an update without marking the object as changed; `__commitProperties__()` isn't called unless something else marks it |
| `__validate__()` | runs the update now instead of on the next frame: commits if changed, then stops listening to frames unless the commit changed something again |
| `__dispatchInvalidateNotification__( property, value )` | calls `onProperty` with `{ name=self.EVENT, type=self.PROPERTY_UPDATED, target=self, property=property, value=value }` |
| `resetLifecycle( params )` | clears the state and the callbacks; `__init__` calls it |
| `setDebug( on )` | turns debug output on or off |

### Properties and Constants

| name | what it is |
|---|---|
| `onUpdate` | a function, or `nil`: called after each `__commitProperties__()` with `{ name=self.EVENT, type=self.LIFECYCLE_UPDATED, target=self }`. Set it (`obj.onUpdate = f`) or call it (`obj:onUpdate( f )`) |
| `onProperty` | a function, or `nil`: called by `__dispatchInvalidateNotification__()` |
| `LIFECYCLE_UPDATED` | `'lifecycle-updated-event'`, the `type` of `onUpdate`'s event |
| `PROPERTY_UPDATED` | `'property-updated-event'`, the `type` of `onProperty`'s event |

`onUpdate` and `onProperty` hold one function each; they aren't sent through `dispatchEvent()`, so `addEventListener()` doesn't receive them. The events' `name` is the object's `EVENT`, set by `ObjectBase`.

### Patching a Plain Table

`patch()` gives a table that isn't a lua-class object the same lifecycle. A plain table has no setters, so `onUpdate` and `onProperty` are methods there, and the table defines its own `__commitProperties__()`:

```lua
local LM = require 'dmc_corona.dmc_lifecycle_mix'

local label = LM.patch( { text="" } )

function label:__commitProperties__()
	print( "redraw", self.text )
end

label:onUpdate( function( event ) print( event.type ) end )

label.text = "hello"
label:__invalidateProperties__()  -- commits on the next frame
```

Call `label:__undoInit__()` when done with it, to stop a waiting update.

## Configuration

dmc-lifecycle-mixin has no settings: `dmc_corona.cfg` needs no section for it, only the `[DMC_CORONA]` section that tells the loader where the libraries are. See [dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md).

## Known Issues

- Debug output is one message, in `resetLifecycle()` ([#1](https://github.com/dmccuskey/dmc-lifecycle-mixin/issues/1)).

## Development

Only `dmc_corona/dmc_lifecycle_mix.lua` and `tests/` are written in this repository; the mixin needs no other module. Everything else is a generated copy, for the classes that use the mixin; fix it in its own repository, then rebuild:

| file | owner |
|---|---|
| every file in `dmc_corona/lib/dmc_lua/` | [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library), which copies them from the `lua-*` repositories ([lua-objects](https://github.com/dmccuskey/lua-objects), [lua-class](https://github.com/dmccuskey/lua-class), ...) |
| `dmc_corona_boot.lua` | [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot) |

The copies are made by Snakemake from sibling checkouts of the repositories above (`../DMC-Lua-Library`, `../dmc-corona-boot`, `../DMC-Corona-Library` for the shared rules). From this repository's root folder:

```sh
snakemake --cores 1 build_all
```

The unit tests run with plain Lua 5.1, no Solar2D needed (a stand-in `Runtime` runs the frames), from the repository's root folder:

```sh
tests/run_unit.sh
```

They use [Luna Test](https://github.com/silentbicycle/lunatest) (`tests/lunatest.lua`, a copy). The Quick Start is the check that it works in Solar2D. Changes are listed in the [CHANGELOG](CHANGELOG.md).

## License

dmc-lifecycle-mixin is released under the [MIT License](LICENSE).
