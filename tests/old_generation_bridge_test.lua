-- Older runtime services must never require GBA modules before a handoff.
-- Native Gen 2 option read/modify/write is exercised against a shared file.
local root=arg[1]
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local GV=require('src.core.GameVersion')
local Save2=require('src.core.gen2.Save')
local file,saved,slots={}, {},{}
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local SD={loadOptions=function()return C.copy(file)end,
 saveOptions=function(o)file=C.copy(o);saved[#saved+1]=C.copy(o);return true end,
 getCart=function()return nil end,activeSlot=function(v)return slots[v]end,
 createSlot=function(v)slots[v]=v..'-slot';return slots[v]end,
 renameSlot=function()return true end,setActiveSlot=function(v,id)slots[v]=id;return id end,
 setModEnabled=function(o,id,enabled,v)o.modsByVersion=o.modsByVersion or {};o.modsByVersion[v]={[id]=enabled}end,
 writeSlot=function()return true end}
package.loaded['src.core.SaveData']=SD
package.loaded['src.import.CacheFs']={}
package.loaded['src.import.CacheContract']={isReady=function()return true end}
local B=assert(loadfile(root..'/travel.lua'))()(C,{})
local originalRequire=require
local wrongEngineRequires=0
require=function(name)
 if name:find('game3',1,true) or name=='src.mods.Gen3Compat' or name=='src.core.Game3' then
  wrongEngineRequires=wrongEngineRequires+1;error('GBA module requested while a GB runtime is mounted: '..name)
 end
 return originalRequire(name)
end
C.runtime={bindOptions=function(g,full)
 eq(full,true,'bridge explicitly identifies full installation options')
 if C.generation(g.session.version)==2 then
  g._hoenntoEngineOptions=g.options;SD.saveOptions(g.options);g.options=Save2.loadOptions()
 end
 g.session.options=g.options
end,newSave=function(g,v)
 return {version=v,player={name='ASH',id=42},party={},boxes={},pokedex={},modData={}}
end,resume=function(g,r)g.save=r;g.session=r;g.resumed=true end}
for _,source in ipairs({'red','blue','yellow','gold','silver','crystal'})do
 GV.set(source);slots={};saved={}
 file={textSpeed=4,battleStyle='shift',saveSlots={},gold={textSpeed='FAST',battleStyle='SET'},
  ruby={textSpeed=2},modOptions={[C.KEY]={sharedWildFollowers={wildsG3FollowerCount=6,wildsG3FollowerDoze=false}}}}
 local native=C.generation(source)==2 and Save2.loadOptions() or SD.loadOptions()
 local raw={version=source,player={name='ASH',id=42},party={},boxes={},pokedex={},modData={}}
 local g={session=raw,save=raw,options=native,phase=C.generation(source)==2 and 'play' or 'field'}
 raw.options=native
 function g:quickSaveAllowed()return true end
 function g:saveGame()
  local nextRaw=C.copy(self.session);B.prepareSave(self,nextRaw);self.save=nextRaw
  if C.generation(self.session.version)==2 then Save2.saveOptions(self.options) else SD.saveOptions(self.options) end
  return true
 end
 local state={wildFollowersOptions={wildsG3FollowerCount=1}}
 B.captureWildOptions(g,state)
 eq(state.wildFollowersOptions.wildsG3FollowerCount,6,'stored GBA preferences survive an older native session')
 eq(state.wildFollowersOptions.wildsG3FollowerDoze,false,'false GBA preferences survive an older native session')
 B.applyWildOptions(g,state,'ruby')
 local nativeGbaSpeed;if C.generation(source)==1 then nativeGbaSpeed=2 end
 eq(g.options.ruby and g.options.ruby.textSpeed,nativeGbaSpeed,'older synchronization leaves the existing GBA block untouched')
 eq(B.syncWildOptions(g),true,'older preference synchronization succeeds')
 eq(file.textSpeed,4,'Gen 1 text speed survives older preference sync')
 eq(file.battleStyle,'shift','Gen 1 battle style survives older preference sync')
 eq(file.gold.textSpeed,'FAST','Gen 2 text speed stays in its native block')
 eq(file.gold.battleStyle,'SET','Gen 2 battle style stays in its native block')
 eq(file.ruby.textSpeed,2,'GBA native options stay intact while older runtime is active')
 B.notice(g,'Native notice')
 eq(g._hoenntoNotice,'Native notice','older notice uses common overlay even without game.generation')
 local payload=assert(B.prepare(g,'ruby'))
 eq(payload.source,source,'older departure captures source checkpoint')
 eq(payload.target,'ruby','older departure can prepare GBA destination without loading its modules')
 eq(payload.state.wildFollowersOptions.wildsG3FollowerCount,6,'departure preserves shared follower settings')
 eq(file.textSpeed,4,'preparing Gen 2 departure never writes its flat text speed over Gen 1')
 local target=source=='red' and 'gold' or 'red'
 local destination={options=SD.loadOptions(),quickSaveAllowed=function()return false end}
 B.resume(destination,{target=target,state=payload.state})
 eq(destination.resumed,true,'older arrival uses adapter instead of GBA schema')
 eq(destination.session.version,target,'older arrival uses destination save version')
 eq(destination.session.player.name,'ASH','older arrival projects trainer identity')
end
-- Manager reset confirmation also identifies the generation from its native
-- version when no generation field has been attached to the Game object.
local Manager={buildOptionRows=function()return {{id='reset_peer'}}end}
package.loaded['src.mods.ManagerState']=Manager
local resets=0
for _,source in ipairs({'red','blue','yellow','gold','silver','crystal'})do
 local stack={clear=function(self)self.closed=true end,top=function()return nil end}
 local g={session={version=source},stack=stack,mods={exports={[C.KEY]={}}}}
 local factory=assert(loadfile(root..'/reset_menu.lua'))()
 factory({},function()resets=resets+1 end,function()return 'ruby'end)
 local manager={game=g,openConfirm=function(self,_,fn)self.overlay={index=1,onYes=fn}end}
 local rows=Manager.buildOptionRows(manager,{id=C.KEY},{})
 rows[1].activate();eq(manager.overlay.index,2,'old-generation destructive confirmation defaults to NO')
 manager.overlay.onYes()
 if C.generation(source)==2 then eq(stack.closed,true,'Gen 2 reset closes its own stack') end
end
eq(resets,6,'all older games queue native reset confirmation')
eq(wrongEngineRequires,0,'no GBA module was requested by any older bridge path')
require=originalRequire
print('Old generation bridge isolation and native Gen 2 option persistence',checks)
