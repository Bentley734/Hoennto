-- Shared window-space panel; native pad bindings and touch controls still
-- feed Input. Gameplay is paused while choosing a cartridge.
return function(C,Bridge,queue)
local M={}
local names={red='Red',blue='Blue',yellow='Yellow',gold='Gold',silver='Silver',crystal='Crystal',firered='FireRed',leafgreen='LeafGreen',ruby='Ruby',sapphire='Sapphire',emerald='Emerald'}
local function layout(w,h)
  local scale=math.min(w/400,h/370)
  return scale,(w-380*scale)/2,(h-350*scale)/2
end
function M.close(game) game._hoenntoMenu=nil;if game.input then game.input:reset() end end
function M.open(game)
  local rows={}
  for _,v in ipairs(C.ORDER) do if v~=game.session.version then
    local ready=Bridge.available(v)
    rows[#rows+1]={version=v,label=names[v]..(ready and '' or ' (import ROM)'),ready=ready}
  end end
  game._hoenntoMenu={rows=rows,index=1,mode='choose'}
  game.input:reset()
end
function M.overview(game)
  local state=game.session.modData and game.session.modData[C.KEY] or {}
  local lines={'ONE TRAINER, ELEVEN STORIES',''}
  for _,v in ipairs(C.ORDER) do lines[#lines+1]=names[v]..': '..(v==game.session.version and 'Current' or state.regions and state.regions[v] and 'Started' or 'New story') end
  lines[#lines+1]='';lines[#lines+1]='Reserve: '..tostring(state.reserveCount or 0)..' Pokemon'
  lines[#lines+1]='A / B: close'
  game._hoenntoMenu={mode='notice',text=table.concat(lines,'\n')}
  game.input:reset()
end
function M.select(game)
  local s=game._hoenntoMenu;if not s then return end
  if s.mode=='notice' then M.close(game);return end
  if s.mode=='confirm' then local target=s.target;M.close(game);queue(target);return end
  local row=s.rows[s.index];local ok,reason=Bridge.available(row.version)
  if ok then local issues=Bridge.compatibility(game,row.version);if #issues>0 then ok=false;reason=table.concat(issues,'\n') end end
  s.target=row.version;s.mode=ok and 'confirm' or 'notice'
  s.text=ok and ('Travel to '..names[row.version]..'?\nYour game will save first.\n\nCompatible Pokemon travel.\nUnsupported species, moves,\nheld items and full-box overflow\nstay safe in campaign reserve.\n\nA: travel     B: cancel') or (reason..'\n\nA / B: close')
end
function M.update(game)
  local s=game._hoenntoMenu;if not s then return end
  local i=game.input;i:pollPads();i:step()
  if i:wasPressed('b') or i:wasPressed('start') then M.close(game);return end
  if s.mode=='choose' then
    if i:wasPressed('down') then s.index=s.index%#s.rows+1 end
    if i:wasPressed('up') then s.index=(s.index-2)%#s.rows+1 end
  end
  if i:wasPressed('a') then M.select(game) end
end
function M.pointer(game,x,y)
  local s=game._hoenntoMenu;if not s then return false end
  local w,h=love.graphics.getDimensions();local scale,ox,oy=layout(w,h)
  x,y=(x-ox)/scale,(y-oy)/scale
  if x<0 or x>380 or y<0 or y>350 then return false end
  if y>=306 and y<=339 then
    if x<190 then M.select(game) else M.close(game) end
  elseif s.mode=='choose' then
    local start=math.max(1,math.min(s.index-4,#s.rows-7))
    local row=start+math.floor((y-44)/30)
    if y>=44 and y<284 and s.rows[row] then s.index=row;M.select(game) end
  end
  return true
end
function M.draw(game)
  local s=game._hoenntoMenu;if not s then return end
  local g=love.graphics;local w,h=g.getDimensions();local scale,ox,oy=layout(w,h)
  g.push('all');g.origin();g.setShader();g.setScissor()
  g.setColor(0,0,0,0.7);g.rectangle('fill',0,0,w,h)
  g.translate(ox,oy);g.scale(scale,scale)
  if g.newFont then
    M.font=M.font or g.newFont(14);M.smallFont=M.smallFont or g.newFont(12)
    g.setFont(s.mode=='notice' and M.smallFont or M.font)
  end
  g.setColor(0.07,0.1,0.15,1);g.rectangle('fill',0,0,380,350,10,10)
  g.setColor(1,1,1,1);g.print('HOENNTO - TRAVEL',18,15)
  if s.mode=='choose' then
    local start=math.max(1,math.min(s.index-4,#s.rows-7))
    for n=start,math.min(start+7,#s.rows) do
      local y=48+(n-start)*30
      if n==s.index then g.setColor(0.2,0.38,0.52,1);g.rectangle('fill',10,y-4,360,28) end
      g.setColor(1,1,1,1);g.print((n==s.index and '> ' or '  ')..s.rows[n].label,18,y)
    end
    g.print('Reserve: '..tostring(game.session.modData and game.session.modData[C.KEY] and game.session.modData[C.KEY].reserveCount or 0)..' | Up / Down: choose',18,285)
  else g.printf(s.text or '',18,52,344) end
  g.setColor(0.2,0.38,0.52,1);g.rectangle('fill',12,306,174,25,4,4);g.rectangle('fill',194,306,174,25,4,4)
  g.setColor(1,1,1,1);g.print(s.mode=='confirm' and 'A: Travel' or s.mode=='notice' and 'A: Close' or 'A: Select',24,310);g.print('B: Cancel',206,310)
  g.pop()
  if game.touchControls and game.touchControls.draw then game.touchControls:draw() end
end
return M
end
