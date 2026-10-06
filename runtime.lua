-- The native service owners differ, while main.lua retains one host table.
local A={}
function A.closeMenus(game)
  if game.generation==3 then
    require('src.ui.game3.mod_manager').close()
    require('src.ui.game3.option_menu').close()
    require('src.ui.game3.start_menu').close(true)
  elseif game.generation==2 then game.stack:clear()
  else while game.stack:top() and game.stack:top()~=game.overworld do game.stack:pop() end end
end
function A.generation(v) return require('src.core.GameVersion').generation(v) end
function A.bind(game)
  game.generation=A.generation(require('src.core.GameVersion').get())
  if game.generation==3 then return end
  game.session=game.save
  if not game._hoenntoNativeAdoptSave then
    local native=game.adoptSave
    game._hoenntoNativeAdoptSave=native
    game.adoptSave=function(self,save,...)
      self.session=save
      -- Gen 1 owns options through save.options; NEW GAME and CONTINUE
      -- replace that save after game.ready, so refresh both live aliases.
      if self.generation==1 and save then self.options=save.options or self.options end
      return native(self,save,...)
    end
  end
  game.saveGame=function(self,...)return self:writeSave(...)end
  game.options=game.options or (game.save and game.save.options) or {}
end
function A.fresh(v,host)
  local gen=A.generation(v);local fresh
  if gen==3 then fresh=require('src.core.Game3').new()
  elseif gen==2 then fresh=require('src.core.Game2').new()
  else fresh=require('src.core.Game') end
  if fresh==host then return host end
  for k in pairs(host) do host[k]=nil end
  setmetatable(host,getmetatable(fresh));for k,vv in pairs(fresh) do host[k]=vv end
  if gen==1 then
    -- Native Gen 1 is a singleton. Keep its module handle forwarding to the
    -- app's retained host so lazy engine readers see the live session.
    for k in pairs(fresh) do fresh[k]=nil end
    setmetatable(fresh,{__index=host,__newindex=host})
    host._hoenntoNativeSingleton=fresh
  end
  return host
end
function A.evict(v)
  -- Gen 2's owner reloads generated data and creates a new World at boot.
  -- SessionLifecycle handles asset invalidation and Gen 3 module eviction.
end
function A.endGame(game)
  local native=game._hoenntoNativeSingleton
  local L=require('src.core.SessionLifecycle')
  L.endGameSession(game)
  if native and native~=game then L.endGameSession(native) end
end
function A.bindOptions(game,fullEngine)
  if A.generation(game.session.version)==3 then require('src.core.game3.options').bind(game.session,game.options)
  elseif game.generation==2 then
    if fullEngine or game.options.saveSlots then
      game._hoenntoEngineOptions=game.options
      assert(require('src.core.SaveData').saveOptions(game.options)~=false,'Could not save destination options')
      game.options=require('src.core.gen2.Save').loadOptions()
    end
    game.session.options=game.options
  else game.session.options=game.options end
end
function A.resume(game,raw,isNew)
  local gen=A.generation(raw.version)
  if gen==1 then
    -- Story snapshots omit installation options. Gen 1 reads those options
    -- directly through save.options, so bind the mounted cartridge's live
    -- table before restoreSave applies it and before gameplay resumes.
    raw.options=game.options
    game:restoreSave(raw,nil,{freshBoot=true})
  else
    if isNew then require('src.core.Game2').anchorNewGameClock(raw) end
    game:continueGame(raw)
    assert(game.phase~='error',game.status or 'Could not enter destination world')
  end
end
function A.newSave(game,version,shared)
  local gen=A.generation(version)
  if gen==1 then return require('src.core.SaveData').newGame(game:bootConfig()) end
  if gen==2 then return require('src.core.gen2.Save').newGame({playerName=shared.name,trainerId=shared.trainerId,
    gender=(shared.gender==1 or shared.gender=='female') and 'female' or 'male'}) end
end
return A
