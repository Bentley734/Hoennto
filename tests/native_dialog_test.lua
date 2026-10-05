package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local root=assert(arg[1])
local C=assert(loadfile(root..'/campaign.lua'))()
-- Imported text assets are absent in the headless fixture; dialogue/choice
-- control flow remains the real engine implementation.
package.loaded['src.core.game3.rom_text']={plain=function(key)
  return key=='gText_Yes' and 'YES' or 'NO'
end}
local Message=require('src.ui.game3.message')
local Choice=require('src.ui.game3.choice')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local P=assert(loadfile(root..'/presentation.lua'))()(C,{
  available=function()return true end,compatibility=function()return {}end,
  destination=function()return 'firered' end})
local function finishMessage()
  for i=1,100 do
    if not Message.isOpen() or Message.isHeld() then return end
    Message.skipReveal();Message.advance()
  end
  error('dialogue did not finish')
end
for _,version in ipairs({'firered','leafgreen','emerald'}) do
  require('src.core.GameVersion').set(version)
  local game={session={version=version,modData={}},quickSaveAllowed=function()return true end}
  local target=version=='emerald' and 'leafgreen' or 'emerald'
  local queued
  P.request(game,target,function(v)queued=v end)
  check(Message.currentPage():find('Welcome',1,true),'native first-trip guide rendered')
  finishMessage()
  check(Message.isHeld(),'native destination dialogue remains visible with choice')
  check(Choice.isOpen() and Choice.cursor==2,'native confirmation defaults NO')
  Choice.cancel()
  check(not Message.isOpen() and not queued,'native B cancels and closes dialog')
  game.session.modData[C.KEY]={travelGuideSeen=true}
  P.request(game,target,function(v)queued=v end);finishMessage()
  Choice.autoPick(true)
  check(queued==target and not Message.isOpen(),'native YES queues departure')
  P.loading(target)
  check(Message.isWaiting() and Message._stay,'loading text is instantly visible')
  P.closeLoading()
  check(not Message.isOpen(),'loading does not block native save gate')
end
print('native_dialog_test: '..checks..' checks passed through stock Message/Choice')
