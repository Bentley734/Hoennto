-- Mod-owned cartridge handoff. Runs between updates, never inside a script.
return function(Campaign, mod)
local Bridge = { VERSION = 1 }
local function req(name) return require(name) end
local function label(v)
  local GV=req('src.core.GameVersion')
  local info=GV.info(v)
  return info and info.label or tostring(v)
end
-- Explicit selection applies in Hoenn. Leaving Kanto always goes to Emerald.
function Bridge.destination(game)
  local source = game and game.session and game.session.version
  local selected=mod.options and mod.options.get and mod.options:get('destination_game')
  if Campaign.validVersion(selected) and selected~=source then return selected end
  if Campaign.isKanto(source) then return "emerald" end
  if source~='emerald' then
    if not Campaign.validVersion(source) then return nil end
    for _,v in ipairs(Campaign.ORDER) do if v~=source and Bridge.available(v) then return v end end
    return source=='red' and 'blue' or 'red'
  end
  return Bridge.kantoDestination(game)
end
function Bridge.kantoDestination(game)
  local choice = mod.options and mod.options.get and mod.options:get("kanto_game")
  if Campaign.isKanto(choice) then return choice end
  if Campaign.isKanto(game.session.version) then return game.session.version end
  local state = game.session.modData and game.session.modData[Campaign.KEY]
  local linked = Campaign.kantoVersion(state)
  if linked then return linked end
  local Fs = req("src.import.CacheFs")
  local Contract = req("src.import.CacheContract")
  if Contract.isReady("firered", Fs) then return "firered" end
  if Contract.isReady("leafgreen", Fs) then return "leafgreen" end
  return "firered"
end
function Bridge.notice(game, message)
  print("[Hoennto] " .. tostring(message))
  if game and game.generation and game.generation<3 then game._hoenntoNotice=tostring(message);return end
  local ok, Hud = pcall(req, "src.ui.game3.hud")
  if ok and Hud.openMessage and game and game.phase == "field" then
    Hud.openMessage(game, tostring(message))
  end
end
function Bridge.available(target)
  if not Campaign.validVersion(target) then return false,'Invalid destination.' end
  local Fs = req("src.import.CacheFs")
  if not req("src.import.CacheContract").isReady(target, Fs) then
    return false, "Import " .. label(target) .. "'s ROM in the launcher first."
  end
  return true
end
-- Installed versions are shared by the launcher; per-game enablement and
-- manifest targets can still differ. Only roster/follower companions require
-- symmetry. Unrelated regional mods retain their normal enablement.
function Bridge.compatibility(game,target)
  local issues={}
  local SD=req('src.core.SaveData')
  local options=SD.loadOptions()
  local source=game.session.version
  local loader=game.mods
  local installed=loader and loader.mods or {}
  local loaded={}
  for _,entry in ipairs(loader and loader.loaded or {}) do
    if entry.manifest then loaded[entry.manifest.id]=true end
  end
  for id,entry in pairs(installed) do
    local manifest=entry.manifest or {}
    local text=(id..' '..(manifest.name or '')):lower():gsub('[^%w]','')
    local companion=text:find('1025dex',1,true) or text:find('wildfollowers',1,true)
    for _,tag in ipairs(manifest.tags or {}) do
      if tag=='species' or tag=='pokedex' then companion=true end
    end
    if companion then
      local a=SD.modEnabled(options,id,source)~=false
      local b=SD.modEnabled(options,id,target)~=false
      local Targets=req('src.mods.ModTargets')
      a=a and Targets.supports(manifest,source,Campaign.generation(source))
      b=b and Targets.supports(manifest,target,Campaign.generation(target))
      if a~=b then
        issues[#issues+1]=(manifest.name or id)..' must support and be enabled\nin both linked games.'
      elseif a and loader.loaded and not loaded[id] then
        issues[#issues+1]=(manifest.name or id)..' is not running here.\nResolve its launcher errors first.'
      end
    end
  end
  table.sort(issues)
  return issues
end
local function wildKey(key)
  return type(key)=="string" and (key:match("^wildsG3") or key:match("^wildsFr") or key:match("^wildsNative_"))
end
function Bridge.captureWildOptions(game, state)
  local values = {}
  for key,value in pairs(game.session and game.session.options or {}) do
    if wildKey(key) then values[key]=Campaign.copy(value) end
  end
  state.wildFollowersOptions=values
  if game.options then
    game.options.modOptions=game.options.modOptions or {}
    local buckets=game.options.modOptions
    buckets[Campaign.KEY]=buckets[Campaign.KEY] or {}
    buckets[Campaign.KEY].sharedWildFollowers=Campaign.copy(values)
    local loader=game.mods
    if loader then
      loader.modOptions=loader.modOptions or {}
      loader.modOptions[Campaign.KEY]=loader.modOptions[Campaign.KEY] or {}
      loader.modOptions[Campaign.KEY].sharedWildFollowers=Campaign.copy(values)
    end
  end
end
function Bridge.applyWildOptions(game, state, target)
  if type(state.wildFollowersOptions)~="table" then return end
  if Campaign.generation(target)~=3 then return end
  game.options.modOptions=game.options.modOptions or {}
  local buckets=game.options.modOptions
  buckets[Campaign.KEY]=buckets[Campaign.KEY] or {}
  buckets[Campaign.KEY].sharedWildFollowers=Campaign.copy(state.wildFollowersOptions)
  local loader=game.mods
  if loader then
    loader.modOptions=loader.modOptions or {}
    loader.modOptions[Campaign.KEY]=loader.modOptions[Campaign.KEY] or {}
    loader.modOptions[Campaign.KEY].sharedWildFollowers=Campaign.copy(state.wildFollowersOptions)
  end
  local Options=req("src.core.game3.options")
  local Profile=req("src.core.game3.profile")
  local block=Options.block(game.options,Profile.of(target).optionsBlock)
  for key in pairs(block) do if wildKey(key) then block[key]=nil end end
  for key,value in pairs(state.wildFollowersOptions) do
    if wildKey(key) then block[key]=Campaign.copy(value) end
  end
end
function Bridge.syncWildOptions(game)
  if not game or not game.session or not Campaign.validVersion(game.session.version) then return false end
  local state=game.session.modData and game.session.modData[Campaign.KEY] or {}
  Bridge.captureWildOptions(game,state)
  for _,target in ipairs(Campaign.ORDER) do
    if target~=game.session.version then Bridge.applyWildOptions(game,state,target) end
  end
  return req("src.core.SaveData").saveOptions(game.options)
end
function Bridge.savedWildOptions(game, state)
  local bucket=game.options and game.options.modOptions and game.options.modOptions[Campaign.KEY]
  if bucket and type(bucket.sharedWildFollowers)=="table" then
    local effective=Campaign.copy(state or {})
    effective.wildFollowersOptions=Campaign.copy(bucket.sharedWildFollowers)
    return effective
  end
  return state
end
function Bridge.resetPeer(game, target)
  if not game or not game.session or not Campaign.validVersion(target)
      or target~=Bridge.destination(game) then return false,"Invalid reset destination." end
  if not game:quickSaveAllowed() then return false,"Finish the current event before resetting." end
  local SD=req("src.core.SaveData")
  if SD.getCart and SD.getCart() then return false,"Launch the normal game to reset its linked region." end
  local current=game.session.modData and game.session.modData[Campaign.KEY]
  if not current or (not current.regions[target] and not current.slots[target]) then
    return false,"There is no linked "..label(target).." progress to erase."
  end
  if game:saveGame()~=true then return false,"Could not save here. Reset canceled." end
  local original=Campaign.state(game.save)
  local state=Campaign.copy(original);local slot=state.slots[target]
  state.regions[target],state.slots[target]=nil,nil
  game.session.modData[Campaign.KEY]=state
  -- Commit the removed snapshot before deleting its peer slot. afterSave can
  -- no longer recreate that peer; shared party/storage/dex remain untouched.
  if game:saveGame()~=true then
    game.session.modData[Campaign.KEY]=original
    if game.save and game.save.modData then game.save.modData[Campaign.KEY]=Campaign.copy(original) end
    return false,"Could not save the reset. The other region was not erased."
  end
  if slot then
    local ok,err=SD.deleteSlot(target,slot)
    if not ok then
      game.session.modData[Campaign.KEY]=original
      if game:saveGame()~=true then return false,"Reset could not remove the old slot or restore the link. Save before quitting." end
      return false,"Reset canceled: "..tostring(err)
    end
  end
  game.options=SD.loadOptions()
  Bridge.applyWildOptions(game,game.session.modData[Campaign.KEY],game.session.version)
  if Campaign.runtime then Campaign.runtime.bindOptions(game)
  else req("src.core.game3.options").bind(game.session,game.options) end
  -- Rotate the clean current save into its backup too; otherwise the source
  -- .bak could still carry an embedded copy of the erased regional story.
  if game:saveGame()~=true then
    return true,label(target).." story erased, but backup refresh failed. Save before quitting."
  end
  return true,label(target).." story erased. Your shared Pokemon and settings are kept."
end
function Bridge.prepareSave(game, raw)
  local s = game.session and game.session.modData and game.session.modData[Campaign.KEY]
  if not s then return end
  local state = Campaign.captureState(s)
  Bridge.captureWildOptions(game,state)
  state = Campaign.capture(raw, state)
  game.session.modData[Campaign.KEY] = state
end
function Bridge.afterSave(game, raw)
  local state = raw.modData and raw.modData[Campaign.KEY]
  if not state then return end
  local SD = req("src.core.SaveData")
  for v, slot in pairs(state.slots) do
    if v ~= raw.version then
      local peer = Campaign.restore(state, v)
      if peer then
        local ok, err = SD.writeSlot(v, slot, peer)
        if not ok then Bridge.notice(game, "Saved here, but the other region's save could not update: " .. tostring(err)) end
      end
    end
  end
end
function Bridge.prepare(game, target)
  if not game or not game.session or not Campaign.validVersion(target)
      or target == game.session.version then return nil, "Invalid destination." end
  if not game:quickSaveAllowed() then return nil, "Finish the current event before traveling." end
  local ok, err = Bridge.available(target)
  if not ok then return nil, err end
  local issues=Bridge.compatibility(game,target)
  if #issues>0 then return nil,table.concat(issues,' ') end
  local SD = req("src.core.SaveData")
  -- Cart scopes deliberately pin a runtime/save profile. The normal launcher
  -- games are the supported host for this dual-cartridge campaign.
  if SD.getCart and SD.getCart() then return nil, "Launch a normal supported game to travel." end
  -- Register the linked slots before the single source checkpoint. The
  -- native save below persists the live script store and captures all changes.
  local state = Campaign.state(game.save)
  state.travelGuideSeen=true
  local source = game.session.version
  if Campaign.isKanto(source) then state.kantoVersion=source
  elseif Campaign.isKanto(target) then state.kantoVersion=target end
  Bridge.captureWildOptions(game,state)
  if not state.slots[source] then
    state.slots[source] = SD.activeSlot(source) or SD.createSlot(source)
  end
  if not state.slots[target] then
    state.slots[target] = SD.createSlot(target)
    SD.renameSlot(target, state.slots[target], "Hoennto")
  end
  if not state.slots[source] or not state.slots[target] then return nil, "Could not create campaign save slots." end
  SD.setActiveSlot(source, state.slots[source])
  -- Slot registration updates installation options. Refresh before game Save
  -- can flush its older options table and erase those new registrations.
  game.options = SD.loadOptions()
  Bridge.applyWildOptions(game,state,source)
  Bridge.applyWildOptions(game,state,target)
  -- Selecting travel explicitly opts this campaign into the destination arm.
  -- Other mods keep their own per-game enablement and compatibility gates.
  SD.setModEnabled(game.options, Campaign.KEY, true, source)
  SD.setModEnabled(game.options, Campaign.KEY, true, target)
  if Campaign.runtime then Campaign.runtime.bindOptions(game)
  else req("src.core.game3.options").bind(game.session, game.options) end
  game.session.modData = game.session.modData or {}
  game.session.modData[Campaign.KEY] = state
  if game:saveGame() ~= true then return nil, "Could not save the campaign. Travel canceled." end
  state = Campaign.copy(game.save.modData[Campaign.KEY])
  return { source = source, target = target, state = state }
end
function Bridge.selectSlot(payload)
  return req("src.core.SaveData").setActiveSlot(payload.target, payload.state.slots[payload.target])
end
function Bridge.resume(game, payload)
  local state, version = payload.state, payload.target
  assert(Campaign.validVersion(version), "invalid travel version")
  Bridge.applyWildOptions(game,state,version)
  local raw = payload.arrivalSave or Campaign.restore(state, version)
  payload.arrivalSave = nil
  if Campaign.generation(version)<3 then
    local isNew=not raw
    raw=raw or Campaign.runtime.newSave(game,version,state.shared)
    if Campaign.roster then Campaign.roster.project(raw,state) else Campaign.apply(raw,state.shared) end
    raw.modData=raw.modData or {};raw.modData[Campaign.KEY]=Campaign.copy(state)
    Campaign.runtime.resume(game,raw,isNew)
    game._regionTravelAutosave=true
    Bridge.tick(game)
    return
  end
  local Schema = req("src.core.game3.save_schema_firered")
  local reason, session
  if raw then
    if Campaign.roster then Campaign.roster.project(raw,state) end
    session = Schema.fromSaveTable(raw)
    reason = "continue"
  else
    -- Run the genuine new-game flags, map reset and truck sequence. No story
    -- event, gym badge or progression variable is pre-completed.
    session = Schema.newGame({ version = version, name = state.shared.name,
      gender = state.shared.gender, trainerIdLower = state.shared.trainerId,
      engineOptions = game.options })
    raw = Schema.toSaveTable(session)
    Campaign.apply(raw, state.shared)
    if Campaign.roster then Campaign.roster.project(raw,state) end
    session = Schema.fromSaveTable(raw)
    reason = "new_game"
  end
  session.modData = session.modData or {}
  session.modData[Campaign.KEY] = Campaign.copy(state)
  -- Restore trainer aliases used by owner checks without changing OT data.
  session.id, session.playerId = session.trainerId, session.trainerId
  req("src.core.game3.options").bind(session, game.options)
  game:adoptSave(session, true)
  game._modSaveAdopted = true
  game.sessionStartedAt = os.time()
  local Mods = req("src.mods.Runtime")
  if reason == "new_game" and Mods.wants("save.created") then
    Mods.emit("save.created", { save = session })
  end
  game:_enterField(session, reason, {
    fieldCallback = reason == "new_game" and (version == "emerald" or version=='ruby' or version=='sapphire') and "truck" or nil,
  })
  if reason == "continue" and Mods.wants("save.loaded") then
    Mods.emit("save.loaded", { save = session, meta = session.meta })
  end
  -- Never save halfway through the uncompleted truck callback. Native New
  -- Game has no continue save there either. Save as soon as field control is
  -- safely returned; later visits can save immediately.
  game._regionTravelAutosave = true
  Bridge.tick(game)
end
function Bridge.tick(game)
  if not game._regionTravelAutosave or not game.session
      or tostring(game.session.map):match('INSIDE_OF_TRUCK$') or not game:quickSaveAllowed() then return end
  game._regionTravelAutosave = nil
  if game:saveGame() ~= true then
    Bridge.notice(game, "Travel arrived, but saving failed. Save before quitting.")
  end
end
return Bridge
end
