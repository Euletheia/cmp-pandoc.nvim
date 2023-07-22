local Path = require("plenary.path")
local utils = require("cmp_pandoc.utils")
local cmp = require("cmp")
local json = require('lunajson')

local M = {}

M.yaml_front_matter = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  local yaml_start = nil
  local yaml_end = nil

  local function is_valid(str)
    local match = string.match(str, "^%-%-%-") or string.match(str, "^%.%.%.")

    if match then
      if string.len(match) == 3 then
        return true
      end

      if string.sub(match, string.len(match) + 1, string.len(str)):match("^%s+") then
        return true
      end

      return false
    end

    return false
  end

  local i = 1

  while i <= #lines do
    if string.match(lines[i], "^%-%-%-") and is_valid(lines[i]) and not yaml_start then
      yaml_start = i
      i = i + 1
    end
    if is_valid(lines[i]) then
      yaml_end = i
      break
    end
    i = i + 1
  end

  local previous_line_is_empty = (function()
    if yaml_start == nil then
      return
    end
    if yaml_start > 1 then
      return string.len(lines[yaml_start - 1]) == 0
    end
    return true
  end)()

  local is_valid_yaml = yaml_start ~= nil and yaml_end ~= nil and (yaml_start ~= yaml_end) and previous_line_is_empty

  return {
    is_valid = is_valid_yaml,
    start = yaml_start,
    ["end"] = yaml_end,
    raw_content = is_valid_yaml and vim.list_slice(lines, yaml_start + 1, yaml_end - 1) or nil,
  }
end

M.get_bibliography_paths = function(bufnr)
  local front_matter = M.yaml_front_matter(bufnr)

  if not front_matter.is_valid then
    return
  end

  local bibliography_line = nil

  for index, value in ipairs(front_matter.raw_content) do
    if string.match(value, "^bibliography:") then
      bibliography_line = index
      break
    end
  end

  if not bibliography_line then
    return
  end

  local bibliography_field = vim.trim(string.match(front_matter.raw_content[bibliography_line], ":(.*)"))

  if string.len(bibliography_field) > 0 then
    return { bibliography_field }
  end

  local bibliography_inputs = {}

  local i = 1

  while i <= #front_matter.raw_content do
    if string.match(front_matter.raw_content[i], "^%-%s[%w|%d|%D]+") then
      table.insert(bibliography_inputs, front_matter.raw_content[i])
    end
    i = i + 1
  end

  if #bibliography_inputs == 0 then
    return
  end

  return vim.tbl_map(function(bibliography)
    return vim.trim(string.match(bibliography, "-%s(.*)"))
  end, bibliography_inputs)
end

local read_file = function(path)
  local p = path
  -- resolve relative path
  if not path:sub(1,1) == '/' then
    p = Path.new(vim.api.nvim_buf_get_name(0)):parent():joinpath(path):absolute()
  end

  if Path:new(p):exists() then
    local file = io.open(p, "rb")
    local results = file:read("*all")
    file:close()
    return results
  end
end

local citations = function(path, opts)
  local data = read_file(path)

  if not data then
    return
  end

  local o = {}

  for citation in data:gmatch("@.-\n}\n") do
    table.insert(o, citation)
  end

  return vim.tbl_map(function(citation)
    local documentation = vim.tbl_map(function(field)
      return utils.format(citation, field)
    end, opts.fields)

    return utils.format_entry({
      label = citation:match("@%w+{(.-),"),
      doc = opts.documentation,
      kind = "Field",
      value = table.concat(documentation, "\n"),
    })
  end, o)
end

local function combine_names(names, suffix)
  local full_names = {}
  for _,name in ipairs(names) do
    local full_name = name.literal or name.family or ''
    local non_drop = name['non-dropping-particle'] or ''
    full_name = non_drop .. full_name
    local given = name.given or ''
    local drop = name['dropping-particle'] or ''
    if drop ~= '' then
      given = given .. ' ' .. drop
    end
    if given ~= '' then
      full_name = given .. ' ' .. full_name
    end
    if full_name ~= '' then
      table.insert(full_names, full_name)
    end
  end
  full_names = table.concat(full_names, ' and ')
  if suffix then
    if #names > 1 then
      full_names = full_names .. ' (' .. suffix .. 's)'
    else
      full_names = full_names .. ' (' .. suffix .. ')'
    end
  end

  return full_names
end

-- Parses the .json file
local function parse_json_bib(filename)
	local file = io.open(filename, 'rb')
	local bibentries = file:read('*all')
	file:close()
    local data = json.decode(bibentries)
    return vim.tbl_map(
        function(item)
            local id = item.id or ''
            
            local doc = {}
            
            local type = item.type or ''
            type = type:gsub("^%l", string.upper):gsub('-journal','')
            table.insert(doc, '# ' .. type)

            local title = item['title-short'] or item.title or ''
            title = title:gsub('[{}]+','')
            table.insert(doc, '*' .. title .. '*')

            local authors = item.author or nil 
            if authors then
              authors = combine_names(authors, nil)
              table.insert(doc, authors)
            end

            local editors = item.editor or nil 
            if editors then
              editors = combine_names(editors, 'ed')
              table.insert(doc, editors)
            end
            
            local translators = item.translator or nil 
            if translators then
              translators = combine_names(translators, nil)
              table.insert(doc, translators .. ' (trans)')
            end
            
            local date = item.issued or nil
            if date then
              date = date.literal or nil
              if date then
                 table.insert(doc, date)
              else
                date = item.issued['date-parts'] or nil
                if date then
                  date = date[1] or nil
                end
                if date then
                  date = date[1] or nil
                end
                if date then
                  table.insert(doc, date)
                end
              end
            end

            doc = table.concat(doc, '\n')
            return { 
                  label = '@' .. id,
                  kind = cmp.lsp.CompletionItemKind.Reference,
                  documentation = {
                     kind = cmp.lsp.MarkupKind.Markdown,
                     value = doc,
                  }
               }
        end, data)
end


M.bibliography = function(bufnr, opts)
  local bib_paths = M.get_bibliography_paths(bufnr)

  if vim.g["pandoc#biblio#bibs"] then
    bib_paths = vim.g["pandoc#biblio#bibs"]
  end
 
  if not bib_paths then
    return
  end

  local all_bib_entrys = {}

  for _, path in ipairs(bib_paths) do
    local citation = citations(path, opts)
    if citation then
      vim.list_extend(all_bib_entrys, citation)
    end
  end

  return all_bib_entrys
end

local crossreferences = function(line, opts)
  if string.match(line, utils.crossref_patterns.equation) and string.match(line, "^%$%$(.*)%$%$") then
    local equation = string.match(line, "^%$%$(.*)%$%$")

    return utils.format_entry({
      label = string.match(line, utils.crossref_patterns.equation),
      doc = opts.documentation,
      value = opts.enable_nabla and utils.nabla(equation) or equation,
    })
  end

  if string.match(line, utils.crossref_patterns.section) and string.match(line, "^#%s+(.*){") then
    return utils.format_entry({
      label = string.match(line, utils.crossref_patterns.section),
      value = "*" .. vim.trim(string.match(line, "#%s+(.*){")) .. "*",
    })
  end

  if string.match(line, utils.crossref_patterns.table) then
    return utils.format_entry({
      label = string.match(line, utils.crossref_patterns.base),
      value = "*" .. vim.trim(string.match(line, "^:%s+(.*)%s+{")) .. "*",
    })
  end

  if string.match(line, utils.crossref_patterns.lst) then
    return utils.format_entry({
      label = string.match(line, utils.crossref_patterns.lst),
      value = "*" .. vim.trim(string.match(line, "^:%s+(.*)%s+{")) .. "*",
    })
  end

  if string.match(line, utils.crossref_patterns.figure) then
    return utils.format_entry({
      label = string.match(line, utils.crossref_patterns.figure),
      value = "*" .. vim.trim(string.match(line, "^%!%[.*%]%((.*)%)")) .. "*",
    })
  end
end

M.references = function(bufnr, opts)
  local valid_lines = vim.tbl_filter(function(line)
    return line:match(utils.crossref_patterns.base) and not line:match("^%<!%-%-(.*)%-%-%>$")
  end, vim.api.nvim_buf_get_lines(bufnr, 0, -1, true))

  if vim.tbl_isempty(valid_lines) then
    return
  end

  return vim.tbl_map(function(line)
    return crossreferences(line, opts)
  end, valid_lines)
end

M.init = function(self, callback, bufnr)
  local opts = self and self.opts or require("cmp_pandoc.config")
 
  local bib = opts.bibliography.path 
  local bib_type = bib:match "[^.]+$"

  local bib_items = nil
  if bib_type == 'json' then
    bib_items = parse_json_bib(bib)
  else
    bib_items = M.bibliography(bufnr, opts.bibliography)
  end

  local reference_items = M.references(bufnr, opts.crossref)

  local all_entrys = {}

  if reference_items then
    vim.list_extend(all_entrys, reference_items)
  end

  if bib_items then
    vim.list_extend(all_entrys, bib_items)
  end

  if not all_entrys then
    return callback()
  end
  return callback(all_entrys)
end

return M
