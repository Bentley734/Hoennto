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
local M=assert(Sandbox.compile(source,'@travel_menu.lua',Sandbox.envFor({modId='kanto_hoenn',permissions={engine_internals=true}})))()(C,
 {available=function()return ready,'Import the destination ROM first.'end,compatibility=function()return issues end},
 function(v)queued[#queued+1]=v end)
local Input=require('src.core.Input');Input:init()
local game={session={version='red',modData={}},input=Input,touchControls={reset=function()end}}
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function press(key)Input:keypressed(key);M.update(game);Input:keyreleased(key);if game._hoenntoMenu then M.update(game)end end
M.open(game);eq(#game._hoenntoMenu.rows,10,'all ten destinations presented')
press('right');eq(game._hoenntoMenu.index,2,'right chooses adjacent card')
press('down');eq(game._hoenntoMenu.index,4,'down chooses next card row')
press('up');eq(game._hoenntoMenu.index,2,'up chooses previous row')
press('left');eq(game._hoenntoMenu.index,1,'left chooses adjacent card')
press('left');eq(game._hoenntoMenu.index,10,'direction wraps at boundary')
press('z');eq(game._hoenntoMenu.mode,'confirm','keyboard opens confirmation')
eq(#queued,0,'selection alone never departs')
press('x');eq(game._hoenntoMenu,nil,'B cancels confirmation')
local dimensions={{320,240},{480,320},{960,640},{1920,1080}}
for _,size in ipairs(dimensions)do
 local w,h=size[1],size[2];love.graphics.getDimensions=function()return w,h end
 local scale=math.min(w/592,h/518,1.65);local ox,oy=(w-560*scale)/2,(h-486*scale)/2
 local function p(x,y)return ox+x*scale,oy+y*scale end
 M.open(game);M.draw(game)
 local x,y=p(450,382);M.hover(game,x,y);eq(game._hoenntoMenu.index,10,'last card hover survives scaling')
 eq(M.pointer(game,x,y),true,'touch on card handled');eq(game._hoenntoMenu.target,'emerald','scaled touch selects correct cartridge')
 eq(#queued,0,'touch card opens confirmation only')
 x,y=p(120,454);M.pointer(game,x,y);eq(queued[#queued],'emerald','touch confirmation departs')
 queued={};M.open(game);M.wheel(game,-1);eq(game._hoenntoMenu.index,3,'wheel follows grid rows')
 local oldFont=love.graphics.newFont(9);love.graphics.setFont(oldFont);love.graphics.setShader('fixture-shader')
 M.draw(game);eq(love.graphics.getFont(),oldFont,'draw restores font');eq(love.graphics.getShader(),'fixture-shader','draw restores shader')
 M.overview(game);M.draw(game);eq(#game._hoenntoMenu.rows,11,'overview shows all cartridges')
 M.select(game);eq(game._hoenntoMenu,nil,'overview closes without departing')
end
ready=false;M.open(game);M.select(game);eq(game._hoenntoMenu.mode,'notice','missing import has readable notice')
M.draw(game);M.select(game);eq(#queued,0,'unavailable target never queued')
ready=true;issues={string.rep('Companion setup needs attention. ',200)}
M.open(game);M.select(game);M.draw(game)
eq(#game._hoenntoMenu.pages>1,true,'long compatibility notices are paginated')
M.select(game);eq(game._hoenntoMenu.page,2,'A advances long notice')
press('left');eq(game._hoenntoMenu.page,1,'left returns to previous notice page')
press('x');eq(game._hoenntoMenu,nil,'long notice cancels')
eq(#queued,0,'compatibility issue never departs')
print('Travel panel native input / scaled touch / notice pagination',checks)
