-- Match the native deterministic save grammar, with presentation-only work
-- checkpoints. SaveData still owns validation, temporary writes and recovery.
return function(data,pulse)
 local work=0
 local function checkpoint()
  work=work+1
  if pulse and work%256==0 then pulse(false) end
 end
 local function serialize(v,indent)
  checkpoint();indent=indent or 0
  local t=type(v)
  if t=='number' or t=='boolean' then return tostring(v)
  elseif t=='string' then return string.format('%q',v)
  elseif t=='table' then
   local keys={}
   for k in pairs(v)do keys[#keys+1]=k;checkpoint()end
   table.sort(keys,function(a,b)
    local ta,tb=type(a),type(b)
    if ta~=tb then return ta<tb end
    return a<b
   end)
   if #keys==0 then return '{}' end
   local pad=string.rep('  ',indent);local parts={}
   for _,k in ipairs(keys)do
    local key
    if type(k)=='string' and k:match('^[%a_][%w_]*$') then key=k
    else key='['..serialize(k)..']'end
    parts[#parts+1]=pad..'  '..key..' = '..serialize(v[k],indent+1)
   end
   return '{\n'..table.concat(parts,',\n')..',\n'..pad..'}'
  end
  error('cannot serialize '..t)
 end
 -- The native writer disables recursive JIT traces to avoid GC corruption.
 -- Keep that same safeguard; the rest of the game retains its JIT settings.
 if jit and jit.off then jit.off(serialize,true)end
 return 'return '..serialize(data)..'\n'
end
