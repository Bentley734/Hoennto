-- Audio registers a process-exit closure on every cartridge load. Keep a
-- single forwarding callback rather than retaining every old module forever.
local M={}
function M.load(fn)
  local L=require('src.core.SessionLifecycle')
  local register=L.registerProcessShutdown
  if not register then return fn() end
  local pending={}
  L.registerProcessShutdown=function(callback)pending[#pending+1]=callback end
  local ok,result=pcall(fn)
  L.registerProcessShutdown=register
  local audioOk,audio=false,nil
  if require('src.core.GameVersion').generation()==3 then audioOk,audio=pcall(require,'src.core.game3.audio') end
  for _,callback in ipairs(pending) do
    if audioOk and callback==audio.shutdown then
      L._kantoHoennAudioShutdown=callback
      if not L._kantoHoennAudioDispatcher then
        L._kantoHoennAudioDispatcher=true
        register(function()
          local current=L._kantoHoennAudioShutdown
          if current then current() end
        end)
      end
    else
      register(callback)
    end
  end
  if not ok then error(result) end
  return result
end
function M.stopAudio()
  local L=require('src.core.SessionLifecycle')
  if require('src.core.GameVersion').generation()==3 then require('src.core.game3.audio').shutdown() end
  L._kantoHoennAudioShutdown=nil
end
return M
