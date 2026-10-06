# Transfer extension contract

After Hoennto loads, its transfer API is available through `game.mods.exports.kanto_hoenn.transfer`.

Public extension points: `name(kind, nativeId, generation)`, `resolve(kind, canonicalName, generation)` and normalization helper `key(name)`. Kinds: `species`, `moves`, `items`. Generations: 1, 2, 3.

Resolvers read the mounted cartridge's live registries. 1025Dex can extend those directly or wrap the functions, delegating ordinary records to the originals:

```lua
local t = game.mods.exports.kanto_hoenn.transfer
local oldName, oldResolve = t.name, t.resolve
function t.name(kind, id, gen)
  return myCanonicalName(kind, id, gen) or oldName(kind, id, gen)
end
function t.resolve(kind, name, gen)
  if isMyCustomName(kind, name) then
    return myDestinationId(kind, name, gen) -- nil means unsupported
  end
  return oldResolve(kind, name, gen)
end
```

Use stable unique canonical names. Native IDs must match destination engine data structures; distinguish forms and gendered species without collisions after `key` normalization. Do not use fixed 151/251/386 ceilings or replace unsupported species with another species. Same-generation routes also resolve against destination registries.

Install mappings and native stats/learnsets/dex data before projection. Hoennto's `save.loading` priority is -100000; use a handler with a higher numerical priority and ensure the export exists before wrapping. Reinstall wrappers when native mod loading creates new instances. Declare all eleven game targets and enable the companion at both endpoints.

`capture`, `project` and `convert` are exposed for inspection/tests but own campaign mutation. Do not mutate records, `_hoenntoId`, archived forms or projected-ID sets. Campaign format 2 is internal. Reserve survives until destination support and capacity permit projection.

