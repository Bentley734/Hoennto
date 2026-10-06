-- All 110 directed transfers through canonical collection, real stat
-- calculators, native save skeletons, serialization and reserve reconciliation.
local root=arg[1]
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local game={data={pokemon={PIKACHU={id='PIKACHU',name='PIKACHU',baseStats={hp=35,attack=55,defense=40,speed=90,special=50,specialAttack=50,specialDefense=50},types={'ELECTRIC'}},BULBASAUR={id='BULBASAUR',name='BULBASAUR',baseStats={hp=45,attack=49,defense=49,speed=45,special=65,specialAttack=65,specialDefense=65},types={'GRASS'}}},moves={TACKLE={id='TACKLE',pp=35}},items={}}}
local R=assert(loadfile(root..'/roster.lua'))()(C,function()return game end)
C.roster=R
local P={keyName=function(id)return id==25 and 'PIKACHU' or id==1 and 'BULBASAUR' or 'FUTUREMON'end,
 speciesFromName=function(n)return n=='PIKACHU' and 25 or n=='BULBASAUR' and 1 end,
 name=function(id)return id==25 and 'PIKACHU' or 'BULBASAUR'end,
 moveName=function(id)return id==33 and 'TACKLE' or 'FUTUREMOVE'end,
 isShiny=function(m)return m.shiny end,
 applyStats=function(m)m.maxHp=80;m.attack=55;m.defense=40;m.speed=90;m.spAtk=50;m.spDef=50 end}
package.loaded['src.core.game3.pokemon']=P
package.loaded['src.mods.Gen3Compat']={moveId=function(n)return n=='TACKLE' and 33 end}
package.loaded['src.core.game3.items_data']={displayName=function()return 'FUTUREITEM'end,toNumericId=function()return nil end}
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function raw(v)
 local gen=C.generation(v)
 local mon={species=gen==3 and 25 or 'PIKACHU',level=20,exp=8000,experience=8000,hp=40,maxHp=80,
  moves=gen==3 and {33} or {{id='TACKLE',pp=7,ppUps=2}},pp={7},ivs={atk=31},personality=12345,
  dvs={attack=15,defense=10,speed=10,special=10,hp=15},statExp={},otId=42,otName='ASH',otSecretId=77}
 return {version=v,generation=gen,name='ASH',trainerId=42,secretId=77,gender=0,
  player={name='ASH',id=42,map=v..'_HOME',gender='male'},map=v..'_HOME',flags={nativeStory=v},money=987,
  party={mon},boxes={},storage={boxes={},items={{id=13,qty=9}}},dex={},pokedex={},modData={}}
end
for _,source in ipairs(C.ORDER) do for _,target in ipairs(C.ORDER) do if source~=target then
 local state=C.capture(raw(source));local arrived=raw(target)
 R.project(arrived,state)
 eq(#arrived.party,1,source..' -> '..target..' party count')
 eq(arrived.party[1].hp>0,true,'living mon remains living')
 eq(arrived.flags.nativeStory,target,'destination story preserved')
 eq(arrived.money,987,'destination wallet preserved')
 eq(C.generation(target)==3 and arrived.trainerId or arrived.player.id,42,'trainer shared')
 eq(C.generation(target)==3 and arrived.party[1].moves[1] or arrived.party[1].moves[1].id,C.generation(target)==3 and 33 or 'TACKLE','move translated')
 C.capture(arrived,state)
 local returned=raw(source);R.project(returned,state)
 eq(#returned.party,1,'roundtrip collection count')
 if C.generation(source)==3 then eq(returned.party[1].ivs.atk,31,'original IV restored');eq(returned.party[1].personality,12345,'original PID restored');eq(returned.secretId,77,'trainer SID restored') end
 local text=require('src.core.SaveSerializer').encode(state)
 local decoded=assert(load(text,'campaign','t',{}))()
 eq(#decoded.collection.records,1,'collection serializes without recursion')
end end end
local source=raw('firered');source.party[2]={species=9999,level=5,moves={33},hp=20}
source.party[3]={species=1,level=5,moves={9999},hp=20}
source.party[4]={species=1,level=5,moves={33},item=9999,hp=20}
local state=C.capture(source);local old=raw('red');R.project(old,state)
eq(#old.party,1,'unsupported species/move/item excluded')
eq(state.reserveCount,3,'all unsupported records counted')
C.capture(old,state);eq(#state.collection.records,4,'reserve survives save')
old.party={};C.capture(old,state);eq(#state.collection.records,3,'release deletes only projected record')
eq(state.collection.records[1].mon.species,9999,'unsupported species retained verbatim')
-- Capacity overflow is preserved independently of the native box size.
source=raw('firered');source.storage.boxes={{mons={}}}
for i=1,300 do
 local b=math.floor((i-1)/30)+1;source.storage.boxes[b]=source.storage.boxes[b] or {mons={}}
 source.storage.boxes[b].mons[(i-1)%30+1]={species=1,level=20,exp=8000,hp=40,maxHp=80,moves={33},pp={7},ivs={},otId=42}
end
state=C.capture(source);old=raw('red');R.project(old,state)
eq(state.reserveCount,60,'Gen 1 box overflow kept in reserve')
C.capture(old,state);eq(#state.collection.records,301,'overflow survives capture')
local extended=raw('ruby');R.project(extended,state);eq(state.reserveCount,0,'expanded storage restores reserve')
-- A future companion can supply names without changing campaign structure.
game.data.pokemon.FUTUREMON={id='FUTUREMON',baseStats=game.data.pokemon.PIKACHU.baseStats}
source=raw('firered');source.party[1].species=9999;state=C.capture(source);old=raw('red');R.project(old,state)
eq(old.party[1].species,'FUTUREMON','expanded destination species registry used')
game.data.pokemon.FUTUREMON=nil
eq(pcall(R.project,raw('red'),state),false,'incompatible whole party blocks arrival safely')
source=raw('firered');source.storage.boxes={{mons={[3]={species=1,level=20,hp=30,maxHp=80,moves={33},pp={7},ivs={}}}}}
state=C.capture(source);old=raw('red');R.project(old,state)
eq(old.boxes[1][1].species,'BULBASAUR','sparse GBA boxes compact safely in GB storage')
C.capture(old,state);eq(#state.collection.records,2,'compacted GB storage never drops a sparse source mon')
source=raw('gold');source.party[1].status='poison';source.party[1].personality=nil
state=C.capture(source);local gba=raw('ruby');R.project(gba,state)
eq(gba.party[1].status,8,'Gen 2 poison converts to native Gen 3 bits')
eq(gba.party[1].ppBonusesPacked,2,'PP Ups convert into native packed field')
C.capture(gba,state);old=raw('red');R.project(old,state)
eq(old.party[1].status,'PSN','Gen 3 poison converts to Gen 1 status')
C.capture(old,state);local g2=raw('silver');R.project(g2,state)
eq(g2.party[1].status,'poison','Gen 1 poison converts to Gen 2 status')
source=raw('firered');state=C.capture(source)
local resolver=R.resolve
R.resolve=function(kind,name,gen)if kind=='moves' and gen==3 then return 44 end;return resolver(kind,name,gen)end
gba=raw('ruby');R.project(gba,state)
eq(gba.party[1].moves[1],44,'same-generation custom move IDs resolve for destination')
R.resolve=resolver
source=raw('gold');source.party[1].shiny=true;source.party[1].personality=nil
state=C.capture(source);gba=raw('ruby');R.project(gba,state)
local pid=gba.party[1].personality
eq(require('bit').bxor(gba.party[1].otId,gba.party[1].otSecretId,math.floor(pid/65536),pid%65536)<8,true,'first Gen 3 transfer preserves shiny PID invariant')
source=raw('gold');state=C.capture(source);source.party={};C.capture(source,state)
eq(#state.collection.records,0,'release of source-caught record stays released')
print('All eleven games / 110 directed transfer checks',checks)
