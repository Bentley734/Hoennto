-- The stock schema has no action type. Replace only our placeholder row with
-- a confirmed native manager action; arrow presses never perform a reset.
return function(mod,queue,destination,overview)
 local Manager=require('src.mods.ManagerState')
 if not Manager._kantoHoennResetRows then
  local native=Manager.buildOptionRows
  Manager.buildOptionRows=function(self,m,schema)
   local rows=native(self,m,schema)
   local active=self.game and self.game.mods and self.game.mods.exports
   local installer=Manager._kantoHoennResetInstaller
   if m.id=='kanto_hoenn' and installer and active and active.kanto_hoenn then
    installer(self,rows)
   end
   return rows
  end
  Manager._kantoHoennResetRows=true
 end
 Manager._kantoHoennResetInstaller=function(manager,rows)
  local game=manager.game;local session=game and game.session
  if not session then return end
  local source=session.version
  local target=destination and destination(game) or (source=='emerald' and 'firered' or 'emerald')
  local region=target:upper()
  for _,row in ipairs(rows) do
   if row.id=='campaign_overview' and overview then
    row.label='CAMPAIGN OVERVIEW';row.step=nil;row.value=function()return '' end
    row.activate=function()overview(game)end
   end
   if row.id=='reset_peer' then
   row.label='ERASE '..region..' SAVE';row.step=nil;row.value=function()return '' end
   row.activate=function()
    local title=target:upper()
    manager:openConfirm({'ERASE '..title..' STORY?', 'SHARED POKEMON KEPT.', 'THIS CANNOT BE UNDONE.'},function()
     local generation=require('src.core.GameVersion').generation(source)
     if generation==3 then
       require('src.ui.game3.mod_manager').close()
       require('src.ui.game3.option_menu').close()
       require('src.ui.game3.start_menu').close(true)
     elseif generation==2 then game.stack:clear()
     else while game.stack:top() and game.stack:top()~=game.overworld do game.stack:pop() end end
     queue(source,target)
    end)
    -- Destructive action: select NO until the player deliberately changes it.
    manager.overlay.index=2
   end
  end end
 end
end
