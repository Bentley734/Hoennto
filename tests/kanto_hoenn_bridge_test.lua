package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
local root=arg[1] or "mods/kanto_hoenn"
local cacheBase=os.getenv("KANTO_HOENN_TEST_CACHE")
if not cacheBase then print("kanto_hoenn_bridge_test: SKIP (set KANTO_HOENN_TEST_CACHE to the ROM fixture cache parent)");return end
local C = assert(loadfile(root.."/campaign.lua"))()
local Bridge = assert(loadfile(root.."/travel.lua"))()(C,{})
local GV = require("src.core.GameVersion")
local Schema = require("src.core.game3.save_schema_firered")
local SD = require("src.core.SaveData")
local Dataset = require("src.core.game3.dataset")
-- Headless fixture for optional town presentation systems, matching the
-- upstream schema test. The actual ROM reset script and native save fields
-- remain active; this test does not exercise these optional NPC systems.
local Sections = require("src.core.game3.save_sections")
for _, name in ipairs({"dewfordTrends","oldMan","lilycoveLady","apprentice"}) do
  Sections.register(name, Sections.fields({name}))
end
local Contract = require("src.import.CacheContract")
local checks=0
local function eq(a,b,m) checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
-- Native schemas and the real extracted Emerald reset-map script are used.
local options=SD.defaultOptions();options.saveSlots={}
local slots,active,writes,names={}, {}, {}, {}
local nextSlot=0
SD.loadOptions=function() return C.copy(options) end
SD.createSlot=function(v) nextSlot=nextSlot+1;local id='slot'..nextSlot;slots[v]=slots[v] or {};slots[v][id]=true;options.saveSlots[v]={list={id}};return id end
SD.activeSlot=function(v)return active[v]end
SD.setActiveSlot=function(v,id)active[v]=id;return id end
SD.renameSlot=function(v,id,name)names[v..id]=name end
SD.getCart=function()return nil end
SD.writeSlot=function(v,id,raw)writes[v..id]=C.copy(raw);return true end
Contract.isReady=function()return true end
local function cache(v)
  GV.set(v);require("src.import.gba.versions").select(v)
  Dataset.cacheRootOverride=cacheBase.."/"..v.."-cache/data/generated/gba"
  require("src.core.game3.scripting.space").bundle=nil
end
local function game(session)
  local g={session=session,phase=session and 'field' or 'boot',options=C.copy(options),safe=true}
  function g:quickSaveAllowed() return self.safe and self.phase=='field' end
  function g:saveGame()
    if self.failSave then return false end
    local raw=Schema.toSaveTable(self.session); Bridge.prepareSave(self,raw);self.save=raw
    writes[self.session.version..(active[self.session.version] or 'legacy')]=C.copy(raw)
    Bridge.afterSave(self,raw);return true
  end
  function g:adoptSave(s)self.adopted=s end
  function g:_enterField(s,reason,opts)self.session=s;self.phase='field';self.reason=reason;self.fieldCallback=opts.fieldCallback end
  return g
end
cache('firered')
local source=Schema.newGame({name='JOHN',gender=0,rngSeed=1})
source.map='FR_VIRIDIAN_CITY';source.x=6;source.y=7
source.flags[0x820]=true;source.vars[0x4000]=17
source.storage.boxes[3].name='JOHNS BOX'
local g=game(source)
g.safe=false;eq(Bridge.prepare(g,'emerald'),nil,'busy field denied');g.safe=true
Contract.isReady=function()return false end;eq(Bridge.prepare(g,'emerald'),nil,'missing import denied');Contract.isReady=function()return true end
g.failSave=true;eq(Bridge.prepare(g,'emerald'),nil,'failed save denied');g.failSave=false
local payload=assert(Bridge.prepare(g,'emerald'))
eq(payload.source,'firered','source correct');eq(payload.target,'emerald','target correct')
eq(type(payload.state.slots.firered),'string','source slot linked')
eq(type(payload.state.slots.emerald),'string','new destination slot linked')
eq(payload.state.regions.emerald,nil,'no artificial completed Emerald story')
eq(names['emerald'..payload.state.slots.emerald],'Hoennto','new target named')
cache('emerald');Bridge.selectSlot(payload)
local hoenn=game(nil);Bridge.resume(hoenn,payload)
eq(hoenn.reason,'new_game','first visit actual new game')
eq(hoenn.fieldCallback,'truck','real truck callback selected')
eq(hoenn.session.map,'EM_INSIDE_OF_TRUCK','real truck start map')
eq(hoenn.session.name,'JOHN','same trainer name')
eq(hoenn.session.trainerId,source.trainerId,'same TID')
eq(hoenn.session.secretId,source.secretId,'same SID')
eq(hoenn.session.flags[0x820],nil,'FireRed gym flag never transferred')
eq(hoenn.session.vars[0x4000],nil,'FireRed story var never transferred')
eq(hoenn.session.storage.boxes[3].name,'JOHNS BOX','boxes follow trainer')
eq(hoenn.session.money,3000,'native Emerald initial money')
eq(hoenn._regionTravelAutosave,true,'truck cannot be saved halfway through callback')
local EC=require('src.core.game3.constants').of('emerald')
local Flags=require('src.core.game3.scripting.flags')
eq(Flags.getFlag(hoenn.session,nil,EC:require('flags','FLAG_HIDE_LITTLEROOT_TOWN_BIRCHS_LAB_BIRCH')),true,'actual ROM reset script ran')
-- Safely end the opening, save, and advance a regional flag.
hoenn.session.map='EM_OLDALE_TOWN';hoenn.session.x=9;hoenn.session.y=4
hoenn.session.flags[EC:require('flags','FLAG_BADGE01_GET')]=true
Bridge.tick(hoenn)
eq(hoenn._regionTravelAutosave,nil,'arrival saved once after leaving truck')
local backPayload=assert(Bridge.prepare(hoenn,'firered'))
local peer=writes['firered'..backPayload.state.slots.firered]
eq(peer.modData.kanto_hoenn.regions.emerald.map,'EM_OLDALE_TOWN','inactive save receives latest Emerald story')
cache('firered');Bridge.selectSlot(backPayload)
local back=game(nil);Bridge.resume(back,backPayload)
eq(back.reason,'continue','return resumes real existing story')
eq(back.session.map,'FR_VIRIDIAN_CITY','exact return map')
eq(back.session.x,6,'exact return x')
eq(back.session.flags[0x820],true,'Kanto badge restored')
eq(back.session.vars[0x4000],17,'Kanto story restored')
local again=assert(Bridge.prepare(back,'emerald'));cache('emerald');Bridge.selectSlot(again)
local h2=game(nil);Bridge.resume(h2,again)
eq(h2.reason,'continue','second Hoenn visit resumes')
eq(h2.fieldCallback,nil,'truck never repeats')
eq(h2.session.map,'EM_OLDALE_TOWN','Hoenn return map')
eq(h2.session.x,9,'Hoenn return coordinate')
eq(h2.session.flags[EC:require('flags','FLAG_BADGE01_GET')],true,'Hoenn badge restored')
print('kanto_hoenn_bridge_test: '..checks..' checks passed with native schemas and actual Emerald ROM scripts')
