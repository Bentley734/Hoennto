local root=assert(arg[1])
local C=assert(loadfile(root..'/campaign.lua'))()
local encode=assert(loadfile(root..'/save_encoder.lua'))()
local native=require('src.core.SaveSerializer')
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local samples={{},{party={},name='gary',flags={[1]=true}}, {['bad key']='quoted"\n\\\0', [0]=false, [15]=1.25}, {nested={{a=1},{b='Ã©'},{}},negative=-12}}
math.randomseed(901)
for i=1,100 do
 local sample={party={},dex={},name='TRAVELER '..i}
 for j=1,20 do sample.party[j]={id=j,hp=math.random(1,200),moves={1,2,3,4},metadata={name='MON '..j,alive=j%2==0}};sample.dex[j]=true end
 samples[#samples+1]=sample
end
for _,sample in ipairs(samples)do
 local bytes=encode(sample)
 eq(bytes,native.encode(sample),'cooperative writer is byte-identical to native grammar')
 local parsed=assert(native.decode(bytes))
 eq(native.encode(parsed),bytes,'native reader accepts the cooperative writer')
end
local huge={};for i=1,5000 do huge[i]={id=i,moves={1,2,3,4}}end
local pulses=0
local bytes=encode(huge,function()pulses=pulses+1 end)
eq(bytes,native.encode(huge),'large campaign has identical save bytes')
eq(pulses>100,true,'CPU-only serialization refreshes throughout its traversal')
local copyPulses=0;C.progress=function()copyPulses=copyPulses+1 end
local copied=C.copy(huge);C.progress=nil
eq(copyPulses>100,true,'large campaign copying has cooperative presentation checkpoints')
eq(native.encode(copied),bytes,'copy checkpoints preserve the complete campaign')
eq(pcall(encode,{bad=function()end}),false,'unsupported values never reach native disk writing')
-- All eleven linked slots stay current after arrival, but the departure
-- checkpoint does not redundantly rewrite ten peers first.
local writes=0
package.loaded['src.core.SaveData']={writeSlot=function()writes=writes+1;return true end}
local B=assert(loadfile(root..'/travel.lua'))()(C,{})
local raw={version='red',modData={}}
local state={version=C.VERSION,slots={},regions={},shared=C.shared({version='red',player={}})}
for _,v in ipairs(C.ORDER)do state.slots[v]=v;state.regions[v]=C.snapshot({version=v,player={},modData={}})end
raw.modData[C.KEY]=state
local game={_hoenntoDepartureSave=true}
B.afterSave(game,raw);eq(writes,0,'source checkpoint skips redundant peer saves')
game._hoenntoDepartureSave=nil
B.afterSave(game,raw);eq(writes,10,'arrival still refreshes every peer save')
local SD=package.loaded['src.core.SaveData']
SD.getCart=function()end;SD.activeSlot=function()return 1 end
SD.setActiveSlot=function()end;SD.loadOptions=function()return {}end
SD.setModEnabled=function()end
B.available=function()return true end;B.compatibility=function()return {}end
B.captureWildOptions=function()end;B.applyWildOptions=function()end
game={session=raw,save=raw,options={},quickSaveAllowed=function()return true end}
local sourceWrites=0;writes=0
game.saveGame=function(self)
 eq(self._hoenntoDepartureSave,true,'departure suppression is limited to the source save')
 sourceWrites=sourceWrites+1;B.prepareSave(self,raw);self.save=raw
 B.afterSave(self,raw);return true
end
local payload=assert(B.prepare(game,'gold'))
eq(sourceWrites,1,'travel still writes its source checkpoint exactly once')
eq(payload.state.active,'red','payload retains the durable source campaign')
eq(writes,0,'actual departure path does not write peers redundantly')
eq(game._hoenntoDepartureSave,nil,'suppression cleared before runtime release')
game.saveGame=function()error('checkpoint write failed')end
eq(pcall(B.prepare,game,'gold'),false,'source checkpoint exceptions still abort departure')
eq(game._hoenntoDepartureSave,nil,'source write failure clears suppression')
game.saveGame=function()return false end
eq(B.prepare(game,'gold'),nil,'failed source save still cancels travel')
eq(game._hoenntoDepartureSave,nil,'false save result clears suppression')
-- Registry indexes must be rebuilt between projections, including in-place
-- expanded-dex registry edits and temporary conversion errors.
local rows={A={id='A',name='Alpha'}}
local data={pokemon=rows,moves={TACKLE={id='TACKLE'}},items={}}
local R=assert(loadfile(root..'/roster.lua'))()(C,function()return {data=data}end)
local function projection(species)
 return {shared={name='ASH'},collection={records={{id=1,version='gold',species=species,moves={'TACKLE'},forms={},party=true,
  mon={species='A',name='ALPHA',moves={{id='TACKLE',pp=35}}}}},dex={seen={},owned={}}}}
end
local output={version='gold'}
R.project(output,projection('Alpha'));eq(output.party[1].species,'A','registry display-name alias resolves')
rows.B={id='B',name='Beta'}
R.project(output,projection('Beta'));eq(output.party[1].species,'B','in-place registry expansion is visible on next projection')
eq(pcall(R.project,output,projection('Missing')),false,'incompatible party still fails safely')
rows.C={id='C',name='Gamma'}
R.project(output,projection('Gamma'));eq(output.party[1].species,'C','failure cannot retain stale projection indexes')
local resolve=R.resolve;local calls=0
R.resolve=function(...)calls=calls+1;return resolve(...)end
R.project(output,projection('Alpha'));eq(calls>0,true,'companion-provided resolver stays active')
print('Travel optimization / native save-byte parity / peer refresh checks',checks)
