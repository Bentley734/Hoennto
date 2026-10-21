local root=arg[1]
love=require('tests.love_stub')
-- The stock headless stub tracks shader/canvas but omits font stack state.
local push,pop=love.graphics.push,love.graphics.pop
local fontStack={}
love.graphics.push=function(...)fontStack[#fontStack+1]={love.graphics.getFont()};push(...)end
love.graphics.pop=function()pop();local f=table.remove(fontStack);love.graphics.setFont(f[1])end
local Sandbox=require('src.mods.Sandbox')
local C=assert(loadfile(root..'/campaign.lua'))()
local source=assert(io.open(root..'/travel_menu.lua')):read('*a')
local queued,ready,issues={},true,{}
local loads,draws,statuses=0,{},{}
local image={setFilter=function()end,getDimensions=function()return 1677,938 end}
love.graphics.newQuad=function(x,y,w,h,aw,ah)assert(x>=0 and y>=0 and x+w<=aw and y+h<=ah);return {x=x,y=y,w=w,h=h}end
love.graphics.draw=function(img,q,x,y,r,sx,sy)draws[#draws+1]={img=img,q=q,x=x,y=y,sx=sx,sy=sy}end
local nativePrint=love.graphics.print
love.graphics.print=function(str,...)statuses[str]=true;return nativePrint(str,...)end
local M=assert(Sandbox.compile(source,'@travel_menu.lua',Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})))()(C,
 {available=function()return ready,'Import the destination ROM first.'end,compatibility=function()return issues end},
 function(v)queued[#queued+1]=v end,{image=function(_,path)assert(path=='assets/travel-buttons.png');loads=loads+1;return image end})
local Input=require('src.core.Input');Input:init()
local game={session={version='red',modData={}},input=Input,touchControls={reset=function()end}}
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function press(key)Input:keypressed(key);M.update(game);Input:keyreleased(key);if game._hoenntoMenu then M.update(game)end end
M.open(game);eq(#game._hoenntoMenu.rows,11,'all cartridges visible including current story');eq(loads,0,'art stays lazy until the menu draws')
press('right');eq(game._hoenntoMenu.index,3,'right chooses adjacent card')
press('down');eq(game._hoenntoMenu.index,6,'down chooses next card row')
press('up');eq(game._hoenntoMenu.index,3,'up chooses previous row')
press('left');eq(game._hoenntoMenu.index,2,'left chooses adjacent card')
press('left');press('left');eq(game._hoenntoMenu.index,11,'direction wraps at boundary')
press('z');eq(game._hoenntoMenu.mode,'confirm','keyboard opens confirmation')
eq(#queued,0,'selection alone never departs')
press('x');eq(game._hoenntoMenu,nil,'B cancels confirmation')
local dimensions={{320,240},{480,320},{960,640},{1920,1080}}
for _,size in ipairs(dimensions)do
 local w,h=size[1],size[2];love.graphics.getDimensions=function()return w,h end
 local scale=math.min(w/932,h/904,1.65);local ox,oy=(w-900*scale)/2,(h-872*scale)/2
 local function p(x,y)return ox+x*scale,oy+y*scale end
 M.open(game);M.draw(game)
 local x,y=p(590,690);M.hover(game,x,y);eq(game._hoenntoMenu.index,11,'last card hover survives scaling')
 eq(M.pointer(game,x,y),true,'touch on card handled');eq(game._hoenntoMenu.target,'leafgreen','scaled touch selects correct cartridge')
 eq(#queued,0,'touch card opens confirmation only')
 x,y=p(120,827);M.pointer(game,x,y);eq(queued[#queued],'leafgreen','touch confirmation departs')
 queued={};M.open(game);M.wheel(game,-1);eq(game._hoenntoMenu.index,5,'wheel follows grid rows')
 local oldFont=love.graphics.newFont(9);love.graphics.setFont(oldFont);love.graphics.setShader('fixture-shader')
 M.draw(game);eq(love.graphics.getFont(),oldFont,'draw restores font');eq(love.graphics.getShader(),'fixture-shader','draw restores shader')
 M.overview(game);M.draw(game);eq(#game._hoenntoMenu.rows,11,'overview shows all cartridges')
 M.select(game);eq(game._hoenntoMenu,nil,'overview closes without departing')
end
eq(loads,1,'atlas loads once across repeated draws')
eq(#draws>40,true,'all supplied cards draw through atlas quads')
eq(statuses['CURRENT STORY'],true,'current story status remains dynamic')
game.session.modData[C.KEY]={regions={gold=true}};M.open(game);M.draw(game)
eq(statuses['CONTINUE STORY'],true,'existing linked save has continue status')
game._hoenntoMenu.index=1;M.select(game);eq(game._hoenntoMenu.mode,'notice','current cartridge cannot be queued')
ready=false;M.open(game);M.draw(game);eq(statuses['ROM NOT IMPORTED'],true,'unavailable cards show their live ROM status')
M.select(game);eq(game._hoenntoMenu.mode,'notice','missing import has readable notice')
M.draw(game);M.select(game);eq(#queued,0,'unavailable target never queued')
ready=true;issues={string.rep('Companion setup needs attention. ',200)}
M.open(game);M.select(game);M.draw(game)
eq(#game._hoenntoMenu.pages>1,true,'long compatibility notices are paginated')
M.select(game);eq(game._hoenntoMenu.page,2,'A advances long notice')
press('left');eq(game._hoenntoMenu.page,1,'left returns to previous notice page')
press('x');eq(game._hoenntoMenu,nil,'long notice cancels')
eq(#queued,0,'compatibility issue never departs')
-- Every visible card hitbox maps to its artwork, in every source cartridge.
ready=true;issues={}
for _,version in ipairs(C.ORDER)do
 game.session.version=version;M.open(game)
 for n=1,11 do
  local row=math.floor((n-1)/3);local col=(n-1)%3
  local cx=(row==3 and 170 or 30)+col*280+140;local cy=142+row*160+69
  local w,h=love.graphics.getDimensions();local scale=math.min(w/932,h/904,1.65)
  M.hover(game,(w-900*scale)/2+cx*scale,(h-872*scale)/2+cy*scale)
  eq(game._hoenntoMenu.index,n,'every grouped card has its own correct hitbox')
 end
end
print('Travel panel native input / scaled touch / notice pagination',checks)
