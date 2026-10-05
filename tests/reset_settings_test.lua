local root=arg[1];local C=assert(loadfile(root..'/campaign.lua'))();local B=assert(loadfile(root..'/travel.lua'))()(C,{})
local checks=0;local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local savedOptions,deleted,writes={}, {}, {}
local Options={block=function(o,id)o[id]=o[id]or{};return o[id]end,bind=function(s,o)s.engineOptions=o;s.options=Options.block(o,s.version)end}
-- Lua local initializer cannot refer to itself in its closure.
Options.bind=function(s,o)s.engineOptions=o;s.options=Options.block(o,s.version)end
package.loaded['src.core.game3.options']=Options
package.loaded['src.core.game3.profile']={of=function(id)return {optionsBlock=id}end}
local failDelete=false
package.loaded['src.core.SaveData']={getCart=function()return nil end,loadOptions=function()return C.copy(savedOptions)end,
 saveOptions=function(o)savedOptions=C.copy(o);return true end,
 deleteSlot=function(v,id)deleted[#deleted+1]={v,id};if failDelete then return false,'fixture failure'end;return true end,
 writeSlot=function(v,id,raw)writes[#writes+1]={v,id,raw};return true end}
local selected='auto'
B=assert(loadfile(root..'/travel.lua'))()(C,{options={get=function()return selected end}})
for _,pair in ipairs({{'firered','emerald'},{'leafgreen','emerald'},{'emerald','firered'},{'emerald','leafgreen'}})do
 local source,target=pair[1],pair[2]
 selected=source=='emerald' and target or 'auto'
 local raw={version=source,name='ASH',party={{species=25,hp=10}},storage={boxes={{1}}},dex={seen={[25]=true}},flags={activeStory=true},modData={}}
 local state=C.capture(raw);state.slots[source]='current';state.slots[target]='linked'
 local peer=C.copy(raw);peer.version=target;peer.flags={otherStory=true};C.capture(peer,state)
 local third=(source=='firered' or target=='firered') and 'leafgreen' or 'firered'
 local extra=C.copy(raw);extra.version=third;extra.flags={thirdStory=true};C.capture(extra,state);state.slots[third]='third-slot'
 local game={session={version=source,modData={[C.KEY]=state},options={wildsG3FollowerCount=6,wildsG3FollowerDoze=false,wildsNative_OW_AMBIENT_CRIES=2,textSpeed=0,otherModValue=9}},options={}}
 game.options[source]=game.session.options;game.options[target]={wildsG3FollowerCount=1,wildsG3FollowerJump=true,textSpeed=2,otherModValue=7}
 B.captureWildOptions(game,state);B.applyWildOptions(game,state,target)
 eq(B.syncWildOptions(game),true,'native option change persisted immediately')
 eq(savedOptions.modOptions[C.KEY].sharedWildFollowers.wildsG3FollowerCount,6,'global shared preference stored')
 local stale=C.copy(state);stale.wildFollowersOptions.wildsG3FollowerCount=1
 eq(B.savedWildOptions(game,stale).wildFollowersOptions.wildsG3FollowerCount,6,'newer menu preferences win over older campaign snapshot')
 eq(game.options[target].wildsG3FollowerCount,6,'count travels both directions');eq(game.options[target].wildsG3FollowerDoze,false,'false preserved')
 eq(game.options[target].wildsG3FollowerJump,nil,'stale destination option removed');eq(game.options[target].textSpeed,2,'native game options stay regional');eq(game.options[target].otherModValue,7,'other mod values untouched')
 local safe=true;local failAt;local saves=0;local durable,backup
 function game:quickSaveAllowed()return safe end
 function game:saveGame()
  saves=saves+1;local nextRaw=C.copy(raw);nextRaw.modData={[C.KEY]=C.copy(self.session.modData[C.KEY])}
  B.prepareSave(self,nextRaw);self.save=nextRaw
  if failAt==saves then return false end
  backup=durable and C.copy(durable);durable=C.copy(nextRaw)
  savedOptions=C.copy(self.options);B.afterSave(self,nextRaw);return true
 end
 safe=false;local before=#deleted;eq(B.resetPeer(game,target),false,'busy reset rejected');eq(#deleted,before,'busy reset deletes nothing');safe=true
 failAt=saves+2;eq(B.resetPeer(game,target),false,'failed reset commit rejected');eq(#deleted,before,'failed commit deletes nothing');eq(game.session.modData[C.KEY].regions[target].flags.otherStory,true,'failed commit retains target snapshot')
 failAt=nil;failDelete=true;eq(B.resetPeer(game,target),false,'delete failure reported');eq(game.session.modData[C.KEY].slots[target],'linked','delete failure rolls link back');failDelete=false
 local ok=B.resetPeer(game,target);eq(ok,true,'reset succeeds');eq(deleted[#deleted][1],target,'only inactive region deleted');eq(deleted[#deleted][2],'linked','only linked slot deleted')
 local result=game.session.modData[C.KEY];eq(result.regions[target],nil,'embedded target story erased');eq(result.slots[target],nil,'target slot link erased')
 eq(result.regions[third].flags.thirdStory,true,'unselected Kanto story preserved')
 eq(result.slots[third],'third-slot','unselected Kanto slot preserved')
 eq(backup.modData[C.KEY].regions[target],nil,'source backup cannot resurrect target story')
 eq(result.regions[source].flags.activeStory,true,'active story retained');eq(result.shared.party[1].species,25,'shared party retained');eq(result.shared.dex.seen[25],true,'shared dex retained')
 eq(result.wildFollowersOptions.wildsG3FollowerCount,6,'shared settings retained');eq(C.restore(result,target),nil,'next travel must start a new story')
 local n=#writes;game:saveGame();eq(#writes,n+1,'autosave updates only remaining third game')
 eq(writes[#writes][1],third,'autosave cannot resurrect reset peer')
 eq(B.resetPeer(game,target),false,'repeat reset reports no progress');eq(B.resetPeer(game,source),false,'active save cannot be erased')
end
-- Production manager-row adapter, reload-safe and default NO.
local Manager={buildOptionRows=function()return {{id='reset_peer',step=function()error('placeholder must be inert')end},{id='campaign_overview',step=function()error('overview must be an action')end}}end}
package.loaded['src.mods.ManagerState']=Manager
local closed={};for _,name in ipairs({'mod_manager','option_menu','start_menu'})do
 package.loaded['src.ui.game3.'..name]={close=function()closed[#closed+1]=name end}
end
local queued={};local factory=assert(loadfile(root..'/reset_menu.lua'))()
for _,source in ipairs({'firered','leafgreen','emerald'})do
 local viewed
 factory({},function(a,b)queued[#queued+1]={a,b}end,nil,function(g)viewed=g end)
 local manager={game={session={version=source},mods={exports={kanto_hoenn={}}}},openConfirm=function(self,lines,fn)self.overlay={index=1,onYes=fn,lines=lines}end}
 local rows=Manager.buildOptionRows(manager,{id='kanto_hoenn'},{});eq(rows[1].step,nil,'arrow does not erase');rows[1].activate()
 eq(rows[2].step,nil,'overview arrows are inert');rows[2].activate();eq(viewed,manager.game,'overview action receives active game')
 eq(manager.overlay.index,2,'confirmation defaults to NO');eq(#queued,source=='firered'and 0 or source=='leafgreen'and 1 or 2,'opening confirm queues nothing')
 manager.overlay.onYes();eq(queued[#queued][1],source,'confirmed source bound');eq(queued[#queued][2],source~='emerald'and'emerald'or'firered','dynamic inactive target')
end
eq(#closed,9,'close all parent menu layers before reset');print('Reset/settings/menu checks',checks)
