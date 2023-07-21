local Path = require("plenary.path")
local yml = require "lyaml"
local json = require "json"

local M = {}

M.yaml_front_matter = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local content = table.concat(lines, "\n")
  return yml.load(lines)
end


M.get_bibliography_paths = function(bufnr)
  --local yaml_bib = M.yaml_front_matter(bufnr).bibliography
  local my_bib = '/Users/desanso/Documents/d/research/zotero.json'
  local bibliography_inputs = { my_bib }
  return bibliography_inputs
end

local read_file = function(path)
  local p = path
  -- resolve relative path
  -- if not path:sub(1,1) == '/' then
  --   p = Path.new(vim.api.nvim_buf_get_name(0)):parent():joinpath(path):absolute()
  -- end

  if Path:new(p):exists() then
    local file = io.open(p, "rb")
    local results = file:read("*all")
    file:close()
    return results
  end
end

local citations = function(path, opts)
  local data = json.decode(read_file(path))
end

M.bibliography = function(bufnr)
  local bib_paths = M.get_bibliography_paths(bufnr)

  local all_bib_entrys = {}

  for _, path in ipairs(bib_paths) do
    print(citations(path))
    -- local citation = citations(path)
    -- if citation then
    --   --vim.list_extend(all_bib_entrys, citation)
    -- end
  end

  return all_bib_entrys
end

M.init = function(self, callback)
   local bib_items = M.bibliography(bufnr)
end

-- return M

local bib_items = M.bibliography(0)

return M
