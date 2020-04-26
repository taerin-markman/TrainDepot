local automatedTrainBuildingTechnology =
{
  type = "technology",
  name = "automated-train-building",
  icon_size = 128,
  icon = "__TrainDepot__/graphics/technology/automated-train-building.png",
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "train-depot"
    },
    {
      type = "unlock-recipe",
      recipe = "train-counter"
    }
  },
  prerequisites = {"automated-rail-transportation", "circuit-network"},
  unit =
  {
    count = 200,
    ingredients =
    {
      {"logistic-science-pack", 1},
      {"automation-science-pack", 1}
    },
    time = 30
  },
  order = "c-g-b"
}

data:extend({automatedTrainBuildingTechnology})
