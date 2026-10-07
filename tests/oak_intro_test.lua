-- Synthetic map/art content, native Gen1 story scripts, TextBox, StateStack,
-- NPC/Player interpolation, Commands and warp transitions. A small companion
-- controller models WildFollowers' public live-owner/clear/tick contract; the
-- private installed-controller integration probe lives outside this package.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local root=assert(arg[1])
local Campaign=assert(loadfile(root..'/campaign.lua'))()
local Adapter=assert(loadfile(root..'/runtime.lua'))()
local Intro=assert(loadfile(root..'/oak_intro.lua'))()
package.loaded['src.render.TileRenderer']={new=function()
 return {rebuild=function()end,release=function()end}
end}
local Game=require('src.core.Game')
local Stack=require('src.core.StateStack')
local OW=require('src.world.OverworldController')
local Runtime=require('src.mods.Runtime')
local Events=require('src.mods.Events')
local Hooks=require('src.mods.Hooks')
local GV=require('src.core.GameVersion')
local MapLoader=require('src.world.MapLoader')
local NativeData=require('src.core.Data')
local nativeBattle=package.loaded['src.battle.BattleState']
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function zeros(n)local t={}for i=1,n do t[i]=0 end return t end
local function object(i,name,x,y,hidden)
 return {index=i,name=name,x=x,y=y,hidden=hidden,sprite='SPRITE_OAK',movement='STAY',range='NONE'}
end
local baseStats={hp=44,attack=48,defense=65,speed=43,special=50,specialAttack=50,specialDefense=64}
local function fixture(version,x,protected,origin,revisited,loseOak)
 origin=origin or 'gold'
 GV.set(version);math.randomseed(73)
 -- The map registry specializes its escort and lab module at load time.
 for name in pairs(package.loaded) do
  if name:match('^data%.scripts%.') then package.loaded[name]=nil end
 end
 MapLoader.invalidateAll()
 Runtime.reset()
 local events,hooks=Events.new(),Hooks.new()
 Runtime.install(events,hooks,{})
 NativeData.map_scripts={}
 local yellow=version=='yellow'
 local sprite={image='oak_fixture.png',frames=6,walker=true}
 local town={id='PALLET_TOWN',index=0,width=10,height=9,tileset='OVERWORLD',blocks=zeros(90),borderBlock=0,
  objects={object(1,'PALLETTOWN_OAK',yellow and 10 or 8,yellow and 4 or 5,true)},
  warps={{x=12,y=11,destMap='OAKS_LAB',destWarp=2}},connections={}}
 local lab={id='OAKS_LAB',width=5,height=6,tileset='LAB',blocks=zeros(30),borderBlock=0,
  objects={object(1,'OAKSLAB_RIVAL',4,3,false),object(yellow and 3 or 5,'OAKSLAB_OAK1',5,2,true),
   object(yellow and 6 or 8,'OAKSLAB_OAK2',5,10,true)},warps={{x=4,y=11},{x=5,y=11}},connections={}}
 local block=zeros(16)
 local pokemon={id='SQUIRTLE',name='SQUIRTLE',dex=7,baseStats=baseStats,types={'WATER'},genderRatio=31,
  growthRate='MEDIUM_FAST',level1Moves={'TACKLE'},learnset={},levelMoves={{level=1,move='TACKLE'}}}
 local data={maps={PALLET_TOWN=town,OAKS_LAB=lab},
  tilesets={OVERWORLD={blocks={block},walkable={0}},LAB={blocks={block},walkable={0}}},
  sprites={SPRITE_OAK=sprite,SPRITE_RED=sprite},pokemon={SQUIRTLE=pokemon,
   CHARMANDER={id='CHARMANDER',name='CHARMANDER',dex=4,baseStats={hp=39,attack=52,defense=43,speed=65,special=50},types={'FIRE'}}},
  moves={TACKLE={id='TACKLE',pp=35},SCRATCH={id='SCRATCH',pp=35},GROWL={id='GROWL',pp=40}},items={},
  text={},constants={},field={flyWarps={},darkMaps={},waterTilesets={},playerSprites={walk='SPRITE_RED'},
   boot={startMap='PALLET_TOWN',startX=x,startY=yellow and 1 or 2}},audio={songs={},sfx={}},
  tokens=require('src.render.TextBox').TOKENS}
 -- Font metrics are real; only rasterized map/sprite content is synthetic.
 data.font={ttf={file=require('src.render.Font').PLAINPIXEL,size=15},pages={},charmap={}}
 require('src.render.Font').load(data)
 Game.data=data;Game.generation=1
 local goldMon=require('src.battle.gen2.Mon').new(data,'SQUIRTLE',5,{dvs={attack=1,defense=2,speed=3,special=4}})
 goldMon.nickname='IMPORTED';goldMon.otName='GOLD';goldMon.otId=42
 local sourceMon,species,moves=goldMon,'SQUIRTLE',{'TACKLE'}
 if origin=='firered' then
  sourceMon={species=4,level=5,exp=125,hp=20,maxHp=20,nickname='IMPORTED',otId=42,otName='FIRERED',
   ivs={hp=10,atk=10,def=10,spe=10,spa=10,spd=10},evs={},moves={10,45},pp={35,40}}
  species,moves='CHARMANDER',{'SCRATCH','GROWL'}
 end
 local state={shared={name='TRAVELER',trainerId=99},collection={nextId=1,
  records={{id=1,version=origin,mon=sourceMon,forms={},party=true,species=species,moves=moves}},
  dex={seen={[species]=true},owned={[species]=true}}}}
 local roster=assert(loadfile(root..'/roster.lua'))()(Campaign,function()return Game end)
 Game.save=Adapter.newSave(Game,version,state.shared)
 roster.project(Game.save,state)
 Game.session=Game.save;Game.options=Game.save.options;Game.options.textSpeed=1
 if revisited then
  -- A prior Hoennto visit was saved in the bedroom before any Oak progress.
  Game.save.player.map='REDS_HOUSE_2F';Game.save.player.x=3;Game.save.player.y=6
  state.regions={};state.slots={};state.version=Campaign.VERSION
  local options=Game.save.options
  Campaign.capture(Game.save,state)
  Game.save=assert(Campaign.restore(state,version));Game.save.options=options
  roster.project(Game.save,state)
  eq(Game.save.player.map,'REDS_HOUSE_2F','Revisited save retains the unfinished bedroom story location')
 end
 eq(Game.save.party[1].nickname,'IMPORTED','Roster imports the '..origin..' Pokemon into '..version)
 eq(Game.save.party[1].species,species,'Travel selects the live imported species')
 eq(Game.save.party[1].otId,42,'Travel preserves the imported trainer')
 eq(next(Game.save.flags),nil,'Imported party does not invent local story flags')
 Stack:init();Game.stack=Stack
 local pressA=false
 Game.input={isDown=function(_,b)return b=='a' and pressA end,
  wasPressed=function(_,b)return b=='a' and pressA end,state={},pressQueue={}}
 Game.renderer={worldViewSize=function()return 160,144 end}
 if yellow then
  -- Yellow's fixed Oak capture demonstration needs extracted battle art.
  -- Native story callbacks/entry transition run; presentation is headless.
  package.loaded['src.battle.BattleState']={newWild=function(game,species,level)
   eq(species,'PIKACHU','Yellow retains the native capture species')
   eq(level,5,'Yellow retains the native capture level')
   return {kind='wild',enemy={mon={level=level}},makeOldManDemo=function(_,name)
    eq(name,'PROF.OAK','Yellow retains Oak as the demonstration trainer')
   end,update=function(self)game.stack:pop();self.onFinish('catch')end}
  end}
 else package.loaded['src.battle.BattleState']=nativeBattle end
 OW._wildFollowersRewriteOwner=nil
 Stack:push(OW,'PALLET_TOWN',x,yellow and 1 or 2,'up')
 local controller={followers={},ticks=0,clears=0}
 local function detach()
  for _,list in ipairs({OW.npcs,OW.entities})do
   for i=#list,1,-1 do if list[i]._wildFollowersRewrite then table.remove(list,i)end end
  end
 end
 function controller:clear()self.clears=self.clears+1;detach();self.followers={}end
 function controller:tick()
  self.ticks=self.ticks+1;OW._wildFollowersRewriteOwner=self
  if #self.followers==0 then
   local e={_wildFollowersRewrite=true,def={index=50001,name='WILDFOLLOWERS'},id='companion',
    cellX=OW.player.cellX,cellY=OW.player.cellY+1,px=OW.player.px,py=OW.player.py+16,
    hidden=false,passable=true,moving=false,update=function()end,draw=function()end}
   self.followers={e}
  end
  detach()
  for _,e in ipairs(self.followers)do OW.npcs[#OW.npcs+1]=e;OW.entities[#OW.entities+1]=e end
 end
 hooks:wrap('input.step',function(next_,game,dt)controller:tick(game,dt);return next_(game,dt)end,0,'companion')
 if protected then
  Intro({generation=1,events=events,hooks=hooks,content={map_scripts={register=function(_,id,entry)
   NativeData.map_scripts[id]={entry};require('src.script.MapScripts').invalidate(id)
  end}}},function()return Game end)
 end
 Runtime.call('input.step',function()end,Game,1/60)
 local nativeTick=controller.tick
 -- The player finishes the upward grass-entry step. The companion trails
 -- in the exact destination cell native Oak approaches in Red/Blue.
 controller.followers[1].cellY=yellow and 1 or 2
 controller.followers[1].py=controller.followers[1].cellY*16
 OW.player.cellY=yellow and 0 or 1;OW.player.py=OW.player.cellY*16
 if protected=='fresh' then OW:setMap('PALLET_TOWN',x,yellow and 0 or 1,'up',{via='boot',freshBoot=true})
 else OW:onStepComplete() end
 if protected then
  eq(#controller.followers,0,'Followers recalled on the grass step before Oak appears')
  check(controller.tick~=nativeTick,'Companion driver held while native story owns the world')
  local ghost
  for _,n in ipairs(OW.npcs)do if n._hoenntoRecall then ghost=n end end
  check(ghost~=nil,'Visible follower gets a recall animation')
  check(ghost.passable and ghost.fxOnly and ghost.pureFx,'Recall ghost is presentation only')
  local inDrawList=false
  for _,e in ipairs(OW.entities)do if e==ghost then inDrawList=true end end
  check(inDrawList,'Recall ghost remains in the native draw list')
  eq(require('src.world.Collision').occupied(OW.entities,ghost.cellX,ghost.cellY),nil,'Recall ghost has no collision occupancy')
  local gfx=love.graphics
  local oldCircle,oldArc,oldScale=gfx.circle,gfx.arc,gfx.scale
  local circles,arcs,scales=0,0,0
  gfx.circle=function(mode,px,py,radius)if radius>0 then circles=circles+1 end end
  gfx.arc=function()arcs=arcs+1 end
  gfx.scale=function()scales=scales+1 end
  Runtime.call('input.step',function()end,Game,1/60)
  check(ghost.elapsed>0,'Recall animation advances while native dialogue is open')
  gfx.setColor(.1,.2,.3,.4);ghost:draw(0,0)
  check(circles>0 and arcs>0,'Recall draws the shrinking Pokeball')
  check(scales>0,'Recall scales the visible companion into its ball')
  local r,g,b,a=gfx.getColor()
  check(r==.1 and g==.2 and b==.3 and a==.4,'Recall restores the native graphics state')
  gfx.circle,gfx.arc,gfx.scale=oldCircle,oldArc,oldScale
  eq(Runtime.call('world.follower.spawn',function()return true end,Game,OW),false,'Stock companion spawning held during Oak story')
 end
 local overlap,unsafe,labEntered,completed=false,false,false,false
 local ticksAtTrigger=controller.ticks
 local droppedOak,dropFrame
 for frame=1,5000 do
  if loseOak and not droppedOak then
   for _,move in ipairs(OW.scriptMoves or {})do
    local oak=move.entity
    if oak and oak.def.name=='PALLETTOWN_OAK' and oak.moving and move.remaining==0
      and oak.targetX==x and oak.targetY==2 and (oak.progress or 0)>=30 then
     -- Simulate a list rebuild losing the actor on the last approach frame.
     -- Rendering still sees Oak, but native update cannot retire his move.
     for i=#OW.npcs,1,-1 do if OW.npcs[i]==oak then table.remove(OW.npcs,i)end end
     droppedOak,dropFrame=oak,frame
     break
    end
   end
  end
  local top=Stack:top();pressA=(top and top.isTextBox==true) or (droppedOak~=nil and not protected)
  Runtime.call('input.step',function()end,Game,1/60)
  if protected and not Game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON then
   eq(controller.ticks,ticksAtTrigger,'Companion tick cannot respawn or interfere during native scene')
  end
  for _,n in ipairs(OW.npcs)do if n.def.name=='PALLETTOWN_OAK' then
   for _,e in ipairs(controller.followers)do if not e.hidden and n.cellX==e.cellX and n.cellY==e.cellY then overlap=true end end
  end end
  if top and top.isTextBox and not unsafe and OW:npcByIndex(1) then
   local text=table.concat(top.pages[1]or {},' ')
   unsafe=text:find('unsafe',1,true)~=nil or text:find('close',1,true)~=nil
  end
  labEntered=labEntered or OW.map.id=='OAKS_LAB'
  Stack:update(1/60)
  if droppedOak and not protected and frame-dropFrame>120 then
   check(not unsafe and not labEntered,'Lost Oak scheduler reproduces the silent approach freeze')
   check(droppedOak.moving and #OW.scriptMoves>0,'Native movement callback remains blocked despite A presses')
   eq(Stack:top(),OW,'Frozen scene remains in the overworld')
   Runtime.reset();return
  end
  if Game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON then completed=true;break end
 end
 check(unsafe,'Native Oak arrival dialogue opens in '..version)
 check(labEntered,'Native Oak escort warps into the lab in '..version)
 check(completed,'Native lab starter speech finishes in '..version)
 if loseOak then check(droppedOak~=nil,'Recovery test actually dropped the moving Oak instance')end
 eq(OW.player.cellX,5,'Native player walk-in ends in the lab aisle')
 eq(OW.player.cellY,3,'Native player walk-in stops before the desk')
 eq(Game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB,true,'Native script owns its escort completion flag')
 eq(Game.save.flags.EVENT_GOT_STARTER,nil,'Local starter selection remains pending')
 eq(Game.save.party[1].nickname,'IMPORTED','Imported party survives the full native story')
 eq(Game.save.party[1].otId,42,'Imported original trainer survives the full native story')
 if protected then
  eq(overlap,false,'Oak never stands on a follower during the protected scene')
  Runtime.call('input.step',function()end,Game,1/60)
  eq(controller.tick,nativeTick,'Native companion driver restored after speech closes')
  eq(#controller.followers,1,'Configured follower returns after the scene')
  eq(Runtime.call('world.follower.spawn',function()return true end,Game,OW),true,'Stock follower policy restored after the scene')
 else check(overlap,'Negative control reproduces Oak/follower stacking without protection')end
 Runtime.reset()
end
for _,version in ipairs({'red','blue','yellow'})do
 for _,x in ipairs({10,11})do fixture(version,x,false);fixture(version,x,true)end
 fixture(version,10,'fresh')
end
fixture('red',10,true,'firered',true)
fixture('red',11,true,'firered',true)
fixture('red',10,false,'firered',true,true)
fixture('red',10,true,'firered',true,true)
package.loaded['src.battle.BattleState']=nativeBattle
print('Oak native intro / imported GB-GBA party / revisit / follower recall checks',checks)
