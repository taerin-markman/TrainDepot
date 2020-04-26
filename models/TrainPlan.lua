require "util"
require "config"

local TrainPlan = {}
TrainPlan.__index = TrainPlan
TrainPlan.version = 2

local function generate_filters_from_carriage(carriage)
  local inventory = carriage.get_output_inventory()
  local inventory_filters = nil
  if inventory then
    inventory_filters = {}
    if inventory.supports_filters() and inventory.is_filtered() then
      for inventory_index = 1, #inventory do
        local filter = inventory.get_filter(inventory_index)
        if filter then
          inventory_filters[inventory_index] = filter
        end
      end
    else
      inventory_filters = nil
    end
  end

  return inventory_filters
end

local function set_filters_on_carriage(carriage, filters)
  if filters then
    local inventory = carriage.get_output_inventory()
    if inventory.supports_filters() then
      for inventory_index, filter in pairs(filters) do
        if inventory.can_set_filter(inventory_index, filter) then
          inventory.set_filter(inventory_index, filter)
        end
      end
    end
  end
end

local function position_and_direction(connected_rail, index, offset)
  local index = index or 1
  local offset = offset or ((index % 2) - 1)

  local rotated_direction = util.counterclockwisedirection90(connected_rail.direction)
  -- local position = util.movepositioncomplex(connected_rail.position, connected_rail.direction, (-((index - 1) * 7) - 3) - offset)
  local position = util.movepositioncomplex(connected_rail.position, connected_rail.direction, (-((index - 1) * 7) - 3) - offset)
  -- local position = util.movepositioncomplex(position, rotated_direction, 2)
  local direction = connected_rail.direction

  return position, direction
end

function TrainPlan:clone_rolling_stock(connected_rail, train, with_filters)
  local rolling_stock = {}
  local front_movers = train.locomotives.front_movers or {}
  local back_movers = train.locomotives.back_movers or {}

  for index, carriage in ipairs(train.carriages) do
    local inventory = carriage.get_output_inventory()
    local inventory_filters = (with_filters and generate_filters_from_carriage(carriage) or nil)

    local position, direction = position_and_direction(connected_rail, index)
    local disconnect_on = defines.rail_direction.back
    if table.contains(back_movers, carriage) then
      direction = util.oppositedirection(direction)
      disconnect_on = defines.rail_direction.front
    end
    local new_stock = {name = carriage.name, position = position, force = connected_rail.force, direction = direction, inventory_filters = inventory_filters, disconnect_on = disconnect_on}

    table.insert(rolling_stock, new_stock)
  end

  return rolling_stock
end

function TrainPlan:clone_schedule(depot, train, add_self)
  local schedule = table.deepcopy(train.schedule)

  util.print("schedule: " .. table.tostring(schedule))

  if schedule then
    schedule.current = 1
    if add_self then
      table.insert(schedule.records, 1, {temporary = true, station = depot.backer_name, wait_conditions = {{type = "inactivity", compare_type = "and", ticks = 150}}})
    end
  end

  return schedule
end

function TrainPlan.new(depot, connected_rail, train, parameters)
  local self = setmetatable({}, TrainPlan)
  self.type = "TrainPlan"
  self.version = TrainPlan.version

  self.rolling_stock = self:clone_rolling_stock(connected_rail, train, parameters.clone_filters)
  self.schedule = nil
  if parameters.clone_schedule then
    self.schedule = self:clone_schedule(depot, train, parameters.set_to_auto)
  end
  self.set_to_auto = parameters.set_to_auto
  self.connected_rail = connected_rail

  return self
end

function TrainPlan:is_rail_clear(surface, index, position)
  local clear = false
  local offset = ((index - 1) % 2)

  -- local rail = surface.find_entity("straight-rail", position)
  local rails = surface.find_entities_filtered({name = "straight-rail", position = position})
  local rail = rails and rails[1] or nil

  util.print("finding rail at " .. table.tostring(position) .. ": " .. (table.tostring(rail) or "false"))

  if rail and rail.valid then
    util.print("found rail")
    local num_trains = rail.trains_in_block or 0
    util.print("num_trains: " .. num_trains)
    if num_trains == 0 then
      clear = true
    end
  end
  return clear
end

function TrainPlan:can_place(surface, stock_index, storage)
  local stock_plan = self.rolling_stock[stock_index]
  local can_place = false
  local reason = nil

  if stock_plan then
    local has_item = storage and (storage.get_item_count(stock_plan.name) > 0)

    if not storage or has_item then
      local plan = stock_plan
      can_place = self:is_rail_clear(surface, plan.position)
      if not can_place then
        reason = "[color=red]train-depot-status.rail-not-long-enough[/color]"
      else
        can_place = can_place and surface.can_place_entity(plan)
        if not can_place then
          reason = "[color=orange]train-depot-status.space-occupied[/color]"
        end
      end
      -- util.print("can place [" .. stock_index .. "][" .. offset .. "] at " .. table.tostring(plan.position) .. ": " .. (can_place and "true" or "false"))
    else
      reason = "[color=yellow]train-depot-status.items-missing[/color]"
    end
  else
    reason = "[color=yellow]train-depot-status.wtf-mate[/color]"
  end

  return can_place, reason
end

function TrainPlan:place(surface, stock_index, storage)
  local stock_plan = self.rolling_stock[stock_index]
  local stock = nil
  local storage_inventory = storage.get_output_inventory()
  local inventory_filters = stock_plan.inventory_filters
  stock_plan.inventory_filters = nil

  storage_inventory.remove({name = stock_plan.name, count = 1})
  stock = surface.create_entity(stock_plan)
  set_filters_on_carriage(stock, inventory_filters)
  game.play_sound({path = "entity-build/" .. stock.name, position = stock.position})

  -- If we place nearby another train, we don't want it to connect
  if stock_plan.disconnect_on then
    stock.disconnect_rolling_stock(stock_plan.disconnect_on)
  end

  return stock
end

function TrainPlan:length()
  return (self.rolling_stock and #self.rolling_stock or 0)
end

function TrainPlan:finalize(train)
  local auto_scheduled = false
  if self.schedule then
    train.schedule = self.schedule
    if self.set_to_auto then
      auto_scheduled = true
      train.manual_mode = false
    end
  end
  return auto_scheduled
end

function TrainPlan:serialize()
  return self
end

function TrainPlan.deserialize(data)
  if type(data) == "table" and data.type == "TrainPlan" and data.version <= TrainPlan.version then
    local self = setmetatable(data, TrainPlan)

    if data.version < 2 then
      self.set_to_auto = true
    end

    self.version = TrainPlan.version
    return self
  end
  return nil
end

return TrainPlan
