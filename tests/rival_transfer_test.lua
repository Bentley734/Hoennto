local root=assert(arg[1])
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local SD=require('src.core.SaveData')
local Bridge=assert(loadfile(root..'/travel.lua'))()(C,{})
local Adapter=assert(loadfile(root..'/runtime.lua'))()
local Save2=require('src.core.gen2.Save')
local GV=require('src.core.GameVersion')
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function raw(v,name)
 local s={version=v,modData={},player={name='ASH',id=42},flags={story=v},party={},boxes={},pokedex={}}
 if C.generation(v)==1 then s.player.rival=name
 elseif C.generation(v)==2 then s.rival={name=name}
 else s.name='ASH';s.trainerId=42;s.rivalName=name end
 return s
end
for _,source in ipairs(C.ORDER)do
 local origin=raw(source,'gary');local state=C.state(origin)
 C.capture(origin,state);eq(state.rival,nil,'ordinary saves do not choose a campaign rival')
 C.beginRival(origin,state);C.capture(origin,state)
 eq(state.rival.source,source,'first departure owns rival identity')
 for _,target in ipairs(C.ORDER)do if target~=source then
  local dst=raw(target,'OTHER');state.slots[target]=3
  C.beginRival(dst,state);C.applyRival(dst,state)
  eq(C.rivalName(dst),'gary',source..' -> '..target..' inherits exact name and case')
  eq(state.rival.name,'gary','later departures cannot replace original name')
  C.capture(dst,state)
  local restored=C.restore(state,target)
  eq(C.rivalName(restored),'gary','revisit restores campaign rival')
  eq(restored.flags.story,target,'rival transfer preserves local story')
 end end
 origin.player.rival='LOCAL';origin.rival={name='LOCAL'};origin.rivalName='LOCAL'
 C.applyRival(origin,state);eq(C.rivalName(origin),'LOCAL','original source remains independently named')
 eq(state.rival.name,'gary','campaign keeps first departure name even if source later changes')
 local unrelated=raw('red','UNRELATED');C.applyRival(unrelated)
 eq(C.rivalName(unrelated),'UNRELATED','unlinked saves remain unchanged')
end
local pending=C.state(raw('gold'))
C.beginRival(raw('gold','???'),pending)
C.beginRival(raw('red','BLUE'),pending)
eq(pending.rival.name,nil,'unnamed Gen 2 rival does not adopt a destination default')
C.capture(raw('gold','SILVER'),pending)
eq(pending.rival.name,'SILVER','first source can supply a name after its native naming event')
local legacy={version=2,regions={},slots={red=1,blue=2},shared=C.shared(raw('red','gary'))}
C.beginRival(raw('red','gary'),legacy)
local old=raw('blue','BLUE');legacy.regions.blue=C.snapshot(old)
eq(C.rivalName(C.restore(legacy,'blue')),'gary','existing Hoennto-created stories adopt name on revisit')
for _,v in ipairs({'ruby','sapphire','emerald'})do
 eq(C.rivalName({version=v,gender=0}),'MAY','native male-player source rival')
 eq(C.rivalName({version=v,gender=1}),'BRENDAN','native female-player source rival')
end
-- Real GB save constructors retain the transferred native fields on serialization.
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'})do
 GV.set(v)
 local dst=C.generation(v)==1 and SD.newGame({version=v}) or Save2.newGame({playerName='ASH'})
 local state={rival={source='firered',name='gary'},slots={[v]=1}}
 C.applyRival(dst,state)
 local bytes=require('src.core.SaveSerializer').encode(dst)
 local copy=assert(load(bytes,'save','t',{}))()
 eq(C.rivalName(copy),'gary','native '..v..' save roundtrip retains rival')
 eq(require('src.render.TextBox').TOKENS.RIVAL({save=copy}),'gary','native GB dialogue uses transferred name')
 state.shared=C.shared(raw('firered','gary'));state.regions={};state.version=2
 C.runtime={newSave=Adapter.newSave,resume=function(game,save,isNew)
  game.session=save;eq(isNew,true,'GB arrival uses its native new-save path')
 end}
 local host={options=SD.defaultOptions(),bootConfig=function()return {version=v}end,
  quickSaveAllowed=function()return false end}
 Bridge.resume(host,{target=v,state=state})
 eq(C.rivalName(host.session),'gary','Bridge seeds '..v..' rival before arrival')
end
C.runtime=nil
-- Native RSE text expansion and trainer presentation, using real constant IDs.
local game={generation=3}
local R=assert(loadfile(root..'/rival.lua'))()(C,function()return game end)
R.install({generation=2})
local World2=require('src.world.gen2.World')
for _,v in ipairs({'gold','silver','crystal'})do
 local save=raw(v,'gary');save.modData[C.KEY]={rival={source='red',name='gary'},slots={[v]=2}}
 local finished=0;local world=setmetatable({game={save=save}}, {__index=World2})
 world:nameRival(function(name)eq(name,'gary','native Gen 2 naming event returns the campaign name');finished=finished+1 end)
 eq(finished,1,'native naming continuation resumes exactly once')
 eq(save.rival.name,'gary','police naming event cannot replace transferred rival')
 save.modData={};save.rival.name='LOCAL'
 world:nameRival(function(name)eq(name,nil,'unlinked naming event follows native path')end)
 eq(save.rival.name,'LOCAL','unlinked naming event is unchanged')
end
local Text=require('src.core.game3.scripting.text_ir')
local Trainers=require('src.core.game3.scripting.trainers')
local Constants=require('src.core.game3.constants')
local originalPack=Trainers._pack
local originalFoe=Trainers.foeFromId
local party={fixture='native-party'}
Trainers.foeFromId=function(id)return {trainerName='NATIVE',party=party,personality=12345}end
for _,v in ipairs({'ruby','sapphire','emerald'})do
 GV.set(v)
 game.session=raw(v,'gary');game.session.modData[C.KEY]={rival={source='red',name='gary'},slots={[v]=2}}
 R.install(game)
 local ctx={dialect=Text.dialectOf(v),playerGender=0,
  placeholders={byGender={RIVAL={male='MAY',female='BRENDAN'},KUN={male='X',female='Y'}}}}
 local ir=Text.fromAscii('Hi, {RIVAL}!',{dialect=ctx.dialect})
 eq(Text.toPlain(ir,ctx),'Hi, gary!','native '..v..' rival placeholder uses campaign name')
 ctx.playerGender=1
 eq(Text.toPlain(ir,ctx),'Hi, gary!','female-player dialogue uses same campaign name')
 eq(ctx.placeholders.byGender.RIVAL.male,'MAY','ROM placeholder input is not mutated')
 local constants=Constants.of(v).trainers.byName
 local rows={};local rivalCount=0;local unrelatedId
 for key,id in pairs(constants)do
  if key:match('^TRAINER_MAY_') or key:match('^TRAINER_BRENDAN_')then
   rows[id]={class=0,name='NATIVE',party={}};rivalCount=rivalCount+1
  elseif key:match('^TRAINER_WALLY_')then unrelatedId=id;rows[id]={class=0,name='WALLY',party={}}end
 end
 Trainers._pack={trainers=rows}
 eq(rivalCount>0,true,'real RSE constants identify rival battles')
 for id in pairs(rows)do
  local info=Trainers.info(id)
  eq(info.name,id==unrelatedId and 'WALLY' or (rows[id].name=='WALLY' and 'WALLY' or 'gary'),'only main rival trainer presentation changes')
  local foe=Trainers.foeFromId(id)
  eq(foe.trainerName,rows[id].name=='WALLY' and 'NATIVE' or 'gary','foe battle display uses transferred rival')
  eq(foe.party,party,'rival naming never reconstructs or changes the trainer party')
  eq(foe.personality,12345,'rival naming preserves native battle data')
 end
 game.session.modData={}
 eq(Text.toPlain(ir,ctx),'Hi, BRENDAN!','unrelated save uses native gender placeholder')
 local id=next(rows)
 eq(Trainers.info(id).name,rows[id].name,'unrelated save uses native trainer name')
end
Trainers._pack=originalPack
-- No cold Gen 1/2 imports: installing there returns before any Gen 3 require.
local cold=assert(loadfile(root..'/rival.lua'))()(C,function()return nil end)
cold.install({generation=1});cold.install({generation=2})
print('Campaign rival names / eleven-game routes / native RSE presentation checks',checks)
