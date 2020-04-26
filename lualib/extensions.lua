require "util"
require "config"

table.tostring = nil
table.tostring = function(thetable, custom)
  if not thetable then return "nil" end

  local string_parts = {}
  for k, v in pairs(thetable) do
    local value = v
    local value_type = type(v)
    if value_type == "table" then
      value = table.tostring(value, custom)
    elseif value_type == "string" then
      value = [["]] .. value .. [["]]
    elseif value_type == "number" then
      value = tostring(value)
    else
      if custom then
        value = custom(value_type, value)
      else
        value = value_type
      end
    end

    table.insert(string_parts, "[" .. k .. "] = " .. value)
  end

  return "{" .. table.concat(string_parts, ",") .. "}"
end

function table.contains(self, value)
  local result = false
  for i, v in ipairs(self) do
    if value == v then
      result = true
      break
    end
  end
  return result
end

function util.movepositioncomplex(position, direction, distance)
  if direction == defines.direction.north then
    return {x = position.x, y = position.y - distance}
  end

  if direction == defines.direction.south then
    return {x = position.x, y = position.y + distance}
  end

  if direction == defines.direction.east then
    return {x = position.x + distance, y = position.y}
  end

  if direction == defines.direction.west then
    return {x = position.x - distance, y = position.y}
  end
end

function util.clockwisedirection90(direction)
  local d = defines.direction
  local clockwise = {
    [d.north] = d.east,
    [d.northeast] = d.southeast,
    [d.east] = d.south,
    [d.southeast] = d.southwest,
    [d.south] = d.west,
    [d.southwest] = d.northwest,
    [d.west] = d.north,
    [d.northwest] = d.northeast
  }
  if clockwise[direction] then return clockwise[direction] end
  error(direction .. " is not a valid direction")
end

function util.counterclockwisedirection90(direction)
  local d = defines.direction
  local clockwise = {
    [d.north] = d.west,
    [d.northeast] = d.northwest,
    [d.east] = d.north,
    [d.southeast] = d.northeast,
    [d.south] = d.east,
    [d.southwest] = d.southeast,
    [d.west] = d.south,
    [d.northwest] = d.southwest
  }
  if clockwise[direction] then return clockwise[direction] end
  error(direction .. " is not a valid direction")
end

function util.print(string)
  if _CONFIG._DEBUG then
    game.print(string)
  end
end

function util.logunexpectednil()
end

function util.logunexpectedtype()
end

function util.tableoruserdata(value)
  local result = false
  if value then
    if type(value) == "userdata" or type(value) == "table" then
      result = true
    end
  end
  return result
end

function util.protected(func)
  if _CONFIG._DEBUG then
    return true, func()
  else
    return pcall(func)
  end
end
