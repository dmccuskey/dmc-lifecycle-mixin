--====================================================================--
-- tests/dmc_lifecycle_mix_spec.lua
--
-- Unit tests for dmc-lifecycle-mixin, using Luna Test.
-- Run with tests/run_unit.sh
--====================================================================--


module(..., package.seeall)



--====================================================================--
--== Setup


local LM, Objects, Score

function suite_setup()
	LM = require 'dmc_corona.dmc_lifecycle_mix'
	Objects = require 'lib.dmc_lua.lua_objects'

	Score = Objects.newClass( { Objects.ObjectBase, LM.LifecycleMix }, { name="Score" } )

	function Score:__init__( params )
		params = params or {}
		self:superCall( LM.LifecycleMix, '__init__', params )
		self:superCall( Objects.ObjectBase, '__init__', params )
		--==--
		self._points = 0
		self.shown = nil
		self.commits = 0
		self.on_commit = nil -- function, called from __commitProperties__
	end

	function Score:__undoInit__()
		self:superCall( Objects.ObjectBase, '__undoInit__' )
		self:superCall( LM.LifecycleMix, '__undoInit__' )
	end

	function Score.__setters:points( value )
		self._points = value
		self:__invalidateProperties__()
	end

	function Score:__commitProperties__()
		self.commits = self.commits + 1
		self.shown = self._points
		if self.on_commit then self:on_commit() end
	end
end

local function listenerCount()
	local n = 0
	for _ in pairs( Runtime.listeners ) do n = n + 1 end
	return n
end

function setup()
	Runtime.listeners = {}
end



--====================================================================--
--== Tests


function test_version()
	assert_string( LM.VERSION )
end

function test_commitOncePerFrame()
	local s = Score:new()
	s.points = 1 ; s.points = 2 ; s.points = 3
	assert_equal( 0, s.commits )
	Runtime.frame()
	assert_equal( 1, s.commits )
	assert_equal( 3, s.shown )
	assert_equal( 0, listenerCount(), "stops listening when settled" )
	Runtime.frame()
	assert_equal( 1, s.commits )
	s:removeSelf()
end

function test_onUpdateEvent()
	local s = Score:new()
	local event
	s.onUpdate = function( e ) event = e end
	s.points = 1
	Runtime.frame()
	assert_table( event )
	assert_equal( s.LIFECYCLE_UPDATED, event.type )
	assert_equal( s, event.target )
	s:removeSelf()
end

function test_setterDuringCommit()
	local s = Score:new()
	s.on_commit = function( self )
		if self._points == 1 then self.points = 2 end
	end
	s.points = 1
	Runtime.frame()
	assert_equal( 1, s.shown )
	assert_equal( 1, listenerCount(), "keeps listening for the new change" )
	Runtime.frame()
	assert_equal( 2, s.shown )
	assert_equal( 0, listenerCount() )
	s:removeSelf()
end

function test_setterDuringOnUpdate()
	local s = Score:new()
	s.onUpdate = function( e )
		if s.shown == 1 then s.points = 2 end
	end
	s.points = 1
	Runtime.frame()
	Runtime.frame()
	assert_equal( 2, s.shown )
	assert_equal( 2, s.commits )
	assert_equal( 0, listenerCount() )
	s:removeSelf()
end

function test_validateNow()
	local s = Score:new()
	s.points = 4
	s:__validate__()
	assert_equal( 4, s.shown )
	assert_equal( 0, listenerCount() )
	s:removeSelf()
end

function test_removeStopsUpdate()
	local s = Score:new()
	s.points = 1
	s:removeSelf()
	assert_equal( 0, listenerCount() )
end

function test_removeIdleObject()
	-- the Runtime stub asserts when a missing listener is removed
	local s = Score:new()
	s:removeSelf()
	assert_equal( 0, listenerCount() )
end

function test_removeKeepsOtherInstances()
	local a, b = Score:new(), Score:new()
	a:removeSelf()
	local updates = 0
	b.onUpdate = function() updates = updates + 1 end
	b.points = 1
	Runtime.frame()
	assert_equal( 1, updates )
	b:removeSelf()
end

function test_onPropertyEvent()
	local s = Score:new()
	local event
	s.onProperty = function( e ) event = e end
	s:__dispatchInvalidateNotification__( 'points', 5 )
	assert_table( event )
	assert_equal( s.PROPERTY_UPDATED, event.type )
	assert_equal( s, event.target )
	assert_equal( 'points', event.property )
	assert_equal( 5, event.value )
	s:removeSelf()
end

function test_patchPlainTable()
	local commits, updates = 0, 0
	local t = LM.patch( { text="" } )
	function t:__commitProperties__() commits = commits + 1 end
	t:onUpdate( function( e )
		updates = updates + 1
		assert_equal( t.LIFECYCLE_UPDATED, e.type )
	end )
	t:__invalidateProperties__()
	t:__invalidateProperties__()
	Runtime.frame()
	assert_equal( 1, commits )
	assert_equal( 1, updates )
	assert_equal( 0, listenerCount() )
	t:__undoInit__()
end

function test_patchNil()
	local t = LM.patch()
	assert_table( t )
	assert_function( t.__invalidateProperties__ )
	t:__undoInit__()
end
