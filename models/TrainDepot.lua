require "util"
require "config"
local TrainBuild = require "models/TrainBuild"

local TrainDepot = {}
TrainDepot.__index = TrainDepot
TrainDepot.version = 2

function TrainDepot.new(depot_entity)
  local self = setmetatable({}, TrainDepot)
  self.type = "TrainDepot"
  self.version = TrainDepot.version

  self.depot = depot_entity
  self.train_build = nil
  self.built_trains = {}
  self.storage = nil
  self.cooldown_remaining = 0
  self.paused = false
  self.waiting_for_train_to_leave = nil
  self.num_trains_built = 0
  self.rail = self:get_connected_rail()

  local surface = depot_entity.surface
  local position = depot_entity.position
  local direction = depot_entity.direction

  if direction == defines.direction.south then
    position = util.movepositioncomplex(position, defines.direction.west, 1)
  end
  if direction == defines.direction.west then
    position = util.movepositioncomplex(position, defines.direction.north, 1)
    position = util.movepositioncomplex(position, defines.direction.west, 1)
  end
  if direction == defines.direction.north then
    position = util.movepositioncomplex(position, defines.direction.north, 1)
  end

  local storage = {name = "train-depot-storage", position = position, force = depot_entity.force}
  self.storage = surface.create_entity(storage)

  return self
end

function TrainDepot.find_using_entity(array, depot_entity)
  local depot = nil
  local index = false
  for i, current_depot in ipairs(array) do
    local current_depot = TrainDepot.deserialize(current_depot)
    if current_depot.depot == depot_entity then
      depot = current_depot
      index = i
      break
    end
  end

  return index, depot
end

function TrainDepot:get_connected_rail()
  local direction = util.counterclockwisedirection90(self.depot.direction)
  local position = util.movepositioncomplex(self.depot.position, direction, 2)
  local surface = self.depot.surface
  local rail = surface.find_entity("straight-rail", position)
  util.print("found rail: " .. (rail and "true" or "false"))
  return rail
end

function TrainDepot:is_rail_block_clear()
  -- TODO: I don't know how to determine this without enormous complexity...
end

function TrainDepot.parameters_from_signals(red_circuit_network, green_circuit_network)
  local signal_clone = 0
  local signal_auto = 0
  local signal_filter = 0
  local signal_schedule = 0

  if green_circuit_network and green_circuit_network.valid then
    signal_clone = signal_clone + (green_circuit_network.get_signal(_CONFIG._SIGNAL_TO_CLONE_FROM) or 0)
    signal_auto = signal_auto + (green_circuit_network.get_signal(_CONFIG._SIGNAL_SET_TO_AUTOMATIC) or 0)
    signal_filter = signal_filter + (green_circuit_network.get_signal(_CONFIG._SIGNAL_COPY_FILTERS) or 0)
    signal_schedule = signal_schedule + (green_circuit_network.get_signal(_CONFIG._SIGNAL_CLONE_SCHEDULE) or 0)
  end
  if red_circuit_network and red_circuit_network.valid then
    signal_clone = signal_clone + (red_circuit_network.get_signal(_CONFIG._SIGNAL_TO_CLONE_FROM) or 0)
    signal_auto = signal_auto + (red_circuit_network.get_signal(_CONFIG._SIGNAL_SET_TO_AUTOMATIC) or 0)
    signal_filter = signal_filter + (red_circuit_network.get_signal(_CONFIG._SIGNAL_COPY_FILTERS) or 0)
    signal_schedule = signal_schedule + (red_circuit_network.get_signal(_CONFIG._SIGNAL_CLONE_SCHEDULE) or 0)
  end

  return {
    clone_filters = (signal_filter >= 0),
    clone_schedule = (signal_schedule >= 0),
    set_to_auto = (signal_auto >= 0 and signal_schedule >= 0),
    train_to_clone = signal_clone
  }

end

function TrainDepot:construct_train_build()
  -- util.print("[" .. self.depot.unit_number .. "] trying to construct...")

  local train_build = nil
  local trains = nil
  local source_train = nil

  local depot_id = self.depot.unit_number or 0
  local red_circuit_network = self.depot.get_circuit_network(defines.wire_type.red)
  local green_circuit_network = self.depot.get_circuit_network(defines.wire_type.green)

  local parameters = self.parameters_from_signals(red_circuit_network, green_circuit_network)

  if parameters.train_to_clone == 0 then
    goto done
  else
    -- util.print("[" .. self.depot.unit_number .. "] looking for train ID " .. parameters.train_to_clone .. "...")
  end

  for _, surface in pairs(game.surfaces) do
    -- util.print("[" .. self.depot.unit_number .. "] checking surface " .. surface.name .. "...")
    trains = surface.get_trains()
    for train_index, train in ipairs(trains) do
      if train.id == parameters.train_to_clone then
        source_train = train
        break
      end
    end

    if source_train then
      break
    end
  end

  if source_train then
    -- util.print("source_train: " .. source_train.id)
    train_build = TrainBuild.new(self.depot, source_train, self.storage, parameters)
  end

::done::
  return train_build
end

function TrainDepot:update(ticks)
  local valid = true
  local complete = true
  local control = nil

  if not self.depot.valid then
    valid = false
    goto done
  end

  control = self.depot.get_or_create_control_behavior()
  if control and control.enable_disable and control.disabled then
    self.train_build = nil
    util.print("Entity not active...")
    goto done
  end

  if self.waiting_for_train_to_leave and self.waiting_for_train_to_leave.valid then
    if self.waiting_for_train_to_leave.state == defines.train_state.wait_station then
      util.print("Waiting for train to leave...")
      goto done
    end

    local schedule = self.waiting_for_train_to_leave.schedule
    if schedule and schedule.records[1] and schedule.records[1].station == self.depot.backer_name then
      table.remove(schedule.records, 1)
      -- util.print("schedule " .. table.tostring(schedule))
      schedule.current = schedule.current - 1
      if schedule.current < 1 then
        schedule.current = 1
      end
      self.waiting_for_train_to_leave.schedule = schedule
    end
  end
  self.waiting_for_train_to_leave = nil

  self.cooldown_remaining = self.cooldown_remaining - ticks

  if self.cooldown_remaining > 0 then
    util.print("Waiting for cooldown...")
    goto done
  end

  self.cooldown_remaining = 0 -- clamp to 0

  if self.paused then
    goto done
  end

  if self.train_build then
    -- Check that our train build is still going and wasn't interrupted
    if not self.train_build:valid() then
      self.train_build = nil
      self.cooldown_remaining = _CONFIG._COOLDOWN_TICKS
      goto done
    end

    complete, auto_scheduled = self.train_build:update(ticks)
    if complete then
      if auto_scheduled then
        self.waiting_for_train_to_leave = self.train_build.train
      end
      self.train_build = nil
      self.cooldown_remaining = _CONFIG._COOLDOWN_TICKS
      self.num_trains_built = (self.num_trains_built or 0) + 1
    end
  else
    -- util.print("[" .. self.depot.unit_number .. "] No train to build...")
  end

  if complete then
    local train_build = self:construct_train_build()

    if not train_build then
      goto done
    end

    if not train_build:can_place_all_remaining() then
      self.cooldown_remaining = _CONFIG._COOLDOWN_TICKS
      goto done
    end

    self.train_build = train_build
    self.train_build:update(ticks)
  end

::done::

  return valid
end

function TrainDepot:serialize()
  self.train_build_serialized = self.train_build and self.train_build:serialize() or nil
  return self
end

function TrainDepot.deserialize(data)
  if type(data) == "table" and data.type == "TrainDepot" and data.version <= TrainDepot.version then
    local self = setmetatable(data, TrainDepot)
    self.train_build = TrainBuild.deserialize(data.train_build_serialized)
    if data.version < 2 then
      self.rail = self:get_connected_rail()
      self.waiting_for_tile_to_clear = nil
    end
    self.version = TrainDepot.version
    return self
  end
  return nil
end

function TrainDepot:destroy()
  local storage = self.storage
  self.storage = nil

  if not storage.valid then
    goto done
  end

  local surface = storage.surface
  local new_storage = surface.create_entity({name = "steel-chest", position = storage.position, force = storage.force})
  local oldinventory = storage.get_output_inventory()
  local newinventory = new_storage.get_output_inventory()

  -- Chests don't support filters....doh
  -- for stack_index = 1, #oldinventory do
  --   local filter = oldinventory.get_filter(stack_index)
  --   newinventory.set_filter(stack_index, filter)
  -- end

  local oldcontents = oldinventory.get_contents()
  for item, count in pairs(oldcontents) do
    newinventory.insert({name = item, count = count})
  end

  storage.destroy()

::done::
end

return TrainDepot
