package.path='./?.lua;./?/init.lua;'..package.path
local root=assert(arg[1])
local C=assert(loadfile(root..'/campaign.lua'))()
local options={modsByVersion={firered={dex=true},emerald={dex=false}}}
local SD={loadOptions=function()return options end,modEnabled=function(o,id,v)return o.modsByVersion[v][id]end}
package.loaded['src.core.SaveData']=SD
package.loaded['src.import.CacheFs']={}
local ready=true
package.loaded['src.import.CacheContract']={isReady=function()return ready end}
local B=assert(loadfile(root..'/travel.lua'))()(C,{})
local P=assert(loadfile(root..'/presentation.lua'))()(C,B)
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local text,opts,choice,queued
package.loaded['src.ui.game3.message']={show=function(t,o)text=t;opts=o end,reset=function()text=nil end,showStay=function(t)text=t end}
package.loaded['src.ui.game3.choice']={yesNo=function(cb)choice=cb end}
package.loaded['src.ui.game3.hud']={openMessage=function(_,t)text=t end}
local manifest={id='dex',name='1025Dex',games={'firered','emerald'}}
local game={phase='field',session={version='firered',map='FR_PALLET_TOWN',flags={[0x820]=true,[0x821]=0},modData={}},mods={mods={dex={manifest=manifest}},loaded={{manifest=manifest}}},quickSaveAllowed=function()return true end}
eq(#B.compatibility(game,'emerald'),1,'disabled destination companion detected')
P.request(game,'emerald',function(t)queued=t end)
eq(text:find('Travel needs attention',1,true)~=nil,true,'actionable compatibility message')
eq(queued,nil,'mismatch cannot depart')
options.modsByVersion.emerald.dex=true
eq(#B.compatibility(game,'emerald'),0,'matching setup accepted')
manifest.games={'firered'}
eq(#B.compatibility(game,'emerald'),1,'unsupported target detected')
manifest.games={'firered','emerald'}
game.mods.loaded={}
eq(#B.compatibility(game,'emerald'),1,'skipped source companion detected')
game.mods.loaded={{manifest=manifest}}
options.modsByVersion.firered.dex=false
eq(#B.compatibility(game,'emerald'),1,'destination-only species mod detected')
options.modsByVersion.firered.dex=true
P.request(game,'emerald',function(t)queued=t end)
eq(text:find('Welcome to Hoennto',1,true)~=nil,true,'first-trip guidance')
opts.done()
eq(text:find('Start a new regional story',1,true)~=nil,true,'first arrival labeled')
opts.done()
eq(package.loaded['src.ui.game3.choice'].cursor,2,'default NO')
choice(false)
eq(queued,nil,'NO cancels without travel')
eq(game.session.modData[C.KEY],nil,'cancellation leaves campaign untouched')
P.request(game,'emerald',function(t)queued=t end);opts.done();opts.done();choice(true)
eq(queued,'emerald','YES queues exact target')
game.session.modData[C.KEY]={travelGuideSeen=true,regions={emerald={map='EM_OLDALE_TOWN',flags={['2151']=true,[2152]=true}}},kantoVersion='firered'}
P.request(game,'emerald',function()end)
eq(text:find('Return to saved progress',1,true)~=nil,true,'return labeled and guide skipped')
eq(P.badges(game.session,'firered'),1,'Kanto badge flags and zero values')
eq(P.badges(game.session.modData[C.KEY].regions.emerald,'emerald'),2,'Emerald badge flags and string keys')
local summary=P.overview(game)
eq(summary:find('Badges: 2/8',1,true)~=nil,true,'inactive progress summary')
eq(summary:find('Oldale Town',1,true)~=nil,true,'readable inactive saved location')
eq(summary:find('Story not started',1,true)~=nil,true,'unlinked cartridge summary')
ready=false
P.request(game,'emerald',function()error('missing ROM queued')end)
eq(text:find('Import Hoenn',1,true)~=nil,true,'missing ROM guidance')
P.loading('leafgreen')
eq(text:find('Kanto - LeafGreen',1,true)~=nil,true,'loading names cartridge')
P.closeLoading();eq(text,nil,'loading closes before save gate')
print('presentation_test: '..checks..' checks passed')
