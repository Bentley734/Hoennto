-- GB generations share DVs and stat experience. Transfers must use live
-- training values while GBA roundtrips retain the archived GB representation.
local root=arg[1]
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local Stats=require('src.pokemon.Stats')
local Mon=require('src.battle.gen2.Mon')
local base={hp=44,attack=48,defense=65,speed=43,special=50,specialAttack=50,specialDefense=64}
local def={id='SQUIRTLE',name='SQUIRTLE',baseStats=base,types={'WATER'},genderRatio=31,
 growthRate='MEDIUM_FAST',level1Moves={'TACKLE'},learnset={},levelMoves={{level=1,move='TACKLE'}}}
local game={data={pokemon={SQUIRTLE=def},moves={TACKLE={id='TACKLE',pp=35}},items={}}}
local R=assert(loadfile(root..'/roster.lua'))()(C,function()return game end)
local checks=0
local function eq(a,b,message)
 checks=checks+1;assert(a==b,message..': '..tostring(a)..' ~= '..tostring(b))
end
local function source(version)
 local gen=C.generation(version)
 local dvs={attack=8,defense=7,speed=6,special=5}
 local effort={hp=4096,attack=2500,defense=1600,speed=900,special=3600}
 local mon
 if gen==1 then
  local rolls={8,7,6,5};local index=0
  mon=require('src.pokemon.Pokemon').new(game.data,'SQUIRTLE',50,function()index=index+1;return rolls[index]end)
  mon.statExp=C.copy(effort);mon.stats=Stats.calc(def,50,mon.dvs,mon.statExp)
 else mon=Mon.new(game.data,'SQUIRTLE',50,{dvs=dvs,statExp=effort}) end
 mon.hp=math.floor(mon.stats.hp/2)
 return mon
end
local function record(version,mon,forms)
 return {id=7,version=version,mon=mon,forms=forms or {},species='SQUIRTLE',moves={'TACKLE'}}
end
local gb1={'red','blue','yellow'};local gb2={'gold','silver','crystal'}
local function transfer(from,to)
 local src=source(from)
 -- Deliberately stale target forms must not roll back training gained in GB.
 local archived={dvs={attack=1,defense=1,speed=1,special=1,hp=15},statExp={hp=0,attack=0,defense=0,speed=0,special=0}}
 local converted=assert(R.convert(record(from,src,{[tostring(C.generation(to))]=archived}),to))
 for _,k in ipairs({'attack','defense','speed','special'})do eq(converted.dvs[k],src.dvs[k],from..' -> '..to..' DV '..k)end
 for _,k in ipairs({'hp','attack','defense','speed','special'})do eq(converted.statExp[k],src.statExp[k],from..' -> '..to..' effort '..k)end
 eq(converted.dvs.hp,5,'HP DV derives from source nibbles')
 local native=C.generation(to)==1 and Stats.calc(def,src.level,src.dvs,src.statExp)or Mon.stats(base,src.dvs,src.level,src.statExp)
 for k,v in pairs(native)do eq(converted.stats[k],v,'destination uses native trained stat '..k)end
 eq(converted.hp,math.ceil(src.hp*converted.maxHp/src.stats.hp),'current HP remains proportional')
 eq(converted.dvs~=src.dvs,true,'DVs copied without source alias')
 eq(converted.statExp~=src.statExp,true,'effort copied without source alias')
 local original=src.statExp.attack;converted.statExp.attack=65535
 eq(src.statExp.attack,original,'destination training does not mutate source record')
end
for _,g1 in ipairs(gb1)do for _,g2 in ipairs(gb2)do transfer(g1,g2);transfer(g2,g1)end end
local src=source('gold');src.dvs.hp=nil
local converted=assert(R.convert(record('gold',src),'red'))
eq(converted.dvs.hp,5,'missing native Gen 2 HP DV rebuilt for Gen 1')
eq(converted.stats.hp,Stats.calc(def,src.level,{attack=8,defense=7,speed=6,special=5,hp=5},src.statExp).hp,'rebuilt HP DV feeds Gen 1 stats')
src=source('gold');src.dvs.specialAttack=src.dvs.special;src.dvs.special=nil
src.statExp.specialAttack=src.statExp.special;src.statExp.special=nil
converted=assert(R.convert(record('gold',src),'red'))
eq(converted.dvs.special,5,'legacy Gen 2 Special DV alias reaches Gen 1')
eq(converted.statExp.special,3600,'legacy Gen 2 Special effort alias reaches Gen 1')
local gba={species=7,level=50,exp=125000,hp=60,maxHp=120,moves={33},pp={35},
 ivs={hp=31,atk=31,def=31,spe=31,spa=31,spd=31},evs={hp=252},otId=42}
for _,target in ipairs({'red','gold'})do
 local archived=source(target)
 local r=record('firered',gba,{[tostring(C.generation(target))]=archived})
 converted=assert(R.convert(r,target))
 for _,k in ipairs({'attack','defense','speed','special','hp'})do eq(converted.dvs[k],archived.dvs[k],'GBA roundtrip keeps archived DV '..k)end
 for _,k in ipairs({'hp','attack','defense','speed','special'})do eq(converted.statExp[k],archived.statExp[k],'GBA roundtrip keeps archived effort '..k)end
end
-- A GB forced-shiny marker must not replace a valid native DV spread.
src=source('red');local r=record('red',src);r.shiny=true
converted=assert(R.convert(r,'gold'))
eq(converted.dvs.attack,8,'GB DV preservation survives companion shiny marker')
eq(converted.dvs.defense,7,'GB shiny marker does not rewrite other DVs')
print('GB native DV and effort transfer checks',checks)
