package.path='./?.lua;./?/init.lua;'..package.path
local Sandbox=require('src.mods.Sandbox')
local root=arg[1] or 'mods/kanto_hoenn'
local reads={};for _,f in ipairs({'main.lua','campaign.lua','travel.lua','mount_lifecycle.lua','presentation.lua','reset_menu.lua'}) do local s=assert(io.open(root..'/'..f)):read('*a');reads[f]=s end
local C=assert(load(reads['campaign.lua']))()
local callbacks,hooks={},{}
local rawGame
local calls={}
local definedOptions
package.loaded['src.mods.ManagerState']={buildOptionRows=function()return {}end}
local function called(s)calls[#calls+1]=s end
local eventApi={}
function eventApi:on(name,fn)callbacks[name]=callbacks[name] or {};table.insert(callbacks[name],fn)end
local function emit(name,payload)for _,f in ipairs(callbacks[name] or {})do f(payload)end end
local function install()
 local mod={path='mods/kanto_hoenn',generation=3,exports={},events=eventApi,
  options={define=function(_,schema)definedOptions=schema end,get=function()return 'auto'end},
  hooks={wrap=function(_,name,fn)hooks[name]=fn end},read=function(_,name)return reads[name]end}
 setmetatable(mod,{__index=function(_,k)if k=='game'then return rawGame end end})
 local env=Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})
 assert(load(reads['main.lua'],'@main.lua','t',env))()(mod)
end
local kanto=arg[2] or 'firered'
assert(kanto=='firered' or kanto=='leafgreen')
local current=kanto
local options={saveSlots={},modsByVersion={}}
local SD={}
local diskLoad=function()error("travel reread destination save from disk")end
SD.load=diskLoad
local active,count={},0
SD.getCart=function()return nil end
SD.activeSlot=function(v)return active[v]end
SD.createSlot=function(v)count=count+1;return 'slot'..count end
SD.renameSlot=function()end
SD.setActiveSlot=function(v,id)active[v]=id;called('slot:'..v);return id end
SD.loadOptions=function()return C.copy(options)end
SD.setModEnabled=function(o,id,enabled,v)o.modsByVersion[v]={[id]=enabled}end
SD.writeSlot=function()return true end
package.loaded['src.core.SaveData']=SD
package.loaded['src.core.GameVersion']={set=function(v)current=v;called('version:'..v)end,cachePrefix=function()return current..'/'end}
package.loaded['src.import.CacheFs']={mountVersion=function(v)called('mount:'..v)end}
package.loaded['src.import.CacheContract']={isReady=function()return true end}
local Menu={_kind='normal'}
Menu.close=function()called('menu.close')end
package.loaded['src.ui.game3.start_menu']=Menu
local dialog,dialogOptions,confirm
package.loaded['src.ui.game3.message']={show=function(text,opts)dialog=text;dialogOptions=opts end,showStay=function(text)dialog=text end,reset=function()dialog=nil;dialogOptions=nil end}
package.loaded['src.ui.game3.choice']={yesNo=function(cb)confirm=cb end}
local function depart()
 if dialogOptions and not dialogOptions.hold then dialogOptions.done() end
 assert(dialogOptions.hold,'travel confirmation presented')
 dialogOptions.done();confirm(true)
 rawGame:update(0.1);rawGame:update(0.1);rawGame:update(0.1)
end
package.loaded['src.ui.game3.hud']={openMessage=function(_,m)error('unexpected notice: '..m)end}
package.loaded['src.core.game3.options']={bind=function(s,o)s.options=o end,block=function(o,id)o[id]=o[id]or{};return o[id]end}
package.loaded['src.core.game3.profile']={of=function(id)return {optionsBlock=id}end}
package.loaded['src.mods.Runtime']={wants=function(name)return callbacks[name]~=nil end,emit=emit}
local Schema={}
Schema.toSaveTable=function(s)local r=C.copy(s);r.options=nil;return r end
Schema.fromSaveTable=function(s)return C.copy(s)end
Schema.newGame=function(o)return {version=current,engine='game3',map=current=='emerald' and 'EM_INSIDE_OF_TRUCK' or 'FR_PLAYERS_HOUSE_2F',x=2,y=2,
 name=o.name,gender=o.gender,trainerId=o.trainerIdLower,secretId=999,flags={},vars={},party={},storage={items={},boxes={}},dex={},modData={}}end
package.loaded['src.core.game3.save_schema_firered']=Schema
local Class={};Class.__index=Class
function Class.new()return setmetatable({generation=3,phase='boot'},Class)end
function Class:update()called('native.update:'..current)end
function Class:saveGame()
 local raw=Schema.toSaveTable(self.session);emit('save.writing',{save=raw});self.save=raw;called('save:'..current);return true
end
function Class:quickSaveAllowed()return self.phase=='field' and self.session.map~='EM_INSIDE_OF_TRUCK'end
function Class:load()called('load:'..current);if self.session==nil and count>0 then SD.load();SD.load();called('checkpoint.load:'..current)end;self.options=C.copy(options);install();emit('game.ready',{game=self})end
function Class:adoptSave()end
function Class:_enterField(s,reason,opts)self.session=s;self.phase='field';self.callback=opts.fieldCallback;called('enter:'..current..':'..reason)end
package.loaded['src.core.Game3']=Class
package.loaded['src.core.game3.audio']={shutdown=function()called('audio.shutdown:'..current)end}
package.loaded['src.core.SessionLifecycle']={
 endGameSession=function(g)called('end.game:'..current);g.session=nil;g.phase='boot'end,
 endMountedSession=function(v)called('unmount:'..v);callbacks={};hooks={}end}
rawGame=Class.new()
local identity=rawGame
local returnFn=function()end;rawGame.returnToLauncher=returnFn
rawGame:load()
rawGame.session={version=kanto,engine='game3',map='FR_PALLET_TOWN',x=4,y=5,name='JOHN',gender=0,trainerId=42,secretId=77,
 flags={KANTO_BADGE=true},vars={STORY=8},party={{species=25,exp=777,hp=12}},storage={boxes={[1]={mons={[3]={species=1}}}},items={}},dex={caught={[25]=true}},modData={}}
rawGame.phase='field'
local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
eq(definedOptions[1].key,'kanto_game','Kanto choice registered through actual sandbox')
eq(definedOptions[1].choices[3][2],'leafgreen','LeafGreen choice usable')
local items=hooks['ui.start_menu.items'](function(_,i)return i end,rawGame,{{id='pokemon',label='POKEMON'},{id='option',label='OPTION'},{id='exit',label='EXIT'}})
eq(items[2].label,'HOENN','destination row before OPTION')
items[2].onSelect()
eq(current,kanto,'menu callback never tears down runtime')
depart()
eq(rawGame,identity,'app Game table identity unchanged')
eq(current,'emerald','profile switched solely by mod')
eq(rawGame.session.name,'JOHN','trainer carried')
eq(rawGame.session.secretId,77,'SID carried')
eq(rawGame.session.party[1].exp,777,'party carried')
eq(rawGame.session.flags.KANTO_BADGE,nil,'regional flags isolated')
eq(rawGame.callback,'truck','native opening truck callback')
eq(rawGame.returnToLauncher,returnFn,'original app return callback preserved')
eq(rawGame.session.storage.boxes[1].mons[3].species,1,'boxes carried')
local nativeSourceTick=false;for _,v in ipairs(calls)do if v=='native.update:'..kanto then nativeSourceTick=true end end
eq(nativeSourceTick,false,'no old native update after handoff')
-- The reloaded mod installs fresh wrappers on the very same object.
rawGame.session.map='EM_OLDALE_TOWN';rawGame.session.flags.HOENN_BADGE=true
rawGame.session.party[1].exp=999
rawGame:update(1/60)
local second=hooks['ui.start_menu.items'](function(_,i)return i end,rawGame,{{id='option'}})
eq(second[1].label,'KANTO','destination switches back')
second[1].onSelect();depart()
eq(rawGame,identity,'same host object on roundtrip')
eq(current,kanto,'roundtrip profile')
eq(rawGame.session.map,'FR_PALLET_TOWN','return location')
eq(rawGame.session.party[1].exp,999,'latest party survives roundtrip')
eq(rawGame.session.flags.KANTO_BADGE,true,'Kanto story restored')
eq(rawGame.session.flags.HOENN_BADGE,nil,'Hoenn badge remains regional')
Menu._kind='safari'
local safari=hooks['ui.start_menu.items'](function(_,i)return i end,rawGame,{{id='exit'}})
eq(#safari,1,'no travel in safari menu')
rawGame.options.modOptions={kanto_hoenn={sharedWildFollowers={wildsG3FollowerCount=6}}}
rawGame.session=nil
eq(pcall(function()emit('game.ready',{game=rawGame})end),true,'title-screen ready with saved follower preferences')
local checkpointSaves=0;local audioStops=0
for i,v in ipairs(calls)do
 if v=='save:'..kanto or v=='save:emerald' then checkpointSaves=checkpointSaves+1 end
 if v:match('^audio.shutdown:')then
  audioStops=audioStops+1
  eq(calls[i+1]:match('^unmount:'), 'unmount:', 'audio stops before native module eviction')
 end
end
eq(checkpointSaves,4,'roundtrip uses one checkpoint per departure plus arrival autosaves')
eq(audioStops,2,'each departure shuts down its sole audio worker')
eq(SD.load,diskLoad,'native save reader restored after remount')
print('kanto_hoenn_mod_test ('..kanto..'): '..checks..' checks passed through actual mod sandbox')
