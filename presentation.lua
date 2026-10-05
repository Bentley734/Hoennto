-- Native field dialogue: no new renderer or replacement engine files.
return function(C, Bridge)
local P = {}
local names = {firered='FireRed', leafgreen='LeafGreen', emerald='Emerald'}
function P.label(version)
  return (version=='emerald' and 'Hoenn - ' or 'Kanto - ') .. (names[version] or '?')
end
function P.badges(raw, version)
  local count, first = 0, version=='emerald' and 0x867 or 0x820
  local flags = raw.flags or {}
  for i=0,7 do
    local value=flags[first+i]
    if value==nil then value=flags[tostring(first+i)] end
    if value==nil then value=flags[string.format('FLAG_BADGE%02d_GET',i+1)] end
    if value==true or (type(value)=='number' and value~=0) then count=count+1 end
  end
  return count
end
function P.location(raw)
  local map=tostring(raw.map or 'Unknown location')
  return (map:gsub('^FR_',''):gsub('^EM_',''):gsub('_',' '):lower():gsub('(%a)([%w]*)',function(a,b)return a:upper()..b end))
end
function P.overview(game)
  local state=game.session.modData and game.session.modData[C.KEY] or {}
  local pages={'HOENNTO CAMPAIGN\nKanto return: '..names[Bridge.kantoDestination(game)]}
  for _,version in ipairs({'firered','leafgreen','emerald'}) do
    local raw=state.regions and state.regions[version]
    local current=game.session.version==version
    if current then raw=game.session end
    local text=P.label(version)..(current and ' (current)' or '')
    if raw then
      text=text..'\nBadges: '..P.badges(raw,version)..'/8\\p'..(current and 'Current location:\n' or 'Last saved location:\n')..P.location(raw)
    else text=text..'\nStory not started.' end
    pages[#pages+1]=text
  end
  pages[#pages+1]='Shared: trainer, Pokemon\nand Pokedex records.\\pRegional: bags, money,\nbadges and stories.'
  return table.concat(pages,'\\p')
end
local function message(text, done)
  require('src.ui.game3.message').show(text,{done=done})
end
function P.request(game,target,queue)
  if not game:quickSaveAllowed() then Bridge.notice(game,'Finish the current event before traveling.');return end
  local ready,reason=Bridge.available(target)
  if not ready then Bridge.notice(game,reason);return end
  local issues=Bridge.compatibility(game,target)
  if #issues>0 then
    message('Travel needs attention.\\p'..table.concat(issues,'\\p')..'\\pEnable compatible versions\nfor both games in launcher.')
    return
  end
  local state=game.session.modData and game.session.modData[C.KEY] or {}
  local function confirm()
    local Message=require('src.ui.game3.message')
    Message.show(P.label(target)..'\n'..(state.regions and state.regions[target] and 'Return to saved progress?' or 'Start a new regional story?')..'\\pTravel saves automatically.\nReady to depart?',{hold=true,done=function()
      local Choice=require('src.ui.game3.choice')
      Choice.yesNo(function(yes)
        Message.reset()
        if yes then queue(target) end
      end)
      Choice.cursor=2
    end})
  end
  if not state.travelGuideSeen then
    message('Welcome to Hoennto!\\pYour trainer, Pokemon and\nPokedex travel together.\\pBags, money, badges and\nstories stay in each region.\\pEach story starts normally.\nLater trips resume your save.',confirm)
  else confirm() end
end
function P.loading(target)
  require('src.ui.game3.message').showStay('Preparing your journey...\n'..P.label(target),{speed=0})
end
function P.closeLoading() require('src.ui.game3.message').reset() end
return P
end
