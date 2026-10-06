-- Actual stock audio worker owner; a fake named-channel worker exposes competing
-- consumers by rejecting a second start and a wait without the quit command.
local root=arg[1]
require('src.core.GameVersion').set('emerald')
local Mount=assert(loadfile(root.."/mount_lifecycle.lua"))()
local retired=setmetatable({},{__mode="v"})
local channels={};local living=0;local starts=0;local joins=0
local function channel(name)
 if not channels[name]then channels[name]={q={},push=function(c,x)c.q[#c.q+1]=x end,clear=function(c)c.q={}end,pop=function(c)return table.remove(c.q,1)end}end
 return channels[name]
end
love={thread={getChannel=channel,newThread=function()
 return {start=function()assert(living==0,'two audio workers share named channels');living=1;starts=starts+1 end,
 wait=function()local quit=false;for _,cmd in ipairs(channel('game3_m4a_cmd').q)do if cmd.cmd=='quit'then quit=true end end
 assert(quit,'wait would freeze without quit');living=0;joins=joins+1 end}
end}}
local shutdowns={}
package.loaded['src.core.SessionLifecycle']={registerProcessShutdown=function(fn)shutdowns[#shutdowns+1]=fn end}
package.loaded['src.core.game3.m4a_sample']={}
package.loaded['src.core.game3.m4a_mix']={}
package.loaded['src.core.game3.m4a_player']={loadPack=function()return {index={}}end}
package.loaded['src.core.game3.se_ids']={}
package.loaded['src.core.game3.song_ids']={}
local checks=0;local function eq(a,b,msg)checks=checks+1;assert(a==b,msg)end
for i=1,80 do
 package.loaded['src.core.game3.audio']=nil
 local audio=Mount.load(function()return require('src.core.game3.audio')end)
 retired[i]=audio
 eq(audio.install({}),true,'region audio installed')
 eq(living,1,'one live audio worker')
 if i<80 then Mount.stopAudio();eq(living,0,'departing worker joined')end
end
eq(#shutdowns,1,'shutdown callback count stays constant through 80 loads')
collectgarbage('collect')
for i=1,79 do eq(retired[i],nil,'retired audio module is collectible')end
for _,fn in ipairs(shutdowns)do fn()end
local sentinel=function()end
local original=package.loaded['src.core.SessionLifecycle'].registerProcessShutdown
eq(pcall(function()Mount.load(function()package.loaded['src.core.SessionLifecycle'].registerProcessShutdown(sentinel);error('failed destination')end)end),false,'load failure propagated')
eq(package.loaded['src.core.SessionLifecycle'].registerProcessShutdown,original,'registration restored on load failure')
eq(shutdowns[#shutdowns],sentinel,'unrelated process callbacks preserved on failure')
eq(living,0,'process exit joins final worker')
eq(starts,80,'all regions start normally')
eq(joins,80,'all threads joined exactly once')
print('Actual audio lifecycle checks',checks)
