require "util"
require "config"

local TrainCounter = {}
TrainCounter.__index = TrainCounter
TrainCounter.version = 1

function TrainCounter.new(counter_entity)
  local self = setmetatable({}, TrainCounter)
  self.type = "TrainCounter"
  self.version = TrainCounter.version

  counter_entity.operable = false
  self.counter = counter_entity
  self.source_entity = self:find_source_entity()

  self:update(0)

  return self
end

function TrainCounter.find_using_entity(array, counter_entity)
  local counter = nil
  local index = false
  for i, current_counter in ipairs(array) do
    local current_counter = TrainCounter.deserialize(current_counter)
    if current_counter.counter == counter_entity then
      counter = current_counter
      index = i
      break
    end
  end

  return index, counter
end

function TrainCounter:find_source_entity()
  local surface = self.counter.surface
  local left_top = util.movepositioncomplex(util.movepositioncomplex(self.counter.position, defines.direction.north, 1), defines.direction.west, 1)
  local right_bottom = util.movepositioncomplex(util.movepositioncomplex(self.counter.position, defines.direction.south, 1), defines.direction.east, 1)
  local bounding_box = {left_top = left_top, right_bottom = right_bottom}

  local entity = nil
  
  for _, entity_name in ipairs({"train-stop", "train-depot"}) do
    local entities = surface.find_entities_filtered({area = bounding_box, name = entity_name}) or {}
    entity = entities[1]
    if entity then
      break
    end
  end

  return entity
end

function TrainCounter:update(ticks)
  local valid = true
  local count = 0
  local control = nil

  if not self.counter.valid then
    valid = false
    goto done
  end

  if not self.source_entity or not self.source_entity.valid then
    self.source_entity = self:find_source_entity()
  end

  if not self.source_entity or not self.source_entity.valid then
    control = self.counter.get_or_create_control_behavior()
    control.set_signal(1, {signal = _CONFIG._SIGNAL_TRAIN_COUNT, count = -1})
    goto done
  end

  count = #self.source_entity.get_train_stop_trains()
  control = self.counter.get_or_create_control_behavior()
  if control then
    control.set_signal(1, {signal = _CONFIG._SIGNAL_TRAIN_COUNT, count = count})
  end

::done::

  return valid
end

function TrainCounter:serialize()
  self.train_build_serialized = self.train_build and self.train_build:serialize() or nil
  return self
end

function TrainCounter.deserialize(data)
  if type(data) == "table" and data.type == "TrainCounter" and data.version <= TrainCounter.version then
    local self = setmetatable(data, TrainCounter)
    self.version = TrainCounter.version
    return self
  end
  return nil
end

function TrainCounter:destroy()
end

return TrainCounter
