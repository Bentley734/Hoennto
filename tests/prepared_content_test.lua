local P=assert(loadfile(arg[1]..'/prepared_content.lua'))()
local Codec=require('src.core.SaveSerializer')
local order=assert(loadfile(arg[1]..'/campaign.lua'))().ORDER
local bytes,reads,fail={},0,nil
local cache={read=function(_,p)return bytes[p]end,write=function(_,p,b)
 if p==fail then return nil,'disk full'end;bytes[p]=b;return true end}
-- Stable 256-bit fixture digest; production supplies LÖVE SHA256.
local function hash(s)local n=0;for i=1,#s do n=(n*31+s:byte(i))%4294967296 end;return string.rep(string.format('%08x',n),8)end
local identities={};for _,v in ipairs(order)do identities[v]=v..'-revision-1'end
local function source(v)
 if not identities[v]then return nil end
 return {identity=identities[v],list=function()return {'rom-cache.complete','data/generated/maps.lua','assets/generated/sprite.bin'}end,
 read=function(_,p)reads=reads+1;return v..'/'..p end}
end
local first=P.prepare(cache,Codec,hash,order,source)
assert(reads==33)
for _,v in ipairs(order)do
 assert(first[v].files==3 and first[v].version==v)
 assert(bytes[first[v].root..'data/generated/maps.lua']==v..'/data/generated/maps.lua')
end
reads=0
P.prepare(cache,Codec,hash,order,source)
assert(reads==0,'Warm launch must not read or copy source assets')
identities.gold=nil
local missing=P.prepare(cache,Codec,hash,order,source)
assert(missing.gold.root==first.gold.root,'Prepared game must survive missing source import')
identities.blue='blue-revision-2';reads=0
local changed=P.prepare(cache,Codec,hash,order,source)
assert(reads==3 and changed.blue.root~=first.blue.root,'Only changed imports should rebuild')
assert(#first.emerald.root:match('/([a-f0-9]+)/$')==32,'Prepared directory must use the compact identity')
local old=bytes['prepared/red/active.lua'];identities.red='red-revision-2';fail='prepared/red/active.lua'
assert(not pcall(P.prepare,cache,Codec,hash,order,source))
assert(bytes['prepared/red/active.lua']==old,'Failed publication must preserve the previous prepared game')
fail=nil
local long='data/generated/gba/native/general__battle_frontier_outside_east/anim_battle_frontier_outside_east_flag_over.idx'
local bounded={read=function(_,p)return bytes[p]end,write=function(_,p,b)
 assert(#('C:/Users/LSDMTHC/AppData/Roaming/pokemon-love2d/mod_cache/kanto_hoenn/'..p)<260,'Windows path limit exceeded')
 bytes[p]=b;return true end}
P.prepare(bounded,Codec,hash,{'emerald'},function()return {identity='long-path',list=function()return {long}end,read=function()return 'fixture'end}end)
print('Prepared native content: all 11 identities, warm reuse, missing imports, changed imports and failed publication passed')
-- Prepared roots must reach all native loaders/mounts without changing save
-- versions. No generation-specific runtime is required during preparation.
local GV=require('src.core.GameVersion');GV.set('red')
local original=GV.cachePrefix
local SD=require('src.core.SaveData');SD.persistenceFs=function()return {}end
package.loaded['src.import.CacheContract']={isReady=function()return false end}
local F=require('src.import.CacheFs')
local unmounts,mounts={},{}
F.unmountVersion=function(v)unmounts[#unmounts+1]=GV.cachePrefix(v)end
F.mountVersion=function(v)mounts[#mounts+1]=GV.cachePrefix(v)end
fail=nil
local state=P.install({cache=cache},order)
assert(unmounts[1]=='red/' and mounts[1]:match('^mod_cache/kanto_hoenn/prepared/red/'))
for _,v in ipairs(order)do assert(GV.cachePrefix(v):match('^mod_cache/kanto_hoenn/prepared/'..v..'/'))end
assert(P.install({cache=cache},order)==state,'Travel reload must reuse the live preparation owner')
state:close()
assert(GV.cachePrefix==original and not GV._hoenntoPrepared)
print('Prepared root routing: 11 native roots, reload ownership and exit restoration passed')
