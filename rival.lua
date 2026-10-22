-- RSE reads the rival from ROM gender placeholders and trainer constants.
-- Override presentation only for Hoennto-owned destination stories. Never
-- rewrite ROM datasets or rename Wally, champions, or unrelated trainers.
return function(C,getGame)
 local R={}
 local function current()
  local game=getGame();local raw=game and game.session
  if not raw or (raw.version~='ruby' and raw.version~='sapphire' and raw.version~='emerald') then return end
  return C.linkedRival(raw),raw.version
 end
 function R.install(game)
  if game and game.generation==2 then
   local World=require('src.world.gen2.World')
   World._hoenntoCampaign=C
   if not World._hoenntoRivalWrapped then
    World._hoenntoRivalWrapped=true
    local native=World.nameRival
    World.nameRival=function(self,onDone)
     local campaign=World._hoenntoCampaign
     local raw=self.game and self.game.save
     local name=raw and campaign.linkedRival(raw)
     if name then
      campaign.applyRival(raw)
      if onDone then onDone(name) end
      return
     end
     return native(self,onDone)
    end
   end
   return
  end
  if not game or game.generation~=3 then return end
  local Text=require('src.core.game3.scripting.text_ir')
  Text._hoenntoRivalLookup=current
  if not Text._hoenntoRivalWrapped then
   Text._hoenntoRivalWrapped=true
   local native=Text.placeholdersFor
   Text.placeholdersFor=function(ctx)
    local value=native(ctx);local name=Text._hoenntoRivalLookup()
    if not name then return value end
    local out=C.copy(value or {});out.byGender=out.byGender or {}
    out.byGender.RIVAL={male=name,female=name}
    return out
   end
  end
  local Trainers=require('src.core.game3.scripting.trainers')
  local Constants=require('src.core.game3.constants')
  Trainers._hoenntoRivalLookup=current
  if not Trainers._hoenntoRivalWrapped then
   Trainers._hoenntoRivalWrapped=true
   local function rename(row,id,field)
    local name,version=Trainers._hoenntoRivalLookup()
    if row and name then
     local key=Constants.of(version):name('trainers',tonumber(id),'TRAINER_')
     if key and (key:match('^TRAINER_BRENDAN_') or key:match('^TRAINER_MAY_')) then row[field]=name end
    end
    return row
   end
   local info,foe=Trainers.info,Trainers.foeFromId
   Trainers.info=function(id,opts)return rename(info(id,opts),id,'name')end
   Trainers.foeFromId=function(id)return rename(foe(id),id,'trainerName')end
  end
 end
 return R
end
