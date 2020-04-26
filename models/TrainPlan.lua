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

local function position_and_direction(depot, index, offset)
  local index = index or 1
  local offset = offset or 0

  local rotated_direction = util.counterclockwisedirection90(depot.direction)
  local position = util.movepositioncomplex(depot.position, depot.direction, (-((index - 1) * 7) - 3) - offset)
  local position = util.movepositioncomplex(position, rotated_direction, 2)
  local direction = depot.direction

  return position, direction
end

function TrainPlan:clone_rolling_stock(depot, train, with_filters)
  local rolling_stock = {}
  local front_movers = train.locomotives.front_movers or {}
  local back_movers = train.locomotives.back_movers or {}

  for index, carriage in ipairs(train.carriages) do
    local inventory = carriage.get_output_inventory()
    local inventory_filters = (with_filters and generate_filters_from_carriage(carriage) or nil)

    local position, direction = position_and_direction(depot, index)
    local disconnect_on = defines.rail_direction.back
    if table.contains(back_movers, carriage) then
      direction = util.oppositedirection(direction)
      disconnect_on = defines.rail_direction.front
    end
    local new_stock = {name = carriage.name, position = position, force = depot.force, direction = direction, inventory_filters = inventory_filters, disconnect_on = disconnect_on}

    table.insert(rolling_stock, new_stock)
  end

  return rolling_stock
end

function TrainPlan:clone_schedule(depot, train, add_self)
  local schedule = table.deepcopy(train.schedule)
  if schedule then
    schedule.current = 1
    if add_self then
      table.insert(schedule.records, 1, {station = depot.backer_name, wait_conditions = {{type = "inactivity", compare_type = "and", ticks = 150}}})
    end
  end

  return schedule
end

function TrainPlan.new(depot, train, parameters)
  local self = setmetatable({}, TrainPlan)
  self.type = "TrainPlan"
  self.version = TrainPlan.version

  self.rolling_stock = self:clone_rolling_stock(depot, train, parameters.clone_filters)
  self.schedule = nil
  if parameters.clone_schedule then
    self.schedule = self:clone_schedule(depot, train, parameters.set_to_auto)
  end
  self.set_to_auto = parameters.set_to_auto

  return self
end

function TrainPlan.can_place_at_depot(depot, stock_plan, stock_index, offset, storage)
  local can_place = false
  local surface = depot.surface
  local stock_index = stock_index or 1

  if stock_plan then
    stock_plan.position, stock_plan.direction = position_and_direction(depot, stock_index, offset)

    local has_item = storage and (storage.get_item_count(stock_plan.name) > 0)

    if not storage or has_item then
      can_place = surface.can_place_entity(stock_plan)
    end

    -- util.print("can place [" .. stock_index .. "][" .. offset .. "] at " .. table.tostring(stock_plan.position))
  end

  return can_place
end

function TrainPlan:can_place(depot, stock_index, offset, storage)
  local stock_plan = self.rolling_stock[stock_index]
  local can_place = false
  local surface = depot.surface
  local offset = offset or 0

  if stock_plan then
    local has_item = storage and (storage.get_item_count(stock_plan.name) > 0)

    if not storage or has_item then

      local plan = stock_plan

      if offset > 0 then
        plan = table.deepcopy(stock_plan)
        plan.position = util.movepositioncomplex(plan.position, depot.direction, -offset)
      end
      can_place = surface.can_place_entity(plan)
      -- util.print("can place [" .. stock_index .. "][" .. offset .. "] at " .. table.tostring(plan.position) .. ": " .. (can_place and "true" or "false"))
    end
  end

  return can_place
end

function TrainPlan:place(surface, stock_index, storage)
  local stock_plan = self.rolling_stock[stock_index]
  local stock = nil
  if stock_plan then
    local storage_inventory = storage.get_output_inventory()
    local has_item = (storage.get_item_count(stock_plan.name) > 0)

    if has_item then
      local inventory_filters = stock_plan.inventory_filters
      stock_plan.inventory_filters = nil

      local can_place = surface.can_place_entity(stock_plan)
      if can_place then
        storage_inventory.remove({name = stock_plan.name, count = 1})
        stock = surface.create_entity(stock_plan)
        set_filters_on_carriage(stock, inventory_filters)
        game.play_sound({path = "entity-build/" .. stock.name, position = stock.position})

        -- If we place nearby another train, we don't want it to connect
        if stock_plan.disconnect_on then
          stock.disconnect_rolling_stock(stock_plan.disconnect_on)
        end
      end
    end
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
