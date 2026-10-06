-- Run from the stock 0.3.51 engine source root. Optional ROM path is arg[2].
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local root=assert(arg[1])
local C=assert(loadfile(root..'/campaign.lua'))()
local choice='auto'
local B=assert(loadfile(root..'/travel.lua'))()(C,{options={get=function(_,key)return key=='kanto_game' and choice or 'auto' end}})
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local ready={}
package.loaded['src.import.CacheContract']={isReady=function(v)return ready[v] end}
local function game(v,state)
 return {session={version=v,modData={[C.KEY]=state}},options={}}
end
eq(C.validVersion('leafgreen'),true,'LeafGreen campaign accepted')
eq(C.validVersion('crystal'),true,'Crystal campaign accepted')
eq(B.destination(game('leafgreen')),'emerald','LeafGreen goes to Hoenn')
eq(B.destination(game('firered')),'emerald','FireRed goes to Hoenn')
eq(B.destination(game('crystal')),'red','Crystal has travel destination')
ready.leafgreen=true
eq(B.destination(game('emerald')),'leafgreen','only imported Kanto game auto-selected')
ready.firered=true
eq(B.destination(game('emerald')),'firered','both imported defaults to FireRed')
local old={version=1,regions={firered={}},slots={firered='fr'}}
eq(B.destination(game('emerald',old)),'firered','legacy linked FireRed preserved')
local linked={version=1,regions={leafgreen={}},slots={leafgreen='lg'}}
eq(B.destination(game('emerald',linked)),'leafgreen','LeafGreen link inferred')
linked.kantoVersion='leafgreen';linked.regions.firered={};linked.slots.firered='fr'
eq(B.destination(game('emerald',linked)),'leafgreen','remembered LeafGreen wins over installed FireRed')
choice='firered'
eq(B.destination(game('emerald',linked)),'firered','explicit choice overrides auto')
choice='leafgreen'
eq(B.destination(game('emerald',old)),'leafgreen','existing campaign can choose LeafGreen')
eq(B.destination(game('firered',old)),'emerald','Kanto departure ignores selection')
ready.leafgreen=false
eq(B.available('leafgreen'),false,'missing explicitly selected ROM denied')
choice='auto'

-- Exercise real engine LeafGreen/FireRed schemas with separate snapshots.
local GV=require('src.core.GameVersion')
local Schema=require('src.core.game3.save_schema_firered')
local SD=require('src.core.SaveData')
local state
for _,v in ipairs({'firered','leafgreen'}) do
 GV.set(v)
 local s=Schema.newGame({version=v,name='JOHN',trainerIdLower=42,rngSeed=1})
 eq(s.version,v,'native new-game version')
 eq(s.map,'FR_PLAYERS_HOUSE_2F','native Kanto starting map')
 s.money=v=='firered' and 1234 or 5678
 s.flags[0x820]=v=='firered'
 s.party={{species=25,exp=111,hp=10}}
 local raw=Schema.toSaveTable(s)
 state=C.capture(raw,state)
 state.slots[v]=v..'-slot'
 eq(C.restore(state,v).version,v,'campaign version preserved')
 eq(Schema.fromSaveTable(C.restore(state,v)).version,v,'native continue version preserved')
end
eq(C.kantoVersion(state),'leafgreen','last visited Kanto game remembered')
eq(C.restore(state,'firered').money,1234,'FireRed wallet isolated')
eq(C.restore(state,'leafgreen').money,5678,'LeafGreen wallet isolated')
eq(C.restore(state,'firered').flags[0x820],true,'FireRed badge isolated')
eq(C.restore(state,'leafgreen').flags[0x820],false,'LeafGreen badge isolated')
local saves=0
local arriving={options=SD.defaultOptions(),phase='boot',quickSaveAllowed=function()return false end,
 adoptSave=function()end,_enterField=function(self,s,reason,opts)self.session=s;self.phase='field';self.reason=reason;self.callback=opts.fieldCallback end}
GV.set('leafgreen')
B.resume(arriving,{target='leafgreen',state=state})
eq(arriving.session.version,'leafgreen','real schema bridge resumes LeafGreen')
eq(arriving.reason,'continue','existing LeafGreen story resumes')
eq(arriving.session.money,5678,'LeafGreen wallet restored through bridge')
eq(arriving.callback,nil,'no Emerald truck callback in LeafGreen')
state.regions.leafgreen=nil
B.resume(arriving,{target='leafgreen',state=state})
eq(arriving.session.version,'leafgreen','real schema bridge starts LeafGreen')
eq(arriving.reason,'new_game','first LeafGreen visit creates native story')
eq(arriving.session.map,'FR_PLAYERS_HOUSE_2F','first LeafGreen visit native bedroom')
eq(arriving.session.trainerId,42,'shared trainer survives native LeafGreen initialization')

local manifestText=assert(io.open(root..'/manifest.json')):read('*a')
local manifest=require('src.link.Json').decode(manifestText)
local validated=require('src.mods.Manifest').validate(manifest,root)
eq(validated.id,C.KEY,'engine manifest validator accepts updated mod')
eq(validated.github,'Bentley734/Hoennto','launcher update repository validated')
eq(validated.name,'Hoennto','renamed launcher title')
eq(validated.version,'0.2.0','release version')
eq(manifest.games[10],'leafgreen','manifest exposes LeafGreen')
for _,f in ipairs({'main.lua','campaign.lua','travel.lua','reset_menu.lua','mount_lifecycle.lua','transition.lua','presentation.lua'}) do
 eq(type(assert(loadfile(root..'/'..f))),'function','production Lua compiles: '..f)
end
if arg[2] then
 local sha='7862c67bdecbe21d1d69ce082ce34327e1c6ed5e'
 local imports=require('src.import.gba.file_io').makeImports(arg[2],sha,'leafgreen')
 local rom=assert(require('src.import.gba.rom').open(imports,'leafgreen'))
 eq(require('src.import.gba.versions').active(),'leafgreen','actual ROM selects LeafGreen importer')
 eq(rom:ensureBuffer():sub(0xad,0xb0),'BPGE','actual ROM header preserved')
 eq(rom.size,16*1024*1024,'actual supported ROM size')
 imports:_close()
end
print('LeafGreen selection/native-schema checks',checks)
