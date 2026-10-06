local modRoot=arg[1]
require('src.core.GameVersion').set('emerald')
local active='emerald'
package.loaded['src.core.game3.profile']={FALLBACK_ID='firered',active=function()return {optionsBlock=active}end,of=function(v)return {optionsBlock=v}end}
local Options=require('src.core.game3.options')
local session
package.loaded['src.core.game3.runtime']={getSession=function()return session end}
-- Exercise the Hoennto guard independently of WildFollowers.
local C=assert(loadfile(modRoot..'/campaign.lua'))()
local B=assert(loadfile(modRoot..'/travel.lua'))()(C,{})
package.loaded['src.core.SaveData']={saveOptions=function()return true end}
local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg)end
package.loaded['src.core.game3.scripting.stdscripts']={legacyHandlers=function()end}
package.loaded['src.core.game3.scripting.flags']={getVar=function()return 0 end}
package.loaded['src.core.game3.scripting.natives']={yieldHost=function(_,_,fn)fn(function()end)end}
package.loaded['src.ui.game3.fade']={clear=function()end}
package.loaded['src.core.game3.time_events']={init=function(s)eq(s,session,'clock initializes live session')end}
package.loaded['src.ui.game3.rse.wall_clock']={open=function(opts)eq(opts.frameType,7,'clock retains frame preference');opts.onDone({confirmed=true})end}
-- Reproduce the stock host call even when the local native source is patched.
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})
local guardSource=assert(io.open(modRoot..'/session_options.lua')):read('*a')
assert(load(guardSource,'@session_options.lua','t',env))()(function()return session end)
local clockSource=assert(io.open('src/core/game3/scripting/natives_clock.lua')):read('*a')
clockSource=clockSource:gsub('Options and Options.ensure','Options and Options.block')
clockSource=clockSource:gsub('pcall%(Options.ensure, sess%)','pcall(Options.block, sess and sess.options)')
local Clock=assert(load(clockSource,'@stock_natives_clock.lua'))()
for _,version in ipairs({'emerald','firered','leafgreen'})do
 active=version
 for count=0,6 do
  local engine={};session={version=version};Options.bind(session,engine)
  local original=session.options
  original.wildsG3FollowerCount=count;original.wildsG3FollowerJump=true;original.frameType=7
  Clock.BY_NAME.StartWallClock({}, {})
  eq(original[version],nil,'clock does not insert nested options')
  eq(Options.ensure(session),original,'ensure preserves bound options identity')
  eq(session.engineOptions,engine,'engine options identity retained')
  eq(session.options.wildsG3FollowerCount,count,'selected follower count survives clock')
  eq(session.options.wildsG3FollowerJump,true,'idle setting survives clock')
  eq(Options.block(engine),original,'normal engine block lookup unchanged')
  local game={options=engine,session=session}
  eq(B.syncWildOptions(game),true,'preferences persist after clock')
  for _,target in ipairs({'emerald','firered','leafgreen'}) do
    eq(engine[target].wildsG3FollowerCount,count,'count shared after clock')
    eq(engine[target].wildsG3FollowerJump,true,'idle shared after clock')
  end
 end
end
session=nil
local other={};eq(Options.block(other),other[active],'title-screen lookup unchanged')
print('Native clock settings checks',checks)
