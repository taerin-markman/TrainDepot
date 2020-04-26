require "util"
require "config"
local TrainPlan = require "models/TrainPlan"

local TrainBuild = {}
TrainBuild.__index = TrainBuild
TrainBuild.version = 1

function TrainBuild.new(depot, train, storage, parameters)
  local self = setmetatable({}, TrainBuild)
  self.type = "TrainBuild"
  self.version = TrainBuild.version

  self.train_plan = TrainPlan.new(depot, train, parameters)
  self.current_stock_index = 1
  self.current_progress = 0
  self.built_stock = {}
  self.train = nil
  self.depot = depot
  self.storage = storage

  return self
end

function TrainBuild:calculate_progress_from_ticks(ticks)
  local progress = 0

  -- TODO: static for now, but affected by modules in the future
  progress = progress + (100 * ((ticks / 60) / _CONFIG._UNMODULED_STOCK_PER_SEC))

  return progress -- math.ceil(progress)
end

function TrainBuild:can_place_next()
  return self.train_plan:can_place(self.current_stock_index)
end

function TrainBuild:can_place_all_remaining()
  local is_clear = true
  local length = self.train_plan:length()

  for index = self.current_stock_index, length do
    local offset = 0
    if index == length then
      offset = 3 -- TODO: connection_distance/joint_distance?
    end

    is_clear = is_clear and self.train_plan:can_place(self.depot, index, offset)
  end

  return is_clear
end

function TrainBuild.can_place_clone_at_depot(depot, train)
  local num = #train.carriages
  local can_place = true

  for stock_index = 1, num do
    local stock_plan = {name = "cargo-wagon"}
    local offset = 0
    if stock_index == num then
      offset = 3 -- TODO: connection_distance/joint_distance?
    end
    can_place = can_place and TrainPlan.can_place_at_depot(depot, stock_plan, stock_index, offset)
  end

  return can_place
end

function TrainBuild:valid()
  local valid = true

  if self.train and not self.train.valid then
    valid = false
  end

  return valid
end

function TrainBuild:update(ticks)
  local complete = false
  local auto_scheduled = false

  self.current_progress = self.current_progress + self:calculate_progress_from_ticks(ticks)

  -- util.print("current_progress: " .. self.current_progress)

  if self.current_progress >= 100 then

    local stock = nil

    if self:can_place_all_remaining() then
      util.print("building: " .. self.current_stock_index .. " of " .. self.train_plan:length())
      stock = self.train_plan:place(self.depot.surface, self.current_stock_index, self.storage)
    else
      util.print("waiting for clearance")
    end

    if stock then
      self.built_stock[self.current_stock_index] = stock

      -- train id changes every time we add stock to it, so keep it updated
      self.train = stock.train

      self.current_progress = self.current_progress % 100
      self.current_stock_index = self.current_stock_index + 1
    else
      -- TODO: check validity of TrainBuild
      self.current_progress = 100 -- clamp while we wait for the stock to be placeable
    end
  end

  if self.current_stock_index > self.train_plan:length() then
    auto_scheduled = self.train_plan:finalize(self.train)
    complete = true
  end

  return complete, auto_scheduled
end

function TrainBuild:serialize()
  self.train_plan_serialized = self.train_plan and self.train_plan:serialize() or nil
  return self
end

function TrainBuild.deserialize(data)
  if type(data) == "table" and data.type == "TrainBuild" and data.version <= TrainBuild.version then
    local self = setmetatable(data, TrainBuild)
    self.train_plan = TrainPlan.deserialize(data.train_plan_serialized)
    self.version = TrainBuild.version
    return self
  end
  return nil
end

return TrainBuild
