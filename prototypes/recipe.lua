local trainDepotRecipe = table.deepcopy(data.raw.recipe["train-stop"])

trainDepotRecipe.enabled = false
trainDepotRecipe.name = "train-depot"
trainDepotRecipe.ingredients =
{
  {"train-stop", 1},
  {"steel-chest", 1},
  {"electronic-circuit", 50}
}
trainDepotRecipe.result = "train-depot"

local trainCounterRecipe = table.deepcopy(data.raw.recipe["constant-combinator"])

trainCounterRecipe.enabled = false
trainCounterRecipe.name = "train-depot-counter"
trainCounterRecipe.ingredients =
{
  {"steel-plate", 5},
  {"electronic-circuit", 10}
}
trainCounterRecipe.result = "train-depot-counter"

data:extend({trainDepotRecipe, trainCounterRecipe})
