local root=arg[1]
local C=assert(loadfile(root..'/campaign.lua'))()
local Serializer=require('src.core.SaveSerializer')
local checks=0;local function eq(a,b,msg)checks=checks+1;assert(a==b,msg)end
local function raw(v)return {engine='game3',version=v,map=v..'_TOWN',name='JOHN',party={{species=25,exp=100,hp=10}},storage={boxes={{mons={{species=1}}}},items={}},dex={seen={[25]=true}},flags={story=v},modData={}}end
local state=C.capture(raw('firered'));C.capture(raw('emerald'),state)
state.slots={firered='slot1',emerald='slot2'}
local initial=#Serializer.encode(state)
for i=1,100 do
 local version=i%2==0 and 'firered' or 'emerald'
 local arriving=C.restore(state,version)
 arriving.party[1].exp=100+i
 local previous=state;local oldShared=state.shared;local oldRegions=state.regions
 local nextState=C.captureState(state)
 C.capture(arriving,nextState)
 eq(previous.shared,oldShared,'previous checkpoint shared identity untouched')
 eq(previous.regions,oldRegions,'previous checkpoint regions identity untouched')
 eq(oldShared.party[1].exp,99+i,'previous checkpoint party unchanged')
 eq(nextState.shared.party[1].exp,100+i,'latest roster captured')
 eq(nextState.regions[version].flags.story,version,'regional story preserved')
 eq(nextState.regions[version].modData[C.KEY],nil,'snapshot has no nested campaign')
 eq(nextState.regions[version].storage.boxes,nil,'roster stored only once in campaign')
 assert(#Serializer.encode(nextState)<initial+100,'campaign save grows with each trip')
 checks=checks+1
 state=nextState
end
print('Repeated campaign capture checks',checks)
