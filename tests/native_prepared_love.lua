local project=assert(os.getenv('HOENNTO_PROJECT'))
local engine=assert(os.getenv('HOENNTO_ENGINE'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
function love.load()
 local ok,err=xpcall(function()
  bit=require('bit')
  local GV=require('src.core.GameVersion');GV.set('firered')
  local P=assert(loadfile(project..'/prepared_content.lua'))()
  local _,cache=require('src.mods.ImportAccess').new({id='kanto_hoenn'},love.filesystem)
  local Codec=require('src.core.SaveSerializer')
  local hash=function(s)return love.data.encode('string','hex',love.data.hash('sha256',s))end
  local versions={'firered','leafgreen','emerald'}
  local sourceReads=0
  local function source(v)
   local root=os.getenv('HOENNTO_IMPORTS')..'/'..v
   local F=require('src.import.gba.file_io').makeCache(root)
   return {identity=assert(F:read('data/generated/gba/meta.json')),
    list=function()
     local out={}
     local SD=require('src.core.SaveData')
     local function walk(path)
      for _,n in ipairs(SD.listNative(root..'/'..path))do
       local rel=path..'/'..n;local info=SD.statNative(root..'/'..rel)
       if info.type=='directory'then walk(rel)else out[#out+1]=rel end
      end
     end
     walk('data/generated');walk('assets/generated');return out
    end,
    read=function(_,p)sourceReads=sourceReads+1;return F:read(p)end}
  end
  local encode=require('src.import.CacheBlob').encode
  local prepared=P.prepare(cache,Codec,hash,versions,source,nil,encode)
  assert(sourceReads>0)
  sourceReads=0;P.prepare(cache,Codec,hash,versions,source);assert(sourceReads==0)
  -- Reopen solely from the completed installation cache, then mount with the
  -- exact production GameVersion prefix router. No source imports remain.
  local Contract=require('src.import.CacheContract');local ready=Contract.isReady
  Contract.isReady=function()return false end
  local state=P.install({cache=cache},versions);Contract.isReady=ready
  local Fs=require('src.import.CacheFs')
  local total=0
  for _,v in ipairs(versions)do
   Fs.unmountVersion(GV.get());GV.set(v);Fs.prefix=GV.cachePrefix(v);Fs.mountVersion(v)
   assert(GV.cachePrefix(v):match('^mod_cache/kanto_hoenn/prepared/'..v..'/'))
   local manifest=assert(Fs.readActive('data/generated/gba/native/manifest.lua'))
   local scripts=assert(Fs.readActive('data/generated/gba/scripts/scripts.lua'))
   local sprite=assert(Fs.readActive('data/generated/gba/ow/16.rgba'))
   assert(#sprite>100 and #scripts>1000 and #manifest>1000)
   assert(require('src.import.CacheBlob').decode('16.rgba',love.filesystem.read('data/generated/gba/ow/16.rgba'))==sprite,'Native mount did not expose prepared graphics')
   local audio=assert(Fs.readActive('data/generated/gba/audio/songs.lua'))
   assert(love.filesystem.read('data/generated/gba/audio/songs.lua')==audio,'Native worker audio root differs')
   local Versions=require('src.import.gba.versions');Versions.selectCache(v,require('src.core.game3.dataset').cache())
   local D=require('src.core.game3.dataset');D.invalidateManifestCache()
   local maps=D.buildMaps();D.attachMidLayouts(maps,D.cache())
   local id=v=='emerald' and 'EM_ROUTE104' or 'FR_VERMILION_CITY'
   assert(maps[id].midLayout)
   local n=0;for _ in pairs(maps)do n=n+1 end;total=total+n
   print('PASS NATIVE PREPARED',v,n,#sprite,#audio)
  end
  state:close()
  assert(GV.cachePrefix('firered')=='firered/')
  print('PASS SOURCE-FREE NATIVE MOUNTS',total)
 end,debug.traceback)
 if not ok then print('FAIL',err)end
 love.event.quit(ok and 0 or 1)
end
