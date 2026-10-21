-- Reproduce Cyndaquil's Oran Berry exclusion and preserve its item through GB.
local root=arg[1]
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local def={id='CYNDAQUIL',name='CYNDAQUIL',baseStats={hp=39,attack=52,defense=43,speed=65,special=50,specialAttack=60,specialDefense=50},types={'FIRE'},growthRate='MEDIUM_FAST'}
local game={data={pokemon={CYNDAQUIL=def},moves={TACKLE={id='TACKLE'},LEER={id='LEER'}},items={ORAN_BERRY={id='ORAN_BERRY'}}}}
local R=assert(loadfile(root..'/roster.lua'))()(C,function()return game end)
local P={keyName=function()return 'CYNDAQUIL'end,name=function()return 'CYNDAQUIL'end,speciesFromName=function(n)return n=='CYNDAQUIL' and 155 end,moveName=function(n)return n==33 and 'TACKLE' or 'LEER'end,isShiny=function()return false end,applyStats=function(m)m.maxHp=40 end}
package.loaded['src.core.game3.pokemon']=P
package.loaded['src.mods.Gen3Compat']={moveId=function(n)return n=='TACKLE' and 33 or n=='LEER' and 43 end}
package.loaded['src.core.game3.items_data']={displayName=function()return 'ORAN BERRY'end,toNumericId=function(n)return R.key(n)=='ORANBERRY' and 139 end}
local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' vs '..tostring(b))end
local function native(v)
 return {version=v,party={{species=155,level=8,hp=20,maxHp=30,exp=512,moves={43,33},pp={30,35},item=139,heldItem=139,otId=7,ivs={},evs={}}},storage={boxes={}},modData={}}
end
for _,from in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,to in ipairs({'red','blue','yellow'})do
  local state={};R.capture(native(from),state)
  local gb={version=to,party={},boxes={},modData={}};R.project(gb,state)
  eq(#gb.party,1,'Cyndaquil travels with held Oran Berry '..from..' -> '..to)
  eq(state.reserveCount,0,'held item does not reserve compatible carrier')
  local mon=gb.party[1];eq(mon.species,'CYNDAQUIL','species retained');eq(mon.item,nil,'Gen 1 cannot use held item');eq(mon.heldItem,nil,'no native held slot')
  eq(mon._hoenntoHeldItem,'ORAN BERRY','canonical held item archived')
  eq(mon.moves[1].id,'LEER','first move translated');eq(mon.moves[2].id,'TACKLE','second move translated')
  R.capture(gb,state);eq(state.collection.records[1].item,'ORAN BERRY','Gen 1 save retains archived item')
  mon._hoenntoHeldItem=nil;R.capture(gb,state)
  eq(state.collection.records[1].item,'ORAN BERRY','campaign retains item even if native save strips metadata')
  local again={version=to,party={},boxes={},modData={}};R.project(again,state);R.capture(again,state)
  local returned={version=from,party={},storage={boxes={}},modData={}};R.project(returned,state)
  eq(returned.party[1].item,139,'return restores held Oran Berry');eq(returned.party[1]._hoenntoHeldItem,nil,'native owner clears archive marker')
  returned.party[1].item=nil;returned.party[1].heldItem=nil;R.capture(returned,state)
  eq(state.collection.records[1].item,nil,'consumed or removed item is not resurrected')
 end
end
-- Gen 2 uses native held items where supported; unavailable items still reserve.
local state={};R.capture(native('firered'),state)
local gold={version='gold',party={},boxes={},modData={}};R.project(gold,state)
eq(gold.party[1].heldItem,'ORAN_BERRY','Gen 2 resolves live companion item registry')
local r=state.collection.records[1];r.item='UNSUPPORTED_ITEM'
eq(select(2,R.convert(r,'gold')),'item','unsupported Gen 2 item remains explicit reserve reason')
print('PASS archived held-item travel and roundtrips:',checks)
