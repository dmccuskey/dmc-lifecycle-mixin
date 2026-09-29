#!/bin/sh
#
# Run the lunatest unit specs with plain Lua 5.1.
#
# usage: tests/run_unit.sh
#   override the interpreter with LUA=

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
LUA=${LUA:-$ROOT/../tools/lua51/bin/lua}

cd "$ROOT"
LUA_PATH="$ROOT/?.lua;$HERE/?.lua;$($LUA -e 'io.write(package.path)')"
LUA_CPATH="$($LUA -e 'io.write(package.cpath)')"
export LUA_PATH LUA_CPATH

# stand-ins for the Solar2D globals the library touches: dmc_corona_boot
# needs json and system.pathForFile; the mixin adds and removes enterFrame
# listeners on Runtime, which the specs run with Runtime.frame()
"$LUA" -e "
package.preload.json = package.preload.json or function() return require 'dkjson' end
Runtime = { listeners={} }
function Runtime:addEventListener( name, f ) self.listeners[f] = true end
function Runtime:removeEventListener( name, f )
	assert( self.listeners[f], 'listener not found' )
	self.listeners[f] = nil
end
function Runtime.frame()
	local fs = {}
	for f in pairs( Runtime.listeners ) do fs[#fs+1] = f end
	for _, f in ipairs( fs ) do f( { name='enterFrame' } ) end
end
system = { pathForFile=function( f ) return f end, ResourceDirectory='.' }
local lunatest = require 'lunatest'
lunatest.suite( 'dmc_lifecycle_mix_spec' )
lunatest.run()
"
