-- Cartridge travel lives entirely in this mod. The host keeps its Game table;
-- only its live native runtime/profile is rebuilt between whole updates.
return function(mod)
  -- Gen 1's mod facade resolves an evictable module singleton. Keep the
  -- actual owner from game.ready, which travel rebuilds in place.
  local liveGame
  local function getGame() return liveGame or mod.game end
  local function module(name)
    return assert(load(assert(mod:read(name)), '@' .. mod.path .. '/' .. name))()
  end
  -- Protect flat live options on stock hosts as well as patched hosts.
  module('session_options.lua')(function() local game=getGame();return game and game.session end)
  local MountLifecycle = module('mount_lifecycle.lua')
  local Campaign = module('campaign.lua')
  local Adapter=module('runtime.lua')
  Campaign.runtime=Adapter
  Campaign.roster=module('roster.lua')(Campaign,getGame)
  local Bridge = module('travel.lua')(Campaign, mod)
  local Transition = module('transition.lua')
  local pending, pendingReset
  local TravelMenu=module('travel_menu.lua')(Campaign,Bridge,function(target)pending=target end)
  local function notice(game, message) Bridge.notice(game, message) end

  local function remount(game, payload, host)
    local GV = require('src.core.GameVersion')
    local SD = require('src.core.SaveData')
    GV.set(payload.target)
    Bridge.selectSlot(payload)
    local Fs = require('src.import.CacheFs')
    Fs.prefix = GV.cachePrefix()
    Fs.mountVersion(payload.target)
    -- Keep the exact object referenced by main.lua. All new methods and
    -- FixedStep callbacks bind to this same object, so the app needs no patch.
    MountLifecycle.load(function()
    Adapter.fresh(payload.target,game)
    game.returnToLauncher, game.onExit = host.returnToLauncher, host.onExit
    game.speedOverride = host.speedOverride
    game._hoenntoTransition = host.transition
    -- The checkpoint already contains the destination save. Native load
    -- reads it twice for boot/continue even though travel immediately enters
    -- the field; avoid parsing the same large campaign from disk again.
    payload.arrivalSave = Campaign.restore(payload.state, payload.target)
    local nativeLoad = SD.load
    SD.load = function() return payload.arrivalSave end
    local loaded, loadError = pcall(game.load, game, { onExit = host.onExit })
    SD.load = nativeLoad -- restore even if a destination mod fails to load
    if not loaded then error(loadError) end
    end)
    Bridge.resume(game, payload)
  end

  local function clock()
    return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
  end
  local function travel(game, target)
    local started=clock()
    local trip=(game._kantoHoennTrip or 0)+1
    local ok, payload, err = pcall(Bridge.prepare, game, target)
    if not ok or not payload then notice(game, ok and err or payload); return end
    local savedAt=clock()
    local host = { returnToLauncher = game.returnToLauncher,
      onExit = game.onExit, speedOverride = game.speedOverride,
      transition = game._hoenntoTransition }
    local Lifecycle = require('src.core.SessionLifecycle')
    Adapter.endGame(game)
    -- Native mount eviction drops the audio module but not its worker.
    -- Join it while it is still the sole owner of the fixed named channels.
    MountLifecycle.stopAudio()
    Lifecycle.endMountedSession(payload.source)
    Adapter.evict(payload.source)
    local releasedAt=clock()
    local arrived, failure = pcall(remount, game, payload, host)
    if arrived then
      game._kantoHoennTrip=trip
      game._kantoHoennTiming={save=savedAt-started,release=releasedAt-savedAt,load=clock()-releasedAt}
      local t=game._kantoHoennTiming
      print(string.format("[Hoennto] Switch %d %s -> %s: save %.3fs, release %.3fs, load %.3fs, Lua heap %.1f MB",trip,payload.source,target,t.save,t.release,t.load,collectgarbage("count")/1024))
    end
    if not arrived then
      -- Both positions and the complete shared roster are in the source
      -- checkpoint before the first runtime is released.
      Adapter.endGame(game)
      MountLifecycle.stopAudio()
      Lifecycle.endMountedSession(target)
      Adapter.evict(target)
      payload.target = payload.source
      local restored, restoreError = pcall(remount, game, payload, host)
      if restored then notice(game, 'Travel canceled: ' .. tostring(failure))
      else
        print('[Hoennto] Travel failed: ' .. tostring(failure))
        print('[Hoennto] Restore failed: ' .. tostring(restoreError))
        if host.returnToLauncher then host.returnToLauncher() end
      end
    end
  end

  mod.events:on('save.writing', function(ev)
    local game = getGame()
    if game and ev.save then Bridge.prepareSave(game, ev.save) end
  end, -100000)
  mod.events:on('save.loading',function(ev)
    local raw=ev.raw;local state=raw and raw.modData and raw.modData[Campaign.KEY]
    if state and state.collection then Campaign.roster.project(raw,state) end
  end,-100000)

  mod.events:on('game.ready', function(ev)
    local game = ev.game
    if not game then return end
    liveGame=game
    Adapter.bind(game)
    -- Wrap the complete update, rather than switching inside a fixed step,
    -- menu callback, VM instruction or renderer invocation.
    local savedState=game.session and game.session.modData and game.session.modData[Campaign.KEY]
    savedState=Bridge.savedWildOptions(game,savedState)
    if savedState and game.session then
      Bridge.applyWildOptions(game,savedState,game.session.version)
      Adapter.bindOptions(game)
    end
    local nativeUpdate, nativeDraw = game.update, game.draw
    for _,name in ipairs({'keypressed','keyreleased','gamepadpressed','gamepadreleased',
        'mousepressed','mousemoved','mousereleased','touchpressed','touchmoved',
        'touchreleased','gamepadaxis','wheelmoved','joystickpressed','joystickreleased','joystickaxis','joystickhat','textinput'}) do
      local native=game[name]
      if native then game[name]=function(self,...)
        if self._hoenntoMenu then
          if name=='touchpressed' or name=='mousepressed' then
            local a,b,c=...
            local x,y=name=='touchpressed' and b or a,name=='touchpressed' and c or b
            if TravelMenu.pointer(self,x,y) then return end
          end
          if name=='mousemoved' and TravelMenu.hover then
            local x,y=...
            if TravelMenu.hover(self,x,y) then return end
          end
          if name=='wheelmoved' and TravelMenu.wheel then
            local _,dy=...
            return TravelMenu.wheel(self,dy)
          end
          local input=self.input
          if input and input[name] then return input[name](input,...) end
          if name:match('^touch') and self.touchControls and self.touchControls[name] then return self.touchControls[name](self.touchControls,...) end
          return
        end
        if not self._hoenntoTransition then return native(self,...) end
      end end
    end
    if nativeDraw then
      game.draw=function(self,...)
        local state=self._hoenntoTransition
        if not state or state.phase~='loading' then nativeDraw(self,...) end
        if state then Transition.draw(state) end
        TravelMenu.draw(self)
      end
    end
    game.update = function(self, dt)
      if self._hoenntoMenu then TravelMenu.update(self);return end
      if self._hoenntoTransition then
        if self.generation==3 and self._hoenntoTransition.phase=='in' then
          -- Advance only the native arrival veil while gameplay stays paused,
          -- so it does not add a second black wait after our fade completes.
          local ok,Fade=pcall(require,'src.ui.game3.fade')
          if ok and Fade.MODE and Fade.mode==Fade.MODE.FROM_BLACK
              and not Fade.doneCb and Fade.tick then Fade.tick(dt) end
        end
        local depart=Transition.tick(self,dt)
        if depart then
          local target=self._hoenntoTransition.target
          local ok,err=Transition.withRefresh(self,function()travel(self,target)end)
          Transition.finish(self)
          if not ok then notice(self,'Travel canceled: '..tostring(err)) end
        end
        return -- hold input/gameplay through both fades and the native handoff
      end
      if self._hoenntoNotice then
        self._hoenntoMenu={mode='notice',text=self._hoenntoNotice..'\n\nA / B: close'}
        self._hoenntoNotice=nil;self.input:reset();return
      end
      if pendingReset then
        local reset=pendingReset;pendingReset=nil
        if self.session.version~=reset.source then notice(self,"Region changed. Reset canceled.");return end
        local ok,result,message=pcall(Bridge.resetPeer,self,reset.target)
        notice(self,ok and message or result)
        return
      end
      if pending then
        local target=pending
        pending=nil
        Transition.begin(self,target)
        return
      end
      Bridge.tick(self)
      return nativeUpdate(self, dt)
    end
    local saveMethod=game.generation==3 and 'saveGame' or 'writeSave'
    local actualSave=game[saveMethod]
    game[saveMethod] = function(self, ...)
      local written = actualSave(self, ...)
      if written == true then Bridge.afterSave(self, self.save) end
      return written
    end
  end, -100000)

  mod.hooks:wrap('ui.start_menu.items', function(next, game, items)
    items = next(game, items)
    local session = game and game.session
    if not session or not Campaign.validVersion(session.version) then return items end
    if game.generation==3 then
      if game.phase~='field' then return items end
      local Menu=require('src.ui.game3.start_menu')
      if Menu._kind~='normal' or Menu._tutorial then return items end
    elseif game.generation==2 and game.phase~='play' then return items end
    local row = { id = 'kanto_hoenn_travel',
      label = 'TRAVEL',
      onSelect = function()
        if game.generation==3 then require('src.ui.game3.start_menu').close(true)
        elseif game.generation==2 then game.stack:pop() end
        TravelMenu.open(game)
      end }
    for i, e in ipairs(items) do
      if e.id == row.id then return items end
      if e.id == 'option' or e.id == 'options' then table.insert(items, i, row); return items end
    end
    table.insert(items, math.max(1, #items), row)
    return items
  end)
  if mod.options and mod.options.define then
    local choices={{'AUTO','auto'}}
    for _,v in ipairs(Campaign.ORDER) do choices[#choices+1]={v:upper(),v} end
    mod.options:define({
      {key='kanto_game',label='KANTO GAME',type='choice',default='auto',
        choices={{'AUTO','auto'},{'FIRERED','firered'},{'LEAFGREEN','leafgreen'}}},
      {key='reset_peer',label='ERASE OTHER REGION SAVE',type='toggle',default=false},
      {key='campaign_overview',label='CAMPAIGN OVERVIEW',type='toggle',default=false},
      {key='destination_game',label='RESET DESTINATION',type='choice',default='auto',choices=choices},
    })
    module('reset_menu.lua')(mod,function(source,target)
      pendingReset={source=source,target=target}
    end,Bridge.destination,function(game)
      Adapter.closeMenus(game)
      TravelMenu.overview(game)
    end)
  end
  mod.exports.syncWildFollowersOptions=function()
    return Bridge.syncWildOptions(getGame())
  end
  mod.exports.transfer=Campaign.roster
  mod.exports.version = '0.2.3'
end
