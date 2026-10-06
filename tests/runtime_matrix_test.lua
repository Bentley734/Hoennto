local root=arg[1]
local output=print
print=function(first,...)if not tostring(first):find('^%[Hoennto%] Switch')then output(first,...)end end
local Sandbox=require('src.mods.Sandbox')
local C=assert(loadfile(root..'/campaign.lua'))()
local reads={}
for _,name in ipairs({'main.lua','session_options.lua','transition.lua','campaign.lua','travel.lua','mount_lifecycle.lua','presentation.lua','reset_menu.lua','runtime.lua','roster.lua','travel_menu.lua'}) do reads[name]=assert(io.open(root..'/'..name)):read('*a') end
local GV=require('src.core.GameVersion')
local callbacks,hooks,host={}, {},nil
local options={saveSlots={},modOptions={},modsByVersion={}}
local SD={loadOptions=function()return C.copy(options)end,saveOptions=function(o)options=C.copy(o);return true end,
 load=function()return nil end,getCart=function()return nil end,activeSlot=function(v)return v..'slot'end,
 createSlot=function(v)return v..'slot'end,renameSlot=function()return true end,setActiveSlot=function()return true end,
 setModEnabled=function()end,writeSlot=function()return true end}
package.loaded['src.core.SaveData']=SD
package.loaded['src.import.CacheFs']={mountVersion=function()end}
package.loaded['src.import.CacheContract']={isReady=function()return true end}
package.loaded['src.mods.ManagerState']={buildOptionRows=function()return {}end}
package.loaded['src.core.game3.options']={block=function(o,id)o[id]=o[id]or{};return o[id]end,bind=function(s,o)s.options=o end}
package.loaded['src.core.game3.profile']={of=function(v)return {optionsBlock=v}end}
package.loaded['src.core.game3.audio']={shutdown=function()end}
package.loaded['src.ui.game3.start_menu']={_kind='normal',close=function()end}
local failures={}
package.loaded['src.ui.game3.hud']={openMessage=function(_,m)failures[#failures+1]=m end}
local function emit(n,e)for _,fn in ipairs(callbacks[n]or{})do fn(e)end end
package.loaded['src.mods.Runtime']={wants=function(n)return callbacks[n]~=nil end,emit=emit}
local function raw(v)
 local gen=GV.generation(v)
 return {version=v,generation=gen,engine=gen==3 and 'game3' or nil,name='ASH',trainerId=42,secretId=77,
  player={name='ASH',id=42,map=v..'home'},map=v..'home',flags={story=v},money=3000,
  party={{species=gen==3 and 25 or 'PIKACHU',level=20,exp=8000,experience=8000,hp=40,maxHp=80,
   moves=gen==3 and {33}or{{id='TACKLE',pp=7}},pp={7},ivs={},dvs={},statExp={},otId=42}},
  boxes={},storage={boxes={}},dex={},pokedex={},modData={}}
end
SD.newGame=function()local r=raw(GV.get());r.party={};return r end
package.loaded['src.core.gen2.Save']={newGame=function()return SD.newGame()end,loadOptions=function()return {}end}
local P={keyName=function()return 'PIKACHU'end,name=function()return 'PIKACHU'end,speciesFromName=function(n)return n=='PIKACHU' and 25 end,
 moveName=function()return 'TACKLE'end,isShiny=function()return false end,applyStats=function(m)m.maxHp=80 end}
package.loaded['src.core.game3.pokemon']=P
package.loaded['src.mods.Gen3Compat']={moveId=function(n)return n=='TACKLE' and 33 end}
package.loaded['src.core.game3.items_data']={}
local Schema={toSaveTable=C.copy,fromSaveTable=C.copy,newGame=function()return SD.newGame()end}
package.loaded['src.core.game3.save_schema_firered']=Schema
local function install()
 local mod={path='mods/kanto_hoenn',exports={},events={on=function(_,name,fn)callbacks[name]=callbacks[name]or{};table.insert(callbacks[name],fn)end},
  hooks={wrap=function(_,name,fn)hooks[name]=fn end},read=function(_,name)return reads[name]end,
  options={define=function()end,get=function()return 'auto'end}}
 setmetatable(mod,{__index=function(_,k)if k=='game'then return host end end})
 assert(load(reads['main.lua'],'@main.lua','t',Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})))()(mod)
end
local Class={};Class.__index=Class
local failTarget
function Class.new()
 return setmetatable({generation=GV.generation(),stack={pop=function()end,clear=function()end},
  input={reset=function(self)self.press=nil end,step=function()end,pollPads=function()end,
   wasPressed=function(self,k)local yes=self.press==k;if yes then self.press=nil end;return yes end}},Class)
end
function Class:load()
 if failTarget==GV.get()then failTarget=nil;error('fixture load failure')end
 self.generation=GV.generation();self.options=C.copy(options);self.save=raw(GV.get())
 self.data={pokemon={PIKACHU={name='PIKACHU',baseStats={hp=35,attack=55,defense=40,speed=90,special=50,specialAttack=50,specialDefense=50},types={'ELECTRIC'}}},moves={TACKLE={id='TACKLE',pp=35}},items={}}
 if self.generation==3 then self.session=self.save end
 install();emit('game.ready',{game=self});self.phase=self.generation==2 and 'play' or 'field'
end
function Class:update()end
function Class:quickSaveAllowed()return true end
function Class:adoptSave(r)self.save=r;if self.generation==3 then self.session=r end end
function Class:_enterField(r)self:adoptSave(r);self.phase='field'end
function Class:restoreSave(r)self:adoptSave(r);self.phase='field'end
function Class:continueGame(r)self:adoptSave(r);self.phase='play'end
function Class:bootConfig()return {version=GV.get()}end
function Class:writeSave()emit('save.writing',{save=self.save});return true end
function Class:saveGame()self.save=C.copy(self.session);emit('save.writing',{save=self.save});return true end
Class.anchorNewGameClock=function()end
package.loaded['src.core.Game3']=Class;package.loaded['src.core.Game2']=Class
package.preload['src.core.Game']=function()
 local g=Class.new();setmetatable(g,nil);for k,v in pairs(Class)do if type(v)=='function'then g[k]=v end end;return g
end
package.loaded['src.core.SessionLifecycle']={endGameSession=function(g)
 if package.loaded['src.core.Game']==g then package.loaded['src.core.Game']=nil end
end,endMountedSession=function()callbacks={};hooks={}end}
local checks=0;local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function travel(target)
 local rows=hooks['ui.start_menu.items'](function(_,i)return i end,host,{{id='option'}})
 rows[1].onSelect();local menu=host._hoenntoMenu
 for i,row in ipairs(menu.rows)do if row.version==target then menu.index=i end end
 host.input.press='a';host:update(0);host.input.press='a';host:update(0)
 for _=1,8 do host:update(0.1)end
end
for _,source in ipairs(C.ORDER)do for _,target in ipairs(C.ORDER)do if source~=target then
 callbacks={};hooks={};failures={};GV.set(source);host=Class.new();host:load();local identity=host
 host.onExit=function()end
 travel(target)
 eq(GV.get(),target,'native target selected '..source..' -> '..target)
 eq(host,identity,'host reference retained');eq(host.session.version,target,'native save adopted')
 eq(host.session.flags.story,target,'first story uses native target skeleton')
 eq(#host.session.party,1,'party projected');eq(#failures,0,'handoff succeeds without notice')
 local after=host.session.party[1];after.nickname='TRAVELER'
 travel(source)
 eq(host.session.party[1].nickname,'TRAVELER','edited mon returns across native owners')
 eq(host.session.flags.story,source,'source story restored')
 eq(host._hoenntoTransition,nil,'fade completes in destination wrapper')
end end end
callbacks={};hooks={};GV.set('firered');host=Class.new();host:load();failTarget='gold';travel('gold')
eq(GV.get(),'firered','failed cross-generation boot rolls back profile')
eq(host.session.version,'firered','failed cross-generation boot rolls back save')
print('Sandbox runtime handoffs / 110 directed routes with roundtrips',checks)
