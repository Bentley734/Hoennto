-- Keep imported companions out of the native Pallet Town introduction.
-- Story flags, the party and follower preferences remain owned by their games.
return function(mod, getGame)
  local scene
  local function gen1(game)
    return game and game.generation == 1 and game.save and game.save.flags
  end
  local function removeGhosts(s)
    for _, list in ipairs({s.world.npcs or {}, s.world.entities or {}}) do
      for i = #list, 1, -1 do
        if list[i]._hoenntoRecall then table.remove(list, i) end
      end
    end
    s.ghosts = {}
  end
  local function finish()
    local s = scene
    if not s then return end
    scene = nil
    removeGhosts(s)
    if s.controller and s.controller.tick == s.tick then s.controller.tick = s.nativeTick end
  end
  local function recallGhost(actor, slot)
    local ghost = {}
    for k, v in pairs(actor) do ghost[k] = v end
    ghost._wildFollowersRewrite = nil
    ghost._hoenntoRecall = true
    ghost.id = 'hoennto_oak_recall_' .. slot
    ghost.def = { index = -slot, name = ghost.id }
    ghost.passable, ghost.fxOnly, ghost.pureFx = true, true, true
    ghost.moving, ghost.hidden = false, false
    ghost.update = function() end
    ghost.elapsed = 0
    local draw = actor.draw
    ghost.draw = function(self, camX, camY)
      local t = math.min(1, self.elapsed / .30)
      local gfx = love.graphics
      local x, y = self.px + 8 - camX, self.py + 12 - camY
      gfx.push('all')
      if t < .72 and draw then
        local scale = math.max(.01, 1 - t / .72)
        gfx.translate(x, y); gfx.scale(scale, scale); gfx.translate(-x, -y)
        draw(self, camX, camY)
        gfx.pop(); gfx.push('all')
      end
      local radius = 3 * math.min(1, t * 6)
      gfx.setColor(1, .22, .25, 1 - t)
      gfx.circle('fill', x, y - 4, radius)
      gfx.setColor(1, 1, 1, 1 - t)
      gfx.arc('fill', x, y - 4, radius, 0, math.pi)
      gfx.setColor(.12, .12, .15, 1 - t)
      gfx.circle('line', x, y - 4, radius)
      gfx.line(x - radius, y - 4, x + radius, y - 4)
      gfx.circle('fill', x, y - 4, 1)
      gfx.pop()
    end
    return ghost
  end
  local function attachController(s)
    local controller = s.world._wildFollowersRewriteOwner
    if not controller or controller.disposed or type(controller.tick) ~= 'function'
        or type(controller.clear) ~= 'function' or s.controller == controller then return end
    -- WildFollowers 3 exposes its live world owner. Earlier companions have
    -- a different runtime and must not be mistaken for this controller.
    if s.controller then return end
    local ghosts = {}
    for i, actor in ipairs(controller.followers or {}) do
      if not actor.hidden and actor._wildFollowersRewrite and type(actor.draw) == 'function' then
        ghosts[#ghosts + 1] = recallGhost(actor, i)
      end
    end
    s.controller, s.nativeTick = controller, controller.tick
    s.tick = function(self, ...)
      if scene == s then return end
      return s.nativeTick(self, ...)
    end
    controller.tick = s.tick
    controller:clear()
    s.ghosts = ghosts
    for _, ghost in ipairs(ghosts) do
      s.world.npcs[#s.world.npcs + 1] = ghost
      s.world.entities[#s.world.entities + 1] = ghost
    end
  end
  local function begin(game, world, y)
    if not gen1(game) or not world or not world.map or world.map.id ~= 'PALLET_TOWN' then return end
    local flags = game.save.flags
    local row = game.save.version == 'yellow' and 0 or 1
    if y ~= row or flags.EVENT_FOLLOWED_OAK_INTO_LAB or flags.EVENT_GOT_STARTER then return end
    if scene then return end
    scene = { game = game, save = game.save, world = world, ghosts = {} }
    attachController(scene)
  end
  local function keepOakScheduled(s)
    local world = s.world
    local name = world.map.id == 'PALLET_TOWN' and 'PALLETTOWN_OAK'
      or world.map.id == 'OAKS_LAB' and 'OAKSLAB_OAK2'
    if not name then return end
    for _, move in ipairs(world.scriptMoves or {}) do
      local oak = move.entity
      if oak and oak.def and oak.def.name == name
          and (oak.moving or (move.remaining or 0) > 0) then
        -- Script callbacks belong to this exact instance. A late people-list
        -- rebuild can leave its movement waiting on an NPC no longer updated.
        -- Restore that instance, preserving its path and completion callback.
        for _, list in ipairs({world.npcs, world.entities}) do
          local present = false
          for i = #list, 1, -1 do
            local npc = list[i]
            if npc == oak then present = true
            elseif npc.def and npc.def.name == name then table.remove(list, i) end
          end
          if not present then list[#list + 1] = oak end
        end
        if world.npcPool and oak.id then world.npcPool[oak.id] = oak end
      end
    end
  end
  -- The contribution also covers a save restored while standing on Oak's
  -- trigger row: freshBoot dispatches onStep without emitting world.stepped.
  if mod.generation == 1 and mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register('PALLET_TOWN', { priority = 100000,
      onStep = function(game, world, _, y) begin(game, world, y); return false end })
  end
  mod.events:on('world.stepped', function(ev)
    local game = getGame()
    if ev.mapId == 'PALLET_TOWN' and game then begin(game, game.overworld, ev.y) end
  end, 100000)
  mod.hooks:wrap('input.step', function(next_, game, dt)
    local s = scene
    if s then
      if not gen1(game) or game.save ~= s.save or game.overworld ~= s.world then finish()
      elseif game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON and game.stack:top() == s.world then finish()
      else
        attachController(s)
        keepOakScheduled(s)
        for _, ghost in ipairs(s.ghosts) do ghost.elapsed = ghost.elapsed + (dt or 1 / 60) end
        if #s.ghosts > 0 and s.ghosts[#s.ghosts].elapsed >= .30 then removeGhosts(s) end
      end
    end
    return next_(game, dt)
  end, 100000)
  mod.hooks:wrap('world.follower.spawn', function(next_, game, world)
    if scene and game.save == scene.save and world == scene.world then return false end
    return next_(game, world)
  end, 100000)
end
