-- Window-space transition, drawn without cartridge assets so it survives
-- native cache eviction. Loading pulses never update gameplay or dispatch input.
local T={DURATION=0.28}
local unpackValues=table.unpack or unpack
local function pack(...)return {n=select('#',...),...}end
local function clock()
  return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
end
function T.begin(game,target)
  game._hoenntoTransition={phase='out',elapsed=0,target=target,started=clock()}
end
function T.tick(game,dt)
  local state=game._hoenntoTransition
  if not state then return false end
  state.elapsed=state.elapsed+math.max(0,math.min(dt or 0,0.1))
  if state.phase=='out' and state.elapsed>=T.DURATION then
    state.phase='loading';state.elapsed=0
    return true
  elseif state.phase=='in' and state.elapsed>=T.DURATION then
    game._hoenntoTransition=nil
    if game.input and game.input.reset then game.input:reset() end
    if game.touchControls and game.touchControls.reset then game.touchControls:reset() end
  end
  return false
end
function T.finish(game)
  local state=game._hoenntoTransition
  if state then state.phase='in';state.elapsed=0 end
end
function T.alpha(state)
  if state.phase=='loading' then return 1 end
  local progress=math.min(1,math.max(0,state.elapsed/T.DURATION))
  local eased=progress*progress*(3-2*progress)
  return state.phase=='in' and 1-eased or eased
end
function T.draw(state)
  local g=love and love.graphics
  if not state or not g or not g.getDimensions then return end
  local w,h=g.getDimensions()
  local canvas=g.getCanvas and g.getCanvas()
  if canvas and canvas.getDimensions then w,h=canvas:getDimensions() end
  local alpha=T.alpha(state)
  g.push('all')
  local ok,err=pcall(function()
  g.origin();g.setShader();g.setScissor()
  if g.setStencilTest then g.setStencilTest() end
  g.setColor(0,0,0,alpha);g.rectangle('fill',0,0,w,h)
  if state.phase=='loading' then
    local scale=math.max(1,math.min(w/240,h/160))
    local radius=8*scale
    g.translate(w-18*scale,h-18*scale)
    g.rotate((clock()-state.started)*3.5)
    -- Red upper half, white lower half, dark seam and central button.
    g.setColor(0.92,0.15,0.20,1)
    g.arc('fill','pie',0,0,radius,math.pi,2*math.pi,32)
    g.setColor(0.96,0.97,1,1)
    g.arc('fill','pie',0,0,radius,0,math.pi,32)
    g.setLineWidth(1.5*scale)
    g.setColor(0.10,0.12,0.16,1)
    g.circle('line',0,0,radius,32);g.line(-radius,0,radius,0)
    g.circle('fill',0,0,3*scale,24)
    g.setColor(0.96,0.97,1,1);g.circle('fill',0,0,1.7*scale,24)
  end
  end)
  g.pop()
  if not ok then error(err) end
end

-- Native loading is synchronous. Refresh at actual cache/graphics checkpoints
-- rather than claiming a background loader. One indivisible C call or Lua
-- computation can still pause the spinner. Only OS event pumping occurs here;
-- quit/input remain queued for the host's normal loop after the handoff.
function T.withRefresh(game,fn)
  local g=love and love.graphics
  local last=-math.huge
  local busy,disabled,active=false,false,true
  local function pulse(force)
    if not active or busy or disabled or not g or not g.present or not g.getCanvas
        or (g.isActive and not g.isActive()) then return end
    local now=clock()
    if not force and now-last<1/30 then return end
    last=now;busy=true
    local canvas=pack(g.getCanvas())
    local pushed=false
    local ok,err=pcall(function()
      g.push('all');pushed=true
      g.setCanvas();g.origin();g.setShader();g.setScissor()
      g.clear(0,0,0,1)
      T.draw(game._hoenntoTransition)
      g.present()
      local Host=require('src.core.HostShell')
      if Host.pumpHostEvents then Host.pumpHostEvents() end
    end)
    if pushed then pcall(g.pop) end
    pcall(g.setCanvas,unpackValues(canvas,1,canvas.n))
    busy=false
    if not ok then disabled=true;print('[Hoennto] Loading refresh unavailable: '..tostring(err)) end
  end
  local replacements={}
  local function wrap(object,key)
    if not object or type(object[key])~='function' then return end
    local original=object[key]
    local replacement=function(...)
      pulse(false)
      local result=pack(original(...))
      pulse(false)
      return unpackValues(result,1,result.n)
    end
    object[key]=replacement
    replacements[#replacements+1]={object=object,key=key,original=original,replacement=replacement}
  end
  local Cache=require('src.import.CacheFs')
  for _,key in ipairs({'readAt','read','readActive','loadActive','write','mountVersion'}) do wrap(Cache,key) end
  -- Image uploads and generated data loads can be slow even after a cache read.
  for _,key in ipairs({'newImage','newImageData','newFont'}) do wrap(g,key) end
  pulse(true)
  local result=pack(pcall(fn))
  -- Restore even on destination/rollback failure; never overwrite a replacement
  -- another mod deliberately installed during its own initialization.
  for i=#replacements,1,-1 do
    local entry=replacements[i]
    if entry.object[entry.key]==entry.replacement then entry.object[entry.key]=entry.original end
  end
  pulse(true)
  active=false
  return unpackValues(result,1,result.n)
end
return T
