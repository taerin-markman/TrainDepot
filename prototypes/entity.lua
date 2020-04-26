local trainDepotEntity = table.deepcopy(data.raw["train-stop"]["train-stop"])

trainDepotEntity.name = "train-depot"
trainDepotEntity.minable = {hardness = 0.2, mining_time = 0.5, result = "train-stop"}
trainDepotEntity.color={r=0.2,  g=0.4, b=0.95, a=0.5}

local trainCounterEntity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
trainCounterEntity.name = "train-depot-counter"
trainCounterEntity.minable = {hardness = 0.2, mining_time = 0.5, result = "train-depot-counter"}
trainCounterEntity.inventory_size = 3
trainCounterEntity.icon = "__TrainDepot__/graphics/icons/train-depot-counter.png",

data:extend({trainDepotEntity, trainCounterEntity})
