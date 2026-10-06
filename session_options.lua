-- Some native screens pass the already-bound flat session options to block().
-- Treat that exact live table as a block, rather than nesting another defaults
-- block inside it (which ensure() would subsequently mistake for an engine).
return function(getSession)
  -- Gen 3 options/profile read mounted cartridge data as they load. Never
  -- initialize them while a Gen 1 or 2 cartridge owns the runtime.
  if require('src.core.GameVersion').generation()~=3 then return false end
  local Options=require('src.core.game3.options')
  local installed=Options._hoenntoBlockGuard
  if installed then
    installed.getSession=getSession
    return true
  end
  local raw=Options.block
  installed={getSession=getSession}
  Options._hoenntoBlockGuard=installed
  Options.block=function(engine,blockId)
    local session=installed.getSession()
    if blockId==nil and type(engine)=='table' and session and engine==session.options
        and engine~=session.engineOptions then
      return Options.ensure(session)
    end
    return raw(engine,blockId)
  end
  return true
end
