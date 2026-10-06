local root=arg[1]
love=require('tests.love_stub')
local C=assert(loadfile(root..'/campaign.lua'))()
local B=assert(loadfile(root..'/travel.lua'))()(C,{options={get=function()return 'auto'end}})
local GV=require('src.core.GameVersion')
local SD=require('src.core.SaveData')
local Schema=require('src.core.game3.save_schema_firered')
local Profile=require('src.core.game3.profile')
local Dataset=require('src.core.game3.dataset')
local nativeCache=Dataset.cache
local contest={defaultWinners={}}
for i=0,7 do contest.defaultWinners[i]={species=0,personality=0,trainerId=0} end
local contestText=require('src.core.SaveSerializer').encode(contest)
local groups={}
for i=0,21 do groups[i]={numWords=1,words={{id=i*512,text='TEST',value=0}}} end
require('src.core.game3.easy_chat_text').install({groups=groups})
Dataset.cache=function()return {read=function(_,path)
 if path=='data/generated/gba/rse/contest/manifest.lua' then return contestText end
 if path=='data/generated/gba/rse/misc/manifest.lua' then return 'return {bard={defaultLyrics={0,0,0,0,0,0}},lady={quizQuestions={{0,0,0,0,0,0,0,0,0}},quizAnswers={0},quizPrizes={13}}}' end
 if path=='data/generated/gba/rse/apprentice/manifest.lua' then return 'return {initialIds={0}}' end
 return nil
end}end
local checks=0;local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
for _,v in ipairs(C.ORDER)do
 GV.set(v)
 local raw
 if C.generation(v)==1 then raw=SD.newGame({version=v})
 elseif C.generation(v)==2 then raw=require('src.core.gen2.Save').newGame({playerName='ASH',trainerId=42})
 else
  local ran
  raw=Schema.toSaveTable(Schema.newGame({version=v,name='ASH',trainerIdLower=42,runScript=function(_,script)ran=script end}))
  if v=='ruby' or v=='sapphire' then
   eq(ran,'EventScript_ResetAllMapFlags','native RS initialization requests ROM reset script')
   eq(raw.map,(v=='ruby' and 'RU_' or 'SA_')..'INSIDE_OF_TRUCK','native RS truck spawn')
  end
 end
 eq(raw.version,v,'native version remains distinct')
 raw.flags={story=v};raw.money=111
 local state=C.capture(raw)
 local restored=C.restore(state,v)
 eq(restored.flags.story,v,'native story isolated')
 local encoded=require('src.core.SaveSerializer').encode(restored)
 eq(assert(load(encoded,'save','t',{}))().version,v,'native save serializes')
 if C.generation(v)==3 then
  local session=Schema.fromSaveTable(restored)
  eq(session.version,v,'native continue schema accepts regional snapshot')
  state.regions[v]=nil
  local rules=Schema.rulesFor(v);local nativeFinish=rules.finishNewGameInit
  local nativeScript=rules.runScriptImmediately
  local nativeInit=rules.newGameInit
  rules.newGameInit=function(session,opts)opts=opts or {};opts.runScript=function()end;return nativeInit(session,opts)end
  rules.runScriptImmediately=function()end
  -- Headless fixture lacks imported script bytecode. Verify the genuine
  -- reset-script request above, while supplying its empty fixture here.
  if nativeFinish then rules.finishNewGameInit=function()end end
  local game={options=SD.defaultOptions(),adoptSave=function()end,quickSaveAllowed=function()return false end,
   _enterField=function(self,s,reason,opts)self.session=s;self.reason=reason;self.callback=opts.fieldCallback end}
  B.resume(game,{target=v,state=state})
  if nativeFinish then rules.finishNewGameInit=nativeFinish end
  rules.runScriptImmediately=nativeScript
  rules.newGameInit=nativeInit
  eq(game.session.version,v,'Bridge uses native first-visit schema')
  eq(game.callback,(Profile.of(v).boot or {}).newGameFieldCallback,'Bridge uses correct native opening callback')
 end
end
eq(C.state({modData={[C.KEY]={version=1,regions={},slots={}}}}).version,2,'old campaign migrates to schema 2')
eq(pcall(C.state,{modData={[C.KEY]={version=99,regions={},slots={}}}}),false,'unknown future campaign fails safely')
print('Native 0.3.54 all-game save schemas / RS opening checks',checks)
Dataset.cache=nativeCache
