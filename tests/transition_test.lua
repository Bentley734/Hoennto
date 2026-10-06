local root=assert(arg[1])
local T
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local time=0
local canvas='engine-canvas'
local pushes,presents,pumps,rotation=0,0,0,0
local fillAlpha,ballPosition
local failDraw=false
local graphics={
  getDimensions=function()return 960,640 end,isActive=function()return true end,
  getCanvas=function()return canvas end,setCanvas=function(c)canvas=c end,
  push=function()pushes=pushes+1 end,pop=function()pushes=pushes-1 end,
  origin=function()end,setShader=function()end,setScissor=function()end,setStencilTest=function()end,
  clear=function()end,setColor=function(_,_,_,a)fillAlpha=a end,
  rectangle=function()if failDraw then error('draw fixture failure')end end,
  translate=function(x,y)ballPosition={x,y}end,rotate=function(a)rotation=a end,
  arc=function()end,setLineWidth=function()end,circle=function()end,line=function()end,
  present=function()eq(canvas,nil,'refresh presents only window canvas');presents=presents+1 end,
  newImage=function(name)return name,nil,'image metadata' end,
}
love={graphics=graphics,timer={getTime=function()return time end}}
local Sandbox=require('src.mods.Sandbox')
local source=assert(io.open(root..'/transition.lua')):read('*a')
T=assert(Sandbox.compile(source,'@transition.lua',Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})))()
package.loaded['src.core.HostShell']={pumpHostEvents=function()pumps=pumps+1 end}
local read=function(key)time=time+0.08;return key,nil,'metadata' end
local cache={read=read}
package.loaded['src.import.CacheFs']=cache
local game={}
T.begin(game,'emerald')
eq(T.alpha(game._hoenntoTransition),0,'fade starts transparent')
eq(T.tick(game,0.1),false,'no early handoff')
eq(T.alpha(game._hoenntoTransition)>0 and T.alpha(game._hoenntoTransition)<1,true,'intermediate fade alpha')
T.tick(game,0.1);eq(T.tick(game,0.1),true,'handoff only after fade out')
eq(T.alpha(game._hoenntoTransition),1,'loading fully covered')
T.draw(game._hoenntoTransition)
eq(pushes,0,'normal drawing restores graphics stack')
eq(ballPosition[1],888,'bottom-right spinner x scales with window')
eq(ballPosition[2],568,'bottom-right spinner y scales with window')
local image=graphics.newImage
local ok,a,b,c=T.withRefresh(game,function()
  local v,n,meta=cache.read('first')
  eq(v,'first','wrapped read result');eq(n,nil,'nil result retained');eq(meta,'metadata','third result retained')
  local firstAngle=rotation
  cache.read('second')
  eq(rotation~=firstAngle,true,'spinner changes angle during synchronous reads')
  eq(canvas,'engine-canvas','refresh restores native render target')
  return 'done',nil,'third'
end)
eq(ok,true,'loading completes');eq(a,'done','outer result retained');eq(b,nil,'outer nil retained');eq(c,'third','outer third result retained')
eq(presents>=4,true,'slow work refreshes multiple frames');eq(pumps,presents,'OS pump once per loading frame')
eq(cache.read,read,'cache wrapper restored');eq(graphics.newImage,image,'graphics wrapper restored');eq(pushes,0,'loading restores graphics stack')
local success,err=T.withRefresh(game,function()cache.read('error');error('destination load failure')end)
eq(success,false,'destination exception returned');eq(tostring(err):find('destination load failure',1,true)~=nil,true,'load error retained')
eq(cache.read,read,'failure restores cache wrapper');eq(graphics.newImage,image,'failure restores graphics wrapper')
eq(canvas,'engine-canvas','failure restores canvas');eq(pushes,0,'failure restores graphics stack')
failDraw=true
local refreshed=T.withRefresh(game,function()cache.read('draw failure')end)
eq(refreshed,true,'graphics failure never cancels travel');eq(pushes,0,'graphics failure restores all pushes')
eq(canvas,'engine-canvas','graphics failure restores render target');eq(cache.read,read,'graphics failure restores cache wrapper')
failDraw=false
local retained
T.withRefresh(game,function()
  local wrapped=cache.read
  retained=function(...)return wrapped(...)end
  cache.read=retained
end)
eq(cache.read,retained,'later mod replacement respected')
local count=presents
cache.read('after loading')
eq(presents,count,'retained wrapper cannot repaint after loading')
cache.read=read
T.finish(game);eq(T.alpha(game._hoenntoTransition),1,'fade in starts covered')
local resets=0;game.input={reset=function()resets=resets+1 end}
T.tick(game,0.1);eq(T.alpha(game._hoenntoTransition)<1,true,'fade in reveals field')
T.tick(game,0.1);T.tick(game,0.1)
eq(game._hoenntoTransition,nil,'transition released after arrival');eq(resets,1,'transition input cleared once')
graphics.isActive=function()return false end
T.begin(game,'leafgreen');T.tick(game,0.1);T.tick(game,0.1);T.tick(game,0.1)
eq(T.withRefresh(game,function()return true end),true,'headless load supported')
print('transition_test: '..checks..' checks passed')
