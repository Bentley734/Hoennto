from pathlib import Path
import os,sys
from lupa.lua53 import LuaRuntime
import argparse
parser=argparse.ArgumentParser(description="Run Hoennto suites against a gen1recomp source checkout")
parser.add_argument('--engine',type=Path,required=True)
parser.add_argument('tests',nargs='*',help='Optional Lua test filenames')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
os.chdir(args.engine.resolve())
shim='''package.preload.bit=function()
local function n(v) return math.tointeger(v) or math.floor(v) end
local function signed(v) v=v&0xffffffff;if v>=0x80000000 then return v-0x100000000 end;return v end
local b={}
function b.band(a,...) local r=n(a);for _,v in ipairs({...})do r=r&n(v)end;return signed(r)end
function b.bor(a,...) local r=n(a);for _,v in ipairs({...})do r=r|n(v)end;return signed(r)end
function b.bxor(a,...) local r=n(a);for _,v in ipairs({...})do r=r~n(v)end;return signed(r)end
function b.bnot(a)return signed(~n(a))end
function b.lshift(a,n_)return signed(n(a)<<(n(n_)&31))end
function b.rshift(a,n_)return (n(a)&0xffffffff)>>(n(n_)&31)end
function b.arshift(a,n_)return signed(math.floor(signed(n(a))/2^(n(n_)&31)))end
function b.tobit(a)return signed(n(a))end
return b
end
bit=require('bit')
unpack=table.unpack
'''
paths=[root/'tests'/n for n in args.tests] if args.tests else sorted((root/'tests').glob('*_test.lua'))
failed=[]
for path in paths:
 if path.name=='kanto_hoenn_bridge_test.lua' and not os.environ.get('KANTO_HOENN_TEST_CACHE'):
  print('SKIP',path.name,'(no KANTO_HOENN_TEST_CACHE)',flush=True)
  continue
 for variant in (['firered','leafgreen'] if path.name=='kanto_hoenn_mod_test.lua' else ['firered']):
  lua=LuaRuntime(unpack_returned_tuples=True)
  lua.execute(shim)
  lua.globals().arg=lua.table_from({1:str(root),**({2:variant} if path.name=='kanto_hoenn_mod_test.lua' else {})})
  try:
   lua.execute("assert(loadfile(...))()",str(path))
   print('PASS',path.name,variant,flush=True)
  except Exception as e:
   print('FAIL',path.name,variant,str(e),flush=True)
   failed.append((path.name,variant))
print('FAILED',failed)
sys.exit(bool(failed))
