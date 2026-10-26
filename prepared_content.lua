-- Installation-owned native content for all eleven cartridges. Save paths
-- and campaign identifiers remain native; only generated-asset roots move.
local P={FORMAT=3}
function P.prepare(cache,codec,hash,versions,source,progress,encode)
  local result={}
  for _,v in ipairs(versions)do
    local input=source(v)
    local statusPath='prepared/'..v..'/active.lua'
    local function statusAt(path)
      local ok,row=pcall(codec.decode,cache:read(path) or '')
      if not ok or type(row)~='table' or row.format~=P.FORMAT or row.version~=v
        or type(row.source)~='string' or type(row.root)~='string' then return nil end
      local id=row.root:match('^prepared/'..v..'/([a-f0-9]+)/$')
      if not id or #id~=32 then return nil end
      return row
    end
    local status=statusAt(statusPath) or statusAt(statusPath..'.previous')
    if input and (not status or status.source~=input.identity)then
      local paths=input:list();table.sort(paths)
      local rows={}
      for _,path in ipairs(paths)do
        assert(type(path)=='string' and path~='' and not path:find('[%z\\:]') and path:sub(1,1)~='/' and not path:find('//',1,true),'Invalid imported path')
        for part in path:gmatch('[^/]+')do assert(part~='.' and part~='..','Invalid imported path')end
        rows[#rows+1]=path
      end
      local id=hash(codec.encode({format=P.FORMAT,version=v,identity=input.identity,paths=rows}))
      assert(id:match('^[a-f0-9]+$') and #id==64,'Expected SHA256 identity')
      -- 128-bit directory identity keeps long Emerald native filenames within
      -- Windows MAX_PATH. The completion record also checks the full source identity.
      local root='prepared/'..v..'/'..id:sub(1,32)..'/'
      for i,path in ipairs(paths)do
        local bytes=assert(input:read(path),'Missing imported file: '..v..'/'..path)
        if encode then bytes=encode(path,bytes)end
        if cache:read(root..path)~=bytes then
          local written,err=cache:write(root..path,bytes)
          assert(written,'Unable to prepare '..v..' content ('..path..'): '..tostring(err))
          assert(cache:read(root..path)==bytes,'Content verification failed: '..v..'/'..path)
        end
        if progress then progress(v,i,#paths)end
      end
      status={format=P.FORMAT,version=v,source=input.identity,root=root,files=#paths}
      -- Publish after all files, including the engine's completion marker.
      local body=codec.encode(status)
      local previous=statusAt(statusPath) or statusAt(statusPath..'.previous')
      if previous then
        local backup=codec.encode(previous)
        assert(cache:write(statusPath..'.previous',backup),'Unable to protect previous prepared content')
        assert(cache:read(statusPath..'.previous')==backup,'Prepared backup verification failed')
      end
      assert(cache:write(statusPath,body),'Unable to publish prepared content')
      assert(cache:read(statusPath)==body,'Prepared completion record failed verification')
    end
    if status then result[v]=status end
  end
  return result
end
function P.install(mod,versions)
  local GV=require('src.core.GameVersion')
  if GV._hoenntoPrepared then return GV._hoenntoPrepared end
  local Fs=require('src.import.CacheFs')
  local SD=require('src.core.SaveData')
  local Contract=require('src.import.CacheContract')
  local codec=require('src.core.SaveSerializer')
  local disk=assert(SD.persistenceFs(),'Content storage is unavailable')
  local original=GV.cachePrefix
  local function source(v)
    if not Contract.isReady(v,Fs)then return nil end
    local prefix=original(v)
    local marker=Fs.readAt(prefix..Contract.MARKER_PATH)
    if not marker then return nil end
    local metadata=Fs.readAt(prefix..'data/generated/gba/meta.json') or ''
    local s={identity=marker..'\n'..metadata}
    function s:read(path)return Fs.readAt(prefix..path)end
    function s:list()
      local paths={Contract.MARKER_PATH}
      local function walk(path,depth)
        assert(depth<32,'Imported content nesting is excessive')
        for _,name in ipairs(disk.getDirectoryItems(prefix..path))do
          assert(name~='.' and name~='..' and not name:find('[/\\]'),'Invalid imported filename')
          local rel=path..'/'..name
          local info=disk.getInfo(prefix..rel)
          if info and info.type=='directory'then walk(rel,depth+1)
          elseif info and info.type=='file'then paths[#paths+1]=rel end
        end
      end
      for _,root in ipairs({'data/generated','assets/generated'})do
        local info=disk.getInfo(prefix..root)
        if info and info.type=='directory'then walk(root,0)end
      end
      return paths
    end
    return s
  end
  local last=0
  local function progress(v,i,n)
    local now=love.timer.getTime();if now-last<.1 then return end;last=now
    local g=love.graphics;local w,h=g.getDimensions()
    g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor()
    g.clear(.04,.07,.12,1);g.setColor(1,1,1,1)
    g.printf('HOENNTO\n\nPreparing '..v..' ('..i..' / '..n..')\nPrepared games are reused on future visits.',20,h/2-40,w-40,'center')
    g.present();g.pop()
    local Host=require('src.core.HostShell');if Host.pumpHostEvents then Host.pumpHostEvents()end
  end
  local function hash(bytes)return love.data.encode('string','hex',love.data.hash('sha256',bytes))end
  local prepared=P.prepare(mod.cache,codec,hash,versions,source,progress,require('src.import.CacheBlob').encode)
  local state={prepared=prepared,original=original}
  local function routed(v)
    v=v or GV.get()
    local row=prepared[v]
    return row and ('mod_cache/kanto_hoenn/'..row.root) or original(v)
  end
  -- Existing overlays must leave under their original identity.
  local active=GV.get()
  if prepared[active]then Fs.unmountVersion(active)end
  GV.cachePrefix=routed;GV._hoenntoPrepared=state
  if prepared[active]then Fs.prefix=routed(active);Fs.mountVersion(active)end
  function state:close()
    if GV.cachePrefix~=routed then return end
    local current=GV.get()
    Fs.unmountVersion(current)
    GV.cachePrefix=original;GV._hoenntoPrepared=nil;Fs.prefix=original(current)
  end
  return state
end
return P
