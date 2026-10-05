-- Cartridge travel lives entirely in this mod. The host keeps its Game table;
-- only its live native runtime/profile is rebuilt between whole updates.
return function(mod)
  local function module(name)
    return assert(load(assert(mod:read(name)), '@' .. mod.path .. '/' .. name))()
  end
  -- Protect flat live options on stock hosts as well as patched hosts.
  module('session_options.lua')(function() return mod.game and mod.game.session end)
  local MountLifecycle = module('mount_lifecycle.lua')
  local Campaign = module('campaign.lua')
  local Bridge = module('travel.lua')(Campaign, mod)
  local Presentation = module('presentation.lua')(Campaign, Bridge)
  local pending, pendingReset, loading
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
    local fresh = require('src.core.Game3').new()
    for key in pairs(game) do game[key] = nil end
    setmetatable(game, getmetatable(fresh))
    for key, value in pairs(fresh) do game[key] = value end
    game.returnToLauncher, game.onExit = host.returnToLauncher, host.onExit
    game.speedOverride = host.speedOverride
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
      onExit = game.onExit, speedOverride = game.speedOverride }
    local Lifecycle = require('src.core.SessionLifecycle')
    Lifecycle.endGameSession(game)
    -- Native mount eviction drops the audio module but not its worker.
    -- Join it while it is still the sole owner of the fixed named channels.
    MountLifecycle.stopAudio()
    Lifecycle.endMountedSession(payload.source)
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
      Lifecycle.endGameSession(game)
      MountLifecycle.stopAudio()
      Lifecycle.endMountedSession(target)
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
    local game = mod.game
    if game and ev.save then Bridge.prepareSave(game, ev.save) end
  end, -100000)

  mod.events:on('game.ready', function(ev)
    local game = ev.game
    if not game or game.generation ~= 3 then return end
    -- Wrap the complete update, rather than switching inside a fixed step,
    -- menu callback, VM instruction or renderer invocation.
    local savedState=game.session and game.session.modData and game.session.modData[Campaign.KEY]
    savedState=Bridge.savedWildOptions(game,savedState)
    if savedState and game.session then
      Bridge.applyWildOptions(game,savedState,game.session.version)
      require('src.core.game3.options').bind(game.session,game.options)
    end
    local nativeUpdate, nativeSave = game.update, game.saveGame
    game.update = function(self, dt)
      if pendingReset then
        local reset=pendingReset;pendingReset=nil
        if self.session.version~=reset.source then notice(self,"Region changed. Reset canceled.");return end
        local ok,result,message=pcall(Bridge.resetPeer,self,reset.target)
        notice(self,ok and message or result)
        return
      end
      if pending then
        if not loading then
          loading=0
          Presentation.loading(pending)
          return
        end
        loading=loading+math.min(dt or 0,0.1)
        if loading<0.2 then return end
        local target=pending
        pending,loading=nil,nil
        Presentation.closeLoading()
        travel(self,target)
        return -- no source callback may run after the profile handoff
      end
      Bridge.tick(self)
      return nativeUpdate(self, dt)
    end
    game.saveGame = function(self, ...)
      local written = nativeSave(self, ...)
      if written == true then Bridge.afterSave(self, self.save) end
      return written
    end
  end, -100000)

  mod.hooks:wrap('ui.start_menu.items', function(next, game, items)
    items = next(game, items)
    local session = game and game.session
    if not session or game.phase ~= 'field' then return items end
    local Menu = require('src.ui.game3.start_menu')
    if Menu._kind ~= 'normal' or Menu._tutorial then return items end
    local target = Bridge.destination(game)
    if not target then return items end
    local row = { id = 'kanto_hoenn_travel',
      label = target == 'emerald' and 'HOENN' or 'KANTO',
      onSelect = function()
        Menu.close(true)
        Presentation.request(game,target,function(destination) pending=destination end)
      end }
    for i, e in ipairs(items) do
      if e.id == row.id then return items end
      if e.id == 'option' or e.id == 'options' then table.insert(items, i, row); return items end
    end
    table.insert(items, math.max(1, #items), row)
    return items
  end)
  if mod.options and mod.options.define then
    mod.options:define({
      {key='kanto_game',label='KANTO GAME',type='choice',default='auto',
        choices={{'AUTO','auto'},{'FIRERED','firered'},{'LEAFGREEN','leafgreen'}}},
      {key='reset_peer',label='ERASE OTHER REGION SAVE',type='toggle',default=false},
      {key='campaign_overview',label='CAMPAIGN OVERVIEW',type='toggle',default=false},
    })
    module('reset_menu.lua')(mod,function(source,target)
      pendingReset={source=source,target=target}
    end,Bridge.destination,function(game)
      require('src.ui.game3.mod_manager').close()
      require('src.ui.game3.option_menu').close()
      require('src.ui.game3.start_menu').close(true)
      require('src.ui.game3.message').show(Presentation.overview(game))
    end)
  end
  mod.exports.syncWildFollowersOptions=function()
    return Bridge.syncWildOptions(mod.game)
  end
  mod.exports.version = '0.1.5'
end
