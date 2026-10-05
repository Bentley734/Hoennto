package.path = "./?.lua;./?/init.lua;" .. package.path
local root=arg[1] or "mods/kanto_hoenn"
local C = assert(loadfile(root.."/campaign.lua"))()
local Ser = require("src.core.SaveSerializer")
local tests = 0
local function eq(a,b,msg) tests=tests+1;assert(a==b, msg .. ': '..tostring(a)..' != '..tostring(b)) end
local fr = { engine="game3", version="firered", name="JOHN",gender=0, trainerId=123,secretId=456,
  map="FR_VIRIDIAN_CITY", x=6,y=7,facing="left", flags={[0x820]=true}, vars={[0x4000]=4},
  party={{species=25,hp=17,exp=555,personality=4321,otId=123,otSecretId=456,moves={85}, pp={9},ivs={atk=31}, item=13}},
  storage={currentBox=2,items={{id=13,qty=5}},boxes={{mons={[4]={species=1,nickname="BULBY"}}}}},
  dex={seen={[25]=true},owned={[25]=true},caught={[25]=true},national=true}, money=6000,
  bag={pockets={KEY_ITEMS={{id=99}}}}, modData={followers={enabled=true}}, mail={},move_overlay={} }
local em = { engine="game3",version="emerald",map="EM_SLATEPORT_CITY",x=3,y=9, flags={[0x807]=true},vars={[0x4000]=99},
  money=2222,bag={pockets={KEY_ITEMS={{id=100}}}}, storage={items={{id=13,qty=2}},boxes={}},
  dex={national=false},modData={secretbase={foo=1}} }
local state=C.capture(fr)
state.slots={firered="slot1",emerald="slot2"}
C.apply(em,state.shared); C.capture(em,state)
eq(em.party[1].hp,17,"HP carries without healing")
eq(em.party[1].ivs.atk,31,"IVs intact")
eq(em.trainerId,123,"trainer identity")
eq(em.party[1].otSecretId,456,"OT intact")
eq(em.storage.boxes[1].mons[4].nickname,"BULBY","sparse PC slots shared")
eq(em.storage.items[1].qty,2,"regional PC items")
eq(em.dex.national,false,"national progression local")
eq(em.money,2222,"regional wallet")
em.party[1].hp=8;em.party[1].exp=900;em.party[2]={species=252};em.dex.caught[252]=true
em.vars[0x4000]=101; C.capture(em,state)
local back=C.restore(state,"firered")
eq(back.map,"FR_VIRIDIAN_CITY","return map")
eq(back.x,6,"return x")
eq(back.facing,"left","return facing")
eq(back.party[1].hp,8,"latest party returns")
eq(back.party[2].species,252,"caught mon returns")
eq(back.vars[0x4000],4,"story variables don't collide")
eq(back.flags[0x807],nil,"Hoenn badge never becomes Kanto flag")
eq(back.flags[0x820],true,"Kanto badge retained")
eq(back.money,6000,"Kanto wallet retained")
eq(back.modData.followers.enabled,true,"other mod state retained")
eq(back.dex.caught[252],true,"dex carries")
eq(back.dex.national,true,"Kanto National unlock retained")
back.party[1].hp=1;eq(state.shared.party[1].hp,8,"snapshot has no party alias")
back.modData.followers.enabled=false;eq(state.regions.firered.modData.followers.enabled,true,"snapshot has no mod alias")
local initial=#Ser.encode(state)
for i=1,40 do
  local v=i%2==0 and "firered" or "emerald"
  local raw=C.restore(state,v);raw.party[1].exp=900+i; C.capture(raw,state)
  eq(state.regions[v].modData.kanto_hoenn,nil,"snapshots never recursively contain campaign")
end
eq(#Ser.encode(state)<initial+100,true,"repeated travel bounded save size")
local encoded=Ser.encode(C.restore(state,"emerald"))
local decoded=assert(load(encoded,"save","t",{}))()
eq(decoded.modData.kanto_hoenn.shared.party[1].exp,940,"campaign serializer roundtrip")
eq(decoded.vars[0x4000],101,"Emerald story serializer roundtrip")
eq(decoded.modData.secretbase.foo,1,"Emerald side systems retained")
local cyc={};cyc.loop=cyc;eq(pcall(C.copy,cyc),false,"cycles rejected")
print('kanto_hoenn_campaign_test: '..tests..' checks passed')
