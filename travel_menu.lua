-- Cartridge-neutral window overlay. Uses LOVE geometry/fonts only.
return function(C,Bridge,queue)
local M={}
local W,H=560,486
local games={
 red={name='Red',region='Kanto',gen=1,color={.91,.31,.35}},blue={name='Blue',region='Kanto',gen=1,color={.30,.53,.94}},
 yellow={name='Yellow',region='Kanto',gen=1,color={.94,.75,.24}},gold={name='Gold',region='Johto',gen=2,color={.90,.68,.28}},
 silver={name='Silver',region='Johto',gen=2,color={.67,.77,.87}},crystal={name='Crystal',region='Johto',gen=2,color={.34,.79,.86}},
 firered={name='FireRed',region='Kanto',gen=3,color={.97,.43,.25}},leafgreen={name='LeafGreen',region='Kanto',gen=3,color={.43,.79,.39}},
 ruby={name='Ruby',region='Hoenn',gen=3,color={.92,.29,.40}},sapphire={name='Sapphire',region='Hoenn',gen=3,color={.37,.49,.94}},
 emerald={name='Emerald',region='Hoenn',gen=3,color={.24,.80,.59}},
}
local ink={.91,.95,.98};local muted={.58,.68,.75};local aqua={.32,.86,.77}
local function state(game) return game.session and game.session.modData and game.session.modData[C.KEY] or {} end
local function layout(w,h)
 local scale=math.min(w/(W+32),h/(H+32),1.65)
 return scale,(w-W*scale)/2,(h-H*scale)/2
end
local function cardRect(index,overview)
 local row=math.floor((index-1)/2);local col=(index-1)%2
 return 22+col*262,120+row*(overview and 49 or 58),254,overview and 43 or 51
end
local function rowsFor(game,overview)
 local rows={};local saved=state(game)
 for _,v in ipairs(C.ORDER) do if overview or v~=game.session.version then
  local ready=Bridge.available(v)
  rows[#rows+1]={version=v,label=games[v].name,ready=ready,
   story=v==game.session.version and 'Current story' or saved.regions and saved.regions[v] and 'Continue story' or 'New story'}
 end end
 return rows
end
function M.close(game)
 game._hoenntoMenu=nil
 if game.input then game.input:reset() end
 if game.touchControls and game.touchControls.reset then game.touchControls:reset() end
end
function M.open(game)
 game._hoenntoMenu={rows=rowsFor(game),index=1,mode='choose'}
 game.input:reset()
end
function M.overview(game)
 game._hoenntoMenu={mode='overview',rows=rowsFor(game,true),index=1}
 game.input:reset()
end
function M.select(game)
 local s=game._hoenntoMenu;if not s then return end
 if s.mode=='overview' then M.close(game);return end
 if s.mode=='notice' then
  if s.page and s.pages and s.page<#s.pages then s.page=s.page+1 else M.close(game) end
  return
 end
 if s.mode=='confirm' then local target=s.target;M.close(game);queue(target);return end
 local row=s.rows[s.index];local ok,reason=Bridge.available(row.version)
 if ok then local issues=Bridge.compatibility(game,row.version);if #issues>0 then ok=false;reason=table.concat(issues,'\n\n') end end
 s.target=row.version;s.mode=ok and 'confirm' or 'notice';s.page=nil;s.pages=nil
 s.text=not ok and tostring(reason or 'Destination unavailable.') or nil
end
local function move(s,n)
 s.index=(s.index-1+n)%#s.rows+1
end
function M.update(game)
 local s=game._hoenntoMenu;if not s then return end
 local i=game.input;i:pollPads();i:step()
 if i:wasPressed('b') or i:wasPressed('start') then M.close(game);return end
 if s.mode=='choose' then
  if i:wasPressed('down') then move(s,2) end
  if i:wasPressed('up') then move(s,-2) end
  if i:wasPressed('right') then move(s,1) end
  if i:wasPressed('left') then move(s,-1) end
 elseif s.mode=='notice' and s.pages then
  if i:wasPressed('right') or i:wasPressed('down') then s.page=math.min(#s.pages,s.page+1) end
  if i:wasPressed('left') or i:wasPressed('up') then s.page=math.max(1,s.page-1) end
 end
 if i:wasPressed('a') then M.select(game) end
end
local function localPoint(x,y)
 local w,h=love.graphics.getDimensions();local scale,ox,oy=layout(w,h)
 return (x-ox)/scale,(y-oy)/scale
end
local function hitCard(s,x,y)
 for n=1,#s.rows do local cx,cy,cw,ch=cardRect(n,s.mode=='overview')
  if x>=cx and x<=cx+cw and y>=cy and y<=cy+ch then return n end
 end
end
function M.hover(game,x,y)
 local s=game._hoenntoMenu;if not s or s.mode~='choose' then return end
 x,y=localPoint(x,y);local n=hitCard(s,x,y);if n then s.index=n end
end
function M.wheel(game,dy)
 local s=game._hoenntoMenu;if not s then return end
 if s.mode=='choose' and dy~=0 then move(s,dy>0 and -2 or 2)
 elseif s.mode=='notice' and s.pages then s.page=math.max(1,math.min(#s.pages,s.page+(dy>0 and -1 or 1))) end
end
function M.pointer(game,x,y)
 local s=game._hoenntoMenu;if not s then return false end
 x,y=localPoint(x,y)
 if x<0 or x>W or y<0 or y>H then return false end
 if y>=434 and y<=470 then
  if x>=22 and x<=274 then M.select(game) elseif x>=286 and x<=538 then M.close(game) end
 elseif s.mode=='choose' then local n=hitCard(s,x,y);if n then s.index=n;M.select(game) end end
 return true
end
local function color(g,c,a)g.setColor(c[1],c[2],c[3],a or 1)end
local function fonts(g)
 if not g.newFont then return end
 M.fonts=M.fonts or {title=g.newFont(23),body=g.newFont(15),small=g.newFont(11),card=g.newFont(17)}
end
local function text(g,font,str,x,y,c)
 if M.fonts then g.setFont(M.fonts[font]) end;color(g,c or ink);g.print(str,x,y)
end
local function ball(g,x,y,c)
 color(g,c);g.circle('fill',x,y,11)
 color(g,{.08,.14,.19});g.rectangle('fill',x-12,y-2,24,4)
 color(g,ink);g.circle('fill',x,y,4)
end
local function card(g,row,n,selected,overview)
 local x,y,w,h=cardRect(n,overview);local info=games[row.version]
 color(g,selected and {.13,.25,.30} or {.075,.13,.19});g.rectangle('fill',x,y,w,h,7,7)
 color(g,selected and aqua or {.16,.24,.29});g.setLineWidth(selected and 1.6 or 1);g.rectangle('line',x+.5,y+.5,w-1,h-1,7,7)
 color(g,info.color,row.ready and 1 or .45);g.rectangle('fill',x+9,y+9,3,h-18,2,2)
 text(g,'card',info.name,x+21,y+7,row.ready and ink or muted)
 text(g,'small',row.ready and row.story or 'Import ROM to visit',x+21,y+(overview and 27 or 32),muted)
 text(g,'small','GEN '..info.gen,x+w-55,y+11,info.color)
 if selected then color(g,aqua);g.circle('fill',x+w-17,y+h-13,3) end
end
local function paragraphs(s,g)
 if s.pages then return end
 local lines={};local font=M.fonts and M.fonts.body
 for para in ((s.text or '')..'\n'):gmatch('(.-)\n') do
  local line=''
  for word in para:gmatch('%S+') do
   local candidate=line=='' and word or line..' '..word
   local width=font and font.getWidth and font:getWidth(candidate) or #candidate*8
   if width>480 and line~='' then lines[#lines+1]=line;line=word else line=candidate end
  end
  lines[#lines+1]=line
 end
 s.pages={};for i=1,#lines,13 do local page={};for j=i,math.min(i+12,#lines)do page[#page+1]=lines[j]end;s.pages[#s.pages+1]=table.concat(page,'\n')end
 if #s.pages==0 then s.pages={''}end;s.page=1
end
function M.draw(game)
 local s=game._hoenntoMenu;if not s then return end
 local g=love.graphics;local w,h=g.getDimensions();local scale,ox,oy=layout(w,h)
 g.push('all');g.origin();g.setShader();g.setScissor();if g.setStencilTest then g.setStencilTest()end
 color(g,{.015,.035,.055},.83);g.rectangle('fill',0,0,w,h)
 g.translate(ox,oy);g.scale(scale,scale);fonts(g)
 color(g,{0,0,0},.28);g.rectangle('fill',4,6,W,H,14,14)
 color(g,{.045,.085,.13});g.rectangle('fill',0,0,W,H,12,12)
 color(g,{.13,.25,.30});g.setLineWidth(1);g.rectangle('line',.5,.5,W-1,H-1,12,12)
 color(g,aqua);g.rectangle('fill',22,22,29,3,2,2)
 text(g,'small','REGION LINK',61,18,aqua)
 text(g,'title','Hoennto',22,38)
 local source=games[game.session.version]
 text(g,'small','FROM '..source.name:upper()..'  /  '..source.region:upper(),198,50,muted)
 ball(g,524,42,source.color)
 color(g,{.13,.22,.27});g.rectangle('fill',22,83,516,1)
 text(g,'body',s.mode=='overview' and 'Your eleven stories' or s.mode=='confirm' and 'Ready to depart?' or s.mode=='notice' and 'Before you travel' or 'Choose your next destination',22,96)
 if s.mode=='choose' or s.mode=='overview' then
  for n,row in ipairs(s.rows) do card(g,row,n,s.mode=='choose' and s.index==n,s.mode=='overview')end
 elseif s.mode=='confirm' then
  local info=games[s.target];color(g,{.08,.16,.22});g.rectangle('fill',22,128,516,78,8,8)
  ball(g,52,167,info.color);text(g,'title',info.name,76,143)
  text(g,'small',info.region:upper()..'  /  GENERATION '..info.gen..'  /  '..s.rows[s.index].story:upper(),77,176,info.color)
  text(g,'body','Your current game saves before departure.',24,228)
  text(g,'body','Compatible Pokemon travel with you.',24,262,aqua)
  if M.fonts then g.setFont(M.fonts.body)end;color(g,muted)
  g.printf('Unsupported species, moves, held items and storage overflow stay in campaign reserve until a compatible destination is available.',24,289,490)
  text(g,'small','Each cartridge keeps its own story, badges and bag.',24,366,muted)
 else
  paragraphs(s,g);if M.fonts then g.setFont(M.fonts.body)end;color(g,ink)
  g.printf(s.pages[s.page],24,132,492)
  if #s.pages>1 then text(g,'small','PAGE '..s.page..' / '..#s.pages..'  -  LEFT / RIGHT',24,389,aqua)end
 end
 if s.mode=='choose' or s.mode=='overview' then
  text(g,'small','RESERVE  '..tostring(state(game).reserveCount or 0)..' Pokemon',24,417,aqua)
  text(g,'small',s.mode=='choose' and 'D-PAD: CHOOSE  /  TAP A CARD' or 'ONE TRAINER. INDEPENDENT PROGRESS.',269,417,muted)
 end
 local action=s.mode=='confirm' and 'A   Travel' or s.mode=='notice' and s.page<#s.pages and 'A   Next page' or (s.mode=='notice' or s.mode=='overview') and 'A   Close' or 'A   Select'
 color(g,{.17,.48,.43});g.rectangle('fill',22,440,252,29,6,6)
 color(g,{.11,.18,.24});g.rectangle('fill',286,440,252,29,6,6)
 text(g,'body',action,38,446);text(g,'body',s.mode=='overview' and 'B   Close' or 'B   Cancel',302,446,muted)
 g.pop()
 if game.touchControls and game.touchControls.draw then game.touchControls:draw() end
end
return M
end
