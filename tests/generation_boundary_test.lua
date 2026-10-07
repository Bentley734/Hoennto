-- A cold Gen 1/2 mod boot must not attempt any Gen 3 require, even a require
-- inside pcall. Unlike the matrix fixtures, no Gen 3 module is preloaded.
local root=arg[1]
local Sandbox=require('src.mods.Sandbox')
local GV=require('src.core.GameVersion')
local C=assert(loadfile(root..'/campaign.lua'))()
local checks=0
local function eq(a,b,msg) checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b)) end
local reads={}
for _,name in ipairs({'main.lua','oak_intro.lua','session_options.lua','transition.lua','campaign.lua','travel.lua','mount_lifecycle.lua','presentation.lua','reset_menu.lua','runtime.lua','roster.lua','travel_menu.lua'}) do
  reads[name]=assert(io.open(root..'/'..name)):read('*a')
end
local SD={loadOptions=function()return {}end,saveOptions=function()return true end}
package.loaded['src.core.SaveData']=SD
package.loaded['src.import.CacheFs']={}
package.loaded['src.import.CacheContract']={isReady=function()return true end}
package.loaded['src.mods.ManagerState']={buildOptionRows=function()return {}end}
package.loaded['src.core.SessionLifecycle']={registerProcessShutdown=function()end}
local tries={}
local function guardedEnv()
  local env=Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})
  local native=env.require
  env.require=function(name)
    if name:find('%.game3') or name=='src.core.Game3' or name=='src.mods.Gen3Compat' then
      tries[#tries+1]=name
      error('Gen 3 dependency on an older cartridge: '..name)
    end
    return native(name)
  end
  return env
end
local function makeSave(version)
  return {version=version,party={},boxes={},pokedex={},player={name='ASH',id=12},modData={},options={textSpeed=2}}
end
for _,version in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
  GV.set(version);tries={}
  local callbacks,hooks={},{}
  local nativeUpdates,writes=0,0
  local game={save=makeSave(version),phase='play',mods={mods={},loaded={}},
    input={reset=function()end,pollPads=function()end,step=function()end,wasPressed=function()return false end},
    stack={pop=function()end,clear=function()end,top=function()return nil end},
    adoptSave=function()end,update=function()nativeUpdates=nativeUpdates+1 end,
    writeSave=function()writes=writes+1;return true end,
    mousemoved=function()end,wheelmoved=function()end,keypressed=function()end,
    quickSaveAllowed=function()return true end}
  if GV.generation()==2 then game.options=game.save.options end
  local mod={path='mods/kanto_hoenn',game=game,exports={},
    read=function(_,name)return reads[name]end,
    options={define=function()end,get=function()return 'auto'end},
    events={on=function(_,name,fn)callbacks[name]=fn end},
    hooks={wrap=function(_,name,fn)hooks[name]=fn end}}
  local env=guardedEnv()
  assert(load(reads['main.lua'],'@main.lua','t',env))()(mod)
  eq(#tries,0,version..' cold entry is free of Gen 3 requires')
  callbacks['game.ready']({game=game})
  eq(game.session,game.save,version..' ready session aliases native save')
  eq(game.generation,GV.generation(),version..' uses active generation')
  game:update(0.01);eq(nativeUpdates,1,version..' native gameplay updates')
  local nextSave=makeSave(version);nextSave.options.textSpeed=0
  game.save=nextSave;game:adoptSave(nextSave)
  eq(game.session,nextSave,version..' continue/new-game refreshes session')
  if GV.generation()==1 then eq(game.options,nextSave.options,version..' refreshes native option alias') end
  local bound=game.adoptSave
  callbacks['game.ready']({game=game})
  eq(game.adoptSave,bound,version..' adapter adoption is idempotent')
  game:saveGame();eq(writes,1,version..' common save dispatches native writer')
  local rows=hooks['ui.start_menu.items'](function(_,i)return i end,game,{{id='option'}})
  eq(rows[1].id,'kanto_hoenn_travel',version..' travel row works on native start menu')
  rows[1].onSelect();eq(game._hoenntoMenu.mode,'choose',version..' picker opens')
  game._hoenntoMenu=nil
  game._hoenntoTransition={phase='in',elapsed=0,target=version,started=0}
  game:update(0.1);eq(nativeUpdates,1,version..' arrival fade pauses native update')
  -- Notices route through the common panel on old cartridges.
  local B=assert(load(reads['travel.lua'],'@travel.lua','t',env))()(C,mod)
  B.notice(game,'Boundary check')
  eq(game._hoenntoNotice,'Boundary check',version..' notice uses shared menu')
  eq(mod.exports.syncWildFollowersOptions(),true,version..' companion options sync is generation-safe')
  local Lifecycle=assert(load(reads['mount_lifecycle.lua'],'@mount_lifecycle.lua','t',env))()
  eq(Lifecycle.load(function()return 'native mount'end),'native mount',version..' mount load succeeds')
  Lifecycle.stopAudio()
  eq(#tries,0,version..' ready/menu/fade/notice/sync/lifecycle never request Gen 3 modules')
end

-- Native Gen 2 options are flat; full launcher options must be retained and
-- saved as a full table before reloading that cartridge's native block.
GV.set('gold')
local A=assert(loadfile(root..'/runtime.lua'))()
local full={gold={textSpeed=1},modsByVersion={gold={kanto_hoenn=true}}}
local flat={textSpeed=1}
local saved
SD.saveOptions=function(options)saved=options;return true end
package.loaded['src.core.gen2.Save']={loadOptions=function()return flat end}
local game={generation=2,session={version='gold'},options=full}
A.bindOptions(game,true)
eq(saved,full,'explicit full options saved even without saveSlots')
eq(game._hoenntoEngineOptions,full,'full launcher table retained')
eq(game.options,flat,'native Gen 2 flat block restored')
eq(game.session.options,flat,'session references native Gen 2 flat block')
saved=nil;A.bindOptions(game)
eq(saved,nil,'flat Gen 2 options never saved through SaveData')
GV.set('red')
local live={textSpeed=2,battleStyle='set'}
local raw={version='red'}
local continued={options=live,restoreSave=function(_,save,_,opts)
  eq(save.options,live,'Gen 1 snapshot receives mounted live options before native restore')
  eq(opts.freshBoot,true,'Gen 1 native fresh boot retained')
end}
A.resume(continued,raw,false)
eq(raw.options,live,'Gen 1 native save retains options reference after travel')

-- Run the actual 0.3.54 Gen 2 option loader/writer, not a flat-table stub.
-- Gold/Silver/Crystal deliberately share the native gold option block.
GV.set('crystal')
package.loaded['src.core.gen2.Save']=nil
local NativeSave=require('src.core.gen2.Save')
local stored={gold={textSpeed='FAST',sound='STEREO',battleStyle='SET',companionSetting=7},
  textSpeed=0,orientation='landscape',firered={frameType=9},saveSlots={crystal={active='story'}},
  modOptions={kanto_hoenn={sharedWildFollowers={wildsG3FollowerCount=4}}},
  modsByVersion={crystal={kanto_hoenn=true}}}
SD.loadOptions=function()return C.copy(stored)end
SD.saveOptions=function(options)stored=C.copy(options);return true end
game={generation=2,session={version='crystal'},options=SD.loadOptions()}
A.bindOptions(game,true)
eq(game.options.textSpeed,'FAST','native Gen 2 text speed retains its own type')
eq(game.options.battleStyle,'SET','native Gen 2 battle style retained')
eq(game.options.sound,'STEREO','native Gen 2 sound preference retained')
eq(game.options.companionSetting,7,'native Gen 2 custom option retained')
eq(game.options.orientation,'landscape','shared display setting retained')
eq(game.options.modOptions.kanto_hoenn.sharedWildFollowers.wildsG3FollowerCount,4,'shared companion settings retained')
game.options.textSpeed='SLOW';NativeSave.saveOptions(game.options)
eq(stored.gold.textSpeed,'SLOW','native Gen 2 writer updates its cartridge block')
eq(stored.textSpeed,0,'native Gen 2 write preserves Gen 1 root preference')
eq(stored.firered.frameType,9,'native Gen 2 write preserves Gen 3 preference')
eq(stored.saveSlots.crystal.active,'story','native Gen 2 write preserves campaign slots')
print('Cold Gen 1/2 dependency boundary checks',checks)
