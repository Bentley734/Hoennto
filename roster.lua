-- Cartridge-neutral collection. Native representations are retained per
-- generation; unsupported records and capacity overflow remain in reserve.
return function(C, getGame)
local R={}
local function key(s)
  return tostring(s or ''):upper():gsub('♀','F'):gsub('♂','M'):gsub('[^%w]','')
end
R.key=key
local function data() local g=getGame();return g and g.data or require('src.core.Data') end
-- Companion mods may replace these resolvers through mod.exports.transfer.
-- Resolve from live registries, never from a fixed national-dex ceiling.
function R.name(kind,id,gen)
  if gen==3 then
    local ok,name=pcall(function()
      if kind=='species' then return require('src.core.game3.pokemon').keyName(id) end
      if kind=='moves' then return require('src.core.game3.pokemon').moveName(id) end
      return require('src.core.game3.items_data').displayName(id)
    end)
    return ok and name or ('UNKNOWN_G3_'..kind..'_'..tostring(id))
  end
  local row=(data()[kind=='species' and 'pokemon' or kind] or {})[id]
  return row and (row.id or id) or tostring(id)
end
function R.resolve(kind,name,gen)
  if gen==3 then
    if kind=='species' then return require('src.core.game3.pokemon').speciesFromName(name) end
    if kind=='moves' then return require('src.mods.Gen3Compat').moveId(name) end
    return require('src.core.game3.items_data').toNumericId(name)
  end
  local rows=data()[kind=='species' and 'pokemon' or kind] or {}
  for id,row in pairs(rows) do
    if type(row)=='table' and (key(id)==key(name) or key(row.id)==key(name) or key(row.name)==key(name)) then return id end
  end
end
local function each(raw,fn)
  for _,m in ipairs(raw.party or {}) do fn(m,true) end
  if C.generation(raw.version)==3 then
    for b,box in ipairs(raw.storage and raw.storage.boxes or {}) do
      for slot=1,30 do local m=box.mons and box.mons[slot];if m then fn(m,false,b,slot) end end
    end
  else
    for b,box in ipairs(raw.boxes or {raw.box or {}}) do for s,m in ipairs(box) do fn(m,false,b,s) end end
  end
end
function R.capture(raw,state)
  local gen=C.generation(raw.version)
  local collection=state.collection or {nextId=0,records={},dex={seen={},owned={}}}
  local existing={};for _,r in ipairs(collection.records) do existing[r.id]=r end
  local seen,live={},{}
  each(raw,function(mon,party,b,s)
    local id=mon._hoenntoId
    if not id or seen[id] then collection.nextId=collection.nextId+1;id=collection.nextId;mon._hoenntoId=id end
    seen[id]=true
    local record=existing[id] or {id=id,forms={}}
    record.forms[tostring(gen)]=C.copy(mon)
    record.mon=C.copy(mon);record.version=raw.version;record.party=party;record.box=b;record.slot=s
    if gen==3 then record.shiny=require('src.core.game3.pokemon').isShiny(mon) else record.shiny=mon.shiny end
    record.species=R.name('species',mon.species,gen)
    record.moves={}
    for i,m in ipairs(mon.moves or {}) do
      local n=type(m)=='table' and (m.id or m.moveId) or m
      if n and n~=0 then record.moves[i]=R.name('moves',n,gen) end
    end
    local item=mon.item or mon.heldItem
    record.item=item and item~=0 and R.name('items',item,gen) or nil
    live[#live+1]=record
  end)
  -- Missing projected IDs were released/traded away. Missing reserve IDs
  -- were never playable here and must survive every subsequent save.
  local projected=state.projected and state.projected[raw.version] or {}
  for _,r in ipairs(collection.records) do if not seen[r.id] and not projected[tostring(r.id)] then live[#live+1]=r end end
  collection.records=live
  local dex=gen==3 and raw.dex or raw.pokedex
  for _,side in ipairs({'seen','owned'}) do
    for id,has in pairs(dex and (dex[side] or side=='owned' and dex.caught) or {}) do
      if has then collection.dex[side][R.name('species',tonumber(id) or id,gen)]=true end
    end
  end
  state.collection=collection
  state.projected=state.projected or {}
  local ids={};for id in pairs(seen) do ids[tostring(id)]=true end
  state.projected[raw.version]=ids
end
local pairsOf={atk='attack',def='defense',spe='speed',spa='special',spd='special',hp='hp'}
local function nativeStatus(src,gen)
  local st=src.status or src.status1
  local aliases={SLP='sleep',PSN='poison',BRN='burn',FRZ='freeze',PAR='paralyze',PRZ='paralyze',TOX='toxic'}
  if type(st)=='number' then
    if st%8>0 then st='sleep'
    elseif math.floor(st/128)%2==1 then st='toxic'
    elseif math.floor(st/64)%2==1 then st='paralyze'
    elseif math.floor(st/32)%2==1 then st='freeze'
    elseif math.floor(st/16)%2==1 then st='burn'
    elseif math.floor(st/8)%2==1 then st='poison' else st=nil end
  elseif type(st)=='string' then st=aliases[st:upper()] or st:lower() end
  if gen==2 then return st end
  if gen==1 then return ({sleep='SLP',poison='PSN',toxic='PSN',burn='BRN',freeze='FRZ',paralyze='PAR'})[st] end
  return ({sleep=math.max(1,math.min(7,src.sleepTurns or src.sleep or 1)),poison=8,burn=16,freeze=32,paralyze=64,toxic=128})[st] or 0
end
function R.convert(record,target)
  local src=record.mon;local from=C.generation(record.version);local gen=C.generation(target)
  local species=R.resolve('species',record.species,gen)
  if not species then return nil,'species' end
  if gen==1 and (src.isEgg or src.egg) then return nil,'egg' end
  local moves={}
  for i,name in ipairs(record.moves) do
    moves[i]=R.resolve('moves',name,gen)
    if not moves[i] then return nil,'move' end
  end
  -- Letters belong to their native story. Reserve their carrier rather than
  -- reinterpreting incompatible mail/item indices in another generation.
  if from~=gen and (src.mail or src.mailIndex and src.mailIndex~=255) then return nil,'mail' end
  local item=record.item and R.resolve('items',record.item,gen)
  if record.item and (gen==1 or not item) then return nil,'item' end
  if from==gen then
    local m=C.copy(src);m.species=species;m.item=item;m.heldItem=item
    if gen==3 then m.moves=moves
    else for i,id in ipairs(moves) do m.moves[i].id=id end end
    return m
  end
  local m=C.copy(record.forms[tostring(gen)] or {})
  m._hoenntoId=record.id;m.species=species;m.level=src.level;m.nickname=src.nickname
  m.otId=src.otId;m.otName=src.otName or src.ot;m.ot=m.otName
  m.status=nativeStatus(src,gen);m.sleepTurns=src.sleepTurns or src.sleep
  m.sleep=m.sleepTurns;m.isEgg=src.isEgg or src.egg;m.item=item;m.heldItem=item
  m.happiness=src.happiness or src.friendship or m.happiness or 70;m.friendship=m.happiness
  if gen==3 then
    m.exp=src.experience or src.exp;m.moves=moves;m.pp={};m.ivs=m.ivs or {};m.evs=m.evs or {}
    for k,v in pairs(pairsOf) do
      if m.ivs[k]==nil then m.ivs[k]=math.min(31,(src.dvs and src.dvs[v] or 0)*2) end
      if m.evs[k]==nil then m.evs[k]=0 end
    end
    m.otSecretId=m.otSecretId or src.otSecretId or 0
    if not m.personality then
      local B=require('bit');local low=(record.id*40503)%65536
      local high=B.bxor(m.otId or 0,m.otSecretId,low,record.shiny and 0 or 256)
      m.personality=high*65536+low
    end
    m.speciesNumbering='internal';m.name=require('src.core.game3.pokemon').name(species)
    m.ppBonusesPacked=0
    for i,mv in ipairs(src.moves or {}) do
      m.pp[i]=type(mv)=='table' and mv.pp or src.pp and src.pp[i] or 0
      local ups=type(mv)=='table' and mv.ppUps or math.floor((src.ppBonusesPacked or 0)/4^(i-1))%4
      m.ppBonusesPacked=m.ppBonusesPacked+(ups or 0)*4^(i-1)
    end
    require('src.core.game3.pokemon').applyStats(m)
  else
    m.dvs=m.dvs or {};m.statExp=m.statExp or {}
    for k,v in pairs(pairsOf) do
      if m.dvs[v]==nil then m.dvs[v]=math.floor((src.ivs and src.ivs[k] or 0)/2) end
      if m.statExp[v]==nil then m.statExp[v]=0 end
    end
    m.moves={}
    for i,id in ipairs(moves) do
      local old=src.moves[i];m.moves[i]={id=id,pp=type(old)=='table' and old.pp or src.pp and src.pp[i] or 0,
        ppUps=type(old)=='table' and old.ppUps or math.floor((src.ppBonusesPacked or 0)/4^(i-1))%4}
    end
    local def=data().pokemon[species]
    if gen==2 and record.shiny and not record.forms['2'] then m.dvs.attack=2;m.dvs.defense=10;m.dvs.speed=10;m.dvs.special=10 end
    if gen==1 then m.exp=src.exp or src.experience;m.stats=require('src.pokemon.Stats').calc(def,m.level,m.dvs,m.statExp)
    else m.experience=src.exp or src.experience;m.stats=require('src.battle.gen2.Mon').stats(def.baseStats,m.dvs,m.level,m.statExp);m.types=def.types;m.name=def.name;m.shiny=require('src.battle.gen2.Mon').vanillaShiny(m.dvs);m.gender=require('src.battle.gen2.Mon').vanillaGender(def,m.dvs) end
    m.maxHp=m.stats.hp
  end
  local oldMax=src.maxHp or src.stats and src.stats.hp or src.hp or 1
  m.hp=math.max(0,math.min(m.maxHp,math.ceil((src.hp or oldMax)*m.maxHp/math.max(1,oldMax))))
  return m
end
function R.project(raw,state)
  if not state.collection then return end
  local gen=C.generation(raw.version);local count,cap=gen==1 and 12 or 14,gen==3 and 30 or 20
  local metadata=raw.storage and raw.storage.boxes or {}
  if gen==3 and state.shared and C.generation(state.shared.sourceVersion)==3 then metadata=state.shared.storage and state.shared.storage.boxes or metadata end
  local boxes={};for b=1,count do
    local old=metadata[b] or {}
    boxes[b]=gen==3 and {name=old.name or 'BOX '..b,wallpaper=old.wallpaper or 0,mons={}} or {}
  end
  local party,ids,reserve={}, {},0
  local slot=0
  for _,r in ipairs(state.collection.records) do
    local m=R.convert(r,raw.version)
    if m then
      if r.party and #party<6 then party[#party+1]=m
      else
        local b,s=r.box,r.slot
        local box=b and boxes[b] and (gen==3 and boxes[b].mons or boxes[b])
        if not (gen==3 and box and s and s<=cap and not box[s]) then
          box=nil
          while slot<count*cap do
            slot=slot+1;b=math.floor((slot-1)/cap)+1;s=(slot-1)%cap+1
            local candidate=gen==3 and boxes[b].mons or boxes[b]
            if not candidate[s] then box=candidate;break end
          end
        end
        if box then box[s]=m else m=nil end
      end
    end
    if m then ids[tostring(r.id)]=true else reserve=reserve+1 end
  end
  local hadParty=false;for _,r in ipairs(state.collection.records) do if r.party then hadParty=true end end
  assert(not hadParty or #party>0,'No party Pokemon can travel here. Choose a compatible party without unsupported moves/items first.')
  raw.party=party
  if gen==3 then raw.storage=raw.storage or {};raw.storage.boxes=boxes;raw.storage.currentBox=math.min(count,raw.storage.currentBox or 1)
  else raw.boxes=boxes;raw.box=nil;raw.currentBox=1 end
  local shared=state.shared or {}
  if gen==3 then raw.name=shared.name;raw.trainerId=shared.trainerId;raw.secretId=shared.secretId or raw.secretId;raw.gender=(shared.gender==1 or shared.gender=='female') and 1 or 0
  else raw.player=raw.player or {};raw.player.name=shared.name;raw.player.id=shared.trainerId;raw.player.gender=(shared.gender==1 or shared.gender=='female') and 'female' or 'male' end
  local dex=gen==3 and raw.dex or raw.pokedex
  dex=dex or {};dex.seen={};dex.owned={};dex.caught={}
  for _,side in ipairs({'seen','owned'}) do for name in pairs(state.collection.dex[side]) do
    local id=R.resolve('species',name,gen);if id then dex[side][id]=true;if side=='owned' then dex.caught[id]=true end end
  end end
  if gen==3 then raw.dex=dex else raw.pokedex=dex end
  state.projected=state.projected or {};state.projected[raw.version]=ids;state.reserveCount=reserve
  raw.modData=raw.modData or {};raw.modData[C.KEY]=C.copy(state)
end
return R
end
