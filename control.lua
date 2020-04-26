--control.lua

require "lualib/extensions"
require "config"

local TrainDepot = require "models/TrainDepot"
local TrainCounter = require "models/TrainCounter"

script.on_configuration_changed(function (event)
  local train_depot_changes = event.mod_changes["TrainDepot"]
  if train_depot_changes then
    local old_version = train_depot_changes.old_version
    if old_version == "0.1.0" or old_version == "0.1.1" then
      for _, force in pairs(game.forces) do
        force.reset_technology_effects()
      end
    end
  end
end)

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
  local entity = event.created_entity
  if not entity then
    return
  end
  local entity_name = (entity.name or "")
  util.print(entity_name .. " placed, unit number: " .. (entity.unit_number or "-"))

  if entity_name == "train-depot" then
    local train_depot = TrainDepot.new(entity):serialize()
    global.train_depots = global.train_depots or {}
    table.insert(global.train_depots, train_depot)
    -- util.print("now tracking unit number: " .. entity.unit_number .. " serialized: " .. table.tostring(train_depot))
  elseif entity_name == "train-counter" then
    local train_counter = TrainCounter.new(entity):serialize()
    global.train_counters = global.train_counters or {}
    table.insert(global.train_counters, train_counter)
    -- util.print("now tracking unit number: " .. entity.unit_number .. " serialized: " .. table.tostring(train_depot))
  end
end)

script.on_event({defines.events.on_marked_for_deconstruction}, function(event)
  local entity = event.created_entity
  if not entity then
    return
  end
  local entity_name = (entity.name or "")

  if entity_name == "train-depot" then
    local index, depot = TrainDepot.find_using_entity(global.train_depots, entity)
    if depot then
      depot.paused = true
    end
  end
end)

script.on_event({defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died}, function(event)
  local entity = event.created_entity
  if not entity then
    return
  end
  local entity_name = (entity.name or "")

  if entity_name == "train-depot" then
    local index, depot = TrainDepot.find_using_entity(global.train_depots, entity)
    if index > 0 then
      depot:destroy()
      table.remove(global.train_depots, index)
    end
  elseif entity_name == "train-counter" then
    local index, counter = TrainCounter.find_using_entity(global.train_counters, entity)
    if index > 0 then
      counter:destroy()
      table.remove(global.train_counters, index)
    end
  end
end)

script.on_event({defines.events.on_player_setup_blueprint}, function(event)
  local player_index = event.player_index
  local player = game.players[player_index]
  local blueprint = player.blueprint_to_setup
  local entities = blueprint.get_blueprint_entities() or {}
  local entities_to_remove = {}
  for index, entity in ipairs(entities) do
    if entity.name == "train-depot-storage" then
      table.insert(entities_to_remove, index)
    end
  end
  table.sort(entities_to_remove, function(a,b) return a>b end)
  for i, index in ipairs(entities_to_remove) do
    table.remove(entities, index)
  end

  blueprint.set_blueprint_entities(entities)
end)

local function updateTrainCounters(ticks)
  if not global.train_counters then return end

  local for_removal = {}

  for index, counter_data in ipairs(global.train_counters) do
    local counter = TrainCounter.deserialize(counter_data)
    local valid = counter:update(ticks)
    if valid then
      global.train_counters[index] = counter:serialize()
    else
      table.insert(for_removal, index)
    end
  end

  for _, index in ipairs(for_removal) do
    local counter = global.train_counters[index]
    counter:destroy()
    table.remove(global.train_counters, index)
  end
end

local function updateTrainDepots(ticks)
  if not global.train_depots then return end

  local selected = game.players[1].selected
  if _CONFIG._DEBUG and selected then
    util.print("selected [" .. selected.name .. "]: " .. table.tostring(selected.position))
  end

  local for_removal = {}

  for index, depot_data in ipairs(global.train_depots) do
    local depot = TrainDepot.deserialize(depot_data)
    local valid = depot:update(ticks)
    if valid then
      global.train_depots[index] = depot:serialize()
    else
      table.insert(for_removal, index)
    end
  end

  for _, index in ipairs(for_removal) do
    local train_depot = global.train_depots[index]
    train_depot:destroy()
    table.remove(global.train_depots, index)
  end
end

script.on_event({defines.events.on_tick}, function(event)
  if event.tick % _CONFIG._UPDATE_COUNTERS_TICKS == 1 then
    updateTrainCounters(_CONFIG._UPDATE_COUNTERS_TICKS)
  end
  if event.tick % _CONFIG._UPDATE_DEPOTS_TICKS == 2 then
    updateTrainDepots(_CONFIG._UPDATE_DEPOTS_TICKS)
  end
end)


