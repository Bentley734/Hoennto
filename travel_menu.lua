-- Cartridge-neutral overlay; artwork loads lazily through the mod asset API.
return function(C,Bridge,queue,assets)
local M={}
local W,H=900,872
local order={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','emerald','firered','leafgreen'}
local atlasRects={
 red={48,112,393,204},blue={444,112,393,204},yellow={840,112,393,204},gold={1236,112,393,204},
 silver={48,376,393,204},crystal={444,376,393,204},ruby={840,376,393,204},sapphire={1236,376,393,204},
 emerald={238,630,398,204},firered={638,630,398,204},leafgreen={1037,630,398,204},
}
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
 local row=math.floor((index-1)/3);local col=(index-1)%3
 return (row==3 and 170 or 30)+col*280,142+row*160,280,138
end
local function rowsFor(game,overview)
 local rows={};local saved=state(game)
 for _,v in ipairs(order) do
  local ready=Bridge.available(v)
  rows[#rows+1]={version=v,label=games[v].name,ready=ready,
   story=v==game.session.version and 'Current story' or saved.regions and saved.regions[v] and 'Continue story' or 'New story'}
 end
 return rows
end
function M.close(game)
 game._hoenntoMenu=nil
 if game.input then game.input:reset() end
 if game.touchControls and game.touchControls.reset then game.touchControls:reset() end
end
function M.open(game)
 game._hoenntoMenu={rows=rowsFor(game),index=game.session.version=='red' and 2 or 1,mode='choose'}
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
 if row.version==game.session.version then
  s.mode='notice';s.text='You are already playing Pokemon '..row.label..'. Choose another cartridge to travel.';s.page=nil;s.pages=nil;return
 end
 if ok then local issues=Bridge.compatibility(game,row.version);if #issues>0 then ok=false;reason=table.concat(issues,'\n\n') end end
 s.target=row.version;s.mode=ok and 'confirm' or 'notice';s.page=nil;s.pages=nil
 s.text=not ok and tostring(reason or 'Destination unavailable.') or nil
end
local function move(s,n)
 s.index=(s.index-1+n)%#s.rows+1
end
local function vertical(s,delta)
 local x,y,w=cardRect(s.index);local row=math.floor((s.index-1)/3)
 local target=(row+delta)%4;local best,distance
 for n=1,#s.rows do if math.floor((n-1)/3)==target then
  local nx=cardRect(n);local d=math.abs(nx-x)
  if not distance or d<distance then best,distance=n,d end
 end end
 s.index=best or s.index
end
function M.update(game)
 local s=game._hoenntoMenu;if not s then return end
 local i=game.input;i:pollPads();i:step()
 if i:wasPressed('b') or i:wasPressed('start') then M.close(game);return end
 if s.mode=='choose' then
  if i:wasPressed('down') then vertical(s,1) end
  if i:wasPressed('up') then vertical(s,-1) end
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
 if s.mode=='choose' and dy~=0 then vertical(s,dy>0 and -1 or 1)
 elseif s.mode=='notice' and s.pages then s.page=math.max(1,math.min(#s.pages,s.page+(dy>0 and -1 or 1))) end
end
function M.pointer(game,x,y)
 local s=game._hoenntoMenu;if not s then return false end
 x,y=localPoint(x,y)
 if x<0 or x>W or y<0 or y>H then return false end
 if y>=806 and y<=848 then
  if x>=30 and x<=438 then M.select(game) elseif x>=462 and x<=870 then M.close(game) end
 elseif s.mode=='choose' then local n=hitCard(s,x,y);if n then s.index=n;M.select(game) end end
 return true
end
local function color(g,c,a)g.setColor(c[1],c[2],c[3],a or 1)end
local function fonts(g)
 if not g.newFont then return end
 M.fonts=M.fonts or {title=g.newFont(40),body=g.newFont(19),small=g.newFont(13),card=g.newFont(22),status=g.newFont(13)}
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
 if not M.artAttempted then
  M.artAttempted=true
  if assets and assets.image and g.newQuad then
   local ok,image=pcall(function()return assets:image('assets/travel-buttons.png')end)
   if ok and image then
    M.art=image;image:setFilter('linear','linear');M.quads={}
    local aw,ah=image:getDimensions()
    for v,r in pairs(atlasRects)do M.quads[v]=g.newQuad(r[1],r[2],r[3],r[4],aw,ah)end
   end
  end
 end
 if M.art then
  if selected then
   color(g,aqua,.13);g.rectangle('fill',x-3,y-3,w+6,h+6,18,18)
   color(g,aqua);g.setLineWidth(2);g.rectangle('line',x-2,y-2,w+4,h+4,18,18)
  end
  color(g,{1,1,1},row.ready and 1 or .4)
  local r=atlasRects[row.version];g.draw(M.art,M.quads[row.version],x,y,0,w/r[3],h/r[4])
  text(g,'status',row.ready and row.story:upper() or 'ROM NOT IMPORTED',x+36,y+103,row.ready and {.65,.89,.93} or muted)
  return
 end
 color(g,selected and {.13,.25,.30} or {.075,.13,.19});g.rectangle('fill',x,y,w,h,7,7)
 color(g,selected and aqua or {.16,.24,.29});g.setLineWidth(selected and 1.6 or 1);g.rectangle('line',x+.5,y+.5,w-1,h-1,7,7)
 color(g,info.color,row.ready and 1 or .45);g.rectangle('fill',x+9,y+9,3,h-18,2,2)
 text(g,'card',info.name,x+21,y+7,row.ready and ink or muted)
 text(g,'small',row.ready and row.story or 'Import ROM to visit',x+21,y+(overview and 27 or 32),muted)
 text(g,'small','GEN '..info.gen,x+w-55,y+11,info.color)
 if selected then color(g,aqua);g.circle('fill',x+w-17,y+h-13,3) end
end
local continents={
 {70,170,110,120,220,115,280,160,235,210,185,220,150,290,105,250},
 {195,295,260,320,270,390,240,470,215,430,210,360},
 {385,150,460,115,530,155,600,120,750,170,790,240,720,260,665,220,610,295,540,240,475,220},
 {440,245,510,255,545,315,505,405,465,365,440,305},
 {680,410,745,390,780,435,720,465},
}
local function inside(poly,x,y)
 local hit=false;local j=#poly-1
 for i=1,#poly,2 do
  local xi,yi,xj,yj=poly[i],poly[i+1],poly[j],poly[j+1]
  if (yi>y)~=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi then hit=not hit end
  j=i
 end
 return hit
end
local function backdrop(g)
 color(g,{.025,.065,.12});g.rectangle('fill',0,0,W,H,14,14)
 -- A quiet dotted map keeps the supplied card artwork in the foreground.
 color(g,{.10,.37,.43},.25)
 if not M.mapDots then
  M.mapDots={}
  for y=90,730,9 do for x=50,850,9 do
   for _,p in ipairs(continents)do if inside(p,x,y)then M.mapDots[#M.mapDots+1]={x,y};break end end
  end end
 end
 for _,p in ipairs(M.mapDots)do g.circle('fill',p[1],p[2],1.5)end
 for i=1,24 do local x=16+(i*173)%868;local y=18+(i*137)%710
  color(g,aqua,.16);g.circle('fill',x,y,3);color(g,aqua,.6);g.circle('fill',x,y,1)
 end
end
local function divider(g,y,label)
 color(g,{.16,.46,.49},.8);g.rectangle('fill',30,y+8,300,1);g.rectangle('fill',570,y+8,300,1)
 if M.fonts then g.setFont(M.fonts.small)end;color(g,muted);g.printf(label,330,y,240,'center')
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
 color(g,{.015,.035,.055},.90);g.rectangle('fill',0,0,w,h)
 g.translate(ox,oy);g.scale(scale,scale);fonts(g);backdrop(g)
 color(g,aqua);g.rectangle('fill',30,30,42,4,2,2)
 text(g,'body','REGION LINK',84,21,aqua)
 text(g,'title','Hoennto',30,48)
 local source=games[game.session.version]
 text(g,'body','FROM '..source.name:upper()..' / '..source.region:upper(),235,68,muted)
 -- Teal orbital rings echo the reference's illuminated link emblem.
 color(g,aqua,.15);g.circle('fill',831,59,28)
 color(g,aqua,.65);g.setLineWidth(1);g.circle('line',831,59,25)
 ball(g,831,59,source.color)
 color(g,{.18,.43,.48});g.rectangle('fill',30,108,840,1)
 if s.mode=='choose' or s.mode=='overview' then
  divider(g,122,'GEN I');divider(g,282,'GEN II');divider(g,442,'GEN III');divider(g,602,'GEN III (REMAKES)')
  for n,row in ipairs(s.rows) do card(g,row,n,s.mode=='choose' and s.index==n,s.mode=='overview')end
 elseif s.mode=='confirm' then
  text(g,'body','Ready to depart?',30,142,aqua)
  local info=games[s.target]
  -- The same supplied cartridge artwork identifies the confirmation target.
  g.push();g.translate(280,70);card(g,s.rows[s.index],1,false,false);g.pop()
  text(g,'body','Your current game saves before departure.',145,412)
  text(g,'body','Compatible Pokemon travel with you.',145,456,aqua)
  if M.fonts then g.setFont(M.fonts.body)end;color(g,muted)
  g.printf('Unsupported species, moves, held items and storage overflow stay in campaign reserve until a compatible destination is available.',145,506,610)
  text(g,'small','Each cartridge keeps its own story, badges and bag.',145,626,muted)
 else
  text(g,'body','Before you travel',30,142,aqua)
  paragraphs(s,g);if M.fonts then g.setFont(M.fonts.body)end;color(g,ink)
  g.printf(s.pages[s.page],145,210,610)
  if #s.pages>1 then text(g,'small','PAGE '..s.page..' / '..#s.pages..'  -  LEFT / RIGHT',145,680,aqua)end
 end
 if s.mode=='choose' or s.mode=='overview' then
  text(g,'body','RESERVE: '..tostring(state(game).reserveCount or 0)..' POKEMON',30,772,aqua)
  text(g,'small',s.mode=='choose' and 'D-PAD: CHOOSE / TAP A CARD' or 'ONE TRAINER. INDEPENDENT PROGRESS.',565,778,muted)
 end
 local action=s.mode=='confirm' and 'A   TRAVEL' or s.mode=='notice' and s.page<#s.pages and 'A   NEXT PAGE' or (s.mode=='notice' or s.mode=='overview') and 'A   CLOSE' or 'A   SELECT'
 color(g,{.17,.52,.44});g.rectangle('fill',30,806,408,42,10,10)
 color(g,{.11,.18,.24});g.rectangle('fill',462,806,408,42,10,10)
 text(g,'body',action,52,816);text(g,'body',s.mode=='overview' and 'B   CLOSE' or 'B   CANCEL',484,816,muted)
 g.pop()
 if game.touchControls and game.touchControls.draw then game.touchControls:draw() end
end
return M
end
