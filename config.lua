_CONFIG = {}

_CONFIG._UPDATE_DEPOTS_TICKS = 10
_CONFIG._UPDATE_COUNTERS_TICKS = 60
_CONFIG._SIGNAL_TO_CLONE_FROM = {type = "virtual", name = "signal-T"} -- TODO: make this configurable in mod settings, and then later in-game
_CONFIG._SIGNAL_COPY_FILTERS = {type = "virtual", name = "signal-F"} -- TODO: make this configurable in mod settings, and then later in-game
_CONFIG._SIGNAL_SET_TO_AUTOMATIC = {type = "virtual", name = "signal-A"} -- TODO: make this configurable in mod settings, and then later in-game
_CONFIG._SIGNAL_CLONE_SCHEDULE = {type = "virtual", name = "signal-S"} -- TODO: make this configurable in mod settings, and then later in-game
_CONFIG._SIGNAL_TRAIN_COUNT = {type = "virtual", name = "signal-C"} -- TODO: make this configurable in mod settings, and then later in-game
_CONFIG._UNMODULED_STOCK_PER_SEC = 1
_CONFIG._DEBUG = false
_CONFIG._COOLDOWN_TICKS = 3 * 60

if _CONFIG._DEBUG then
  _CONFIG._UPDATE_DEPOTS_TICKS = 60
end
