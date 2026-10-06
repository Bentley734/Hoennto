-- Kanto/Hoenn campaign data. Pure functions; no ROM, filesystem or live objects.
local C = { KEY = "kanto_hoenn", VERSION = 2 }
local SHARED = { "name", "gender", "trainerId", "secretId", "party", "mail", "move_overlay", "playTime" }
local sharedKeys={}
for _,key in ipairs(SHARED) do sharedKeys[key]=true end
function C.copy(value, ancestors)
  if type(value) ~= "table" then return value end
  ancestors = ancestors or {}
  assert(not ancestors[value], "cyclic campaign data")
  ancestors[value] = true
  local out = {}
  for k, v in pairs(value) do out[k] = C.copy(v, ancestors) end
  ancestors[value] = nil
  return out
end
function C.isKanto(v) return v == "firered" or v == "leafgreen" end
 C.ORDER={'red','blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald'}
function C.generation(v)
  if v=='red' or v=='blue' or v=='yellow' then return 1 end
  if v=='gold' or v=='silver' or v=='crystal' then return 2 end
  return 3
end
function C.validVersion(v) for _,id in ipairs(C.ORDER) do if v==id then return true end end return false end
-- Version-1 campaigns remain compatible; old saves infer their Kanto game.
function C.kantoVersion(state)
  if type(state) ~= "table" then return nil end
  if C.isKanto(state.kantoVersion) then return state.kantoVersion end
  if C.isKanto(state.active) then return state.active end
  for _, v in ipairs({"firered", "leafgreen"}) do
    if (state.regions and state.regions[v]) or (state.slots and state.slots[v]) then return v end
  end
end
function C.state(raw)
  local s = raw and raw.modData and raw.modData[C.KEY]
  if type(s) == "table" then
    assert(s.version == 1 or s.version == C.VERSION, "unsupported campaign save version")
    assert(type(s.regions) == "table" and type(s.slots) == "table", "invalid campaign save")
    local out=C.copy(s);out.version=C.VERSION;return out
  end
  return { version = C.VERSION, revision = 0, regions = {}, slots = {} }
end
function C.snapshot(raw)
  local out = {}
  for k, v in pairs(raw) do
    if k == "modData" then
      out.modData = {}
      for id, bucket in pairs(v or {}) do
        if id ~= C.KEY then out.modData[id] = C.copy(bucket) end
      end
    elseif k=='boxes' or k=='box' or k=='pokedex' then
      -- Canonical collection owns these; native snapshots keep story only.
      if not C.roster then out[k]=C.copy(v) end
    elseif k == "storage" or k == "dex" then
      local bucket={}
      for key,value in pairs(v or {}) do
        local shared = k=="storage" and (key=="boxes" or key=="currentBox")
          or k=="dex" and (key=="seen" or key=="owned" or key=="caught")
        if not shared then bucket[key]=C.copy(value) end
      end
      out[k]=bucket
    elseif k ~= "options" and not sharedKeys[k] then out[k] = C.copy(v) end
  end
  out.modData = out.modData or {}
  -- Shared data lives only once in the campaign, rather than in every region.
  for _, k in ipairs(SHARED) do out[k] = nil end
  if out.storage then out.storage.boxes, out.storage.currentBox = nil, nil end
  if out.dex then out.dex.seen, out.dex.owned, out.dex.caught = nil, nil, nil end
  return out
end
function C.shared(raw)
  local out = {}
  out.sourceVersion=raw.version
  for _, k in ipairs(SHARED) do out[k] = C.copy(raw[k]) end
  if C.generation(raw.version)<3 then
    out.name=raw.player and raw.player.name
    out.trainerId=raw.player and raw.player.id
    out.gender=raw.player and raw.player.gender
  end
  out.storage = raw.storage and {
    boxes = C.copy(raw.storage.boxes), currentBox = raw.storage.currentBox,
  } or nil
  out.dex = {}
  for _, k in ipairs({"seen", "owned", "caught"}) do
    out.dex[k] = C.copy(raw.dex and raw.dex[k] or {})
  end
  return out
end
function C.apply(raw, shared)
  if C.generation(raw.version)~=C.generation(shared.sourceVersion or raw.version) then
    if C.generation(raw.version)==3 then
      raw.name,raw.trainerId=shared.name,shared.trainerId
      raw.gender=(shared.gender=='female' or shared.gender==1) and 1 or 0
    else
      raw.player=raw.player or {}
      raw.player.name,raw.player.id=shared.name,shared.trainerId
      raw.player.gender=(shared.gender=='female' or shared.gender==1) and 'female' or 'male'
    end
    return raw
  end
  for _, k in ipairs(SHARED) do raw[k] = C.copy(shared[k]) end
  if shared.storage then
    raw.storage = raw.storage or {}
    raw.storage.boxes = C.copy(shared.storage.boxes)
    raw.storage.currentBox = shared.storage.currentBox
  end
  raw.dex = raw.dex or {}
  for _, k in ipairs({"seen", "owned", "caught"}) do raw.dex[k] = C.copy(shared.dex[k]) end
  return raw
end
-- Regional snapshots are immutable once captured. Replace only the active
-- snapshot and shared roster instead of cloning the entire previous roster.
function C.captureState(state)
  local out={}
  for key,value in pairs(state) do
    if key=="regions" then
      out.regions={}
      for version,snapshot in pairs(value) do out.regions[version]=snapshot end
    elseif key~="shared" then out[key]=C.copy(value) end
  end
  return out
end
function C.capture(raw, state)
  state = state or C.state(raw)
  assert(C.validVersion(raw.version), "unsupported campaign region")
  state.revision = (state.revision or 0) + 1
  state.active = raw.version
  if C.isKanto(raw.version) then state.kantoVersion = raw.version end
  local previous=state.shared
  state.shared = C.shared(raw)
  if C.generation(raw.version)<3 and previous then state.shared.secretId=previous.secretId end
  if C.roster then C.roster.capture(raw,state) end
  state.regions[raw.version] = C.snapshot(raw)
  raw.modData = raw.modData or {}
  raw.modData[C.KEY] = state
  return state
end
function C.restore(state, version)
  local snapshot = state.regions[version]
  if not snapshot then return nil end
  local raw = C.copy(snapshot)
  if not state.collection then C.apply(raw,state.shared) end
  raw.modData[C.KEY] = C.copy(state)
  return raw
end
return C
