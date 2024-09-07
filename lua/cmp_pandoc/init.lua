local source = require("cmp_pandoc.source")

local M = {}

M.setup = function(overrides)
  require("cmp").register_source("cmp_pandoc", source.new(overrides))
end

return M
