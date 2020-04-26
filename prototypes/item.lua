local trainDepot = table.deepcopy(data.raw.item["train-stop"])

trainDepot.name = "train-depot"
trainDepot.icon = "__TrainDepot__/graphics/icons/train-depot.png"
trainDepot.place_result = "train-depot"
trainDepot.order = "a[train-system]-c[ztrain-depot]"
trainDepot.fast_replaceable_group = "train-stop"

data.raw.item["train-stop"].fast_replaceable_group = "train-stop"

-- local trainDepotStorage = table.deepcopy(data.raw.item["steel-chest"])

-- trainDepotStorage.name = "train-depot-storage"
-- trainDepotStorage.place_result = "train-depot-storage"
-- trainDepotStorage.icons= {
--    {
--       icon=trainDepotStorage.icon, -- TODO: eventually replace with a custom icon
--       tint={r=0.7,g=0.7,b=1,a=1}
--    },
-- }

local trainCounter = table.deepcopy(data.raw.item["constant-combinator"])

trainCounter.name = "train-depot-counter"
trainCounter.icon = "__TrainDepot__/graphics/icons/train-depot-counter.png"
trainCounter.place_result = "train-depot-counter"
trainCounter.order = "a[train-system]-c[ztrain-depot-counter]"
trainCounter.subgroup = "transport"

data:extend({trainDepot, trainCounter})
