local vim = vim
local cmp = require("cmp")
local utils = require("cmp_pandoc.utils")

-- Debug
local inspect = require("vim.inspect")

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

M.extract_yaml_bibs = function(bufnr)
  local front_matter = M.yaml_front_matter(bufnr)
  local has_bibs = false

  if not front_matter.is_valid then
    return has_bibs
  end

  local bibs = {}
  local is_bibliography_section = false

  for _, value in ipairs(front_matter.raw_content) do
    if is_bibliography_section then
      -- Strip spaces and "| " characters at the beginning of the line
      local stripped_line = string.match(value, "^%- (.*)")
      if stripped_line then
        table.insert(bibs, stripped_line)
      else
        -- Exit the loop when a line not starting with "- " is encountered
        break
      end
    elseif string.match(value, "^bibliography: .+") then
      -- Handle the case where bibliography line directly contains the path to a .bib file
      local path = string.match(value, "^bibliography: (.+)$")
      table.insert(bibs, path)
      has_bibs = true
      break
    elseif string.match(value, "^bibliography:") then
      is_bibliography_section = true
      has_bibs = true
    end
  end

  print(inspect(bibs))

  return {
    has_bibs = has_bibs,
    bibs = bibs,
  }
end

--[[
--====================================
--]]

-- Parse the .bib file
local function parse_bib_bib(filename, opts)
  local file = io.open(filename, "rb")
  local bibentries = nil
  if file ~= nil then
    bibentries = file:read("*all")
    file:close()
  end

  if not bibentries then
    return
  end

  local data = {}

  for citation in bibentries:gmatch("@.-\n}") do
    table.insert(data, citation)
  end

  return vim.tbl_map(function(citation)
    local documentation = vim.tbl_map(function(field)
      return utils.format(citation, field)
    end, opts.bibliography.fields)

    return utils.format_entry({
      label = citation:match("@%w+{(.-),"),
      doc = opts.documentation,
      kind = "Field",
      value = table.concat(documentation, "\n"),
    })
  end, data)
end

local function combine_names(names, suffix)
  local full_names = {}
  for _, name in ipairs(names) do
    local full_name = name.literal or name.family or ""
    local non_drop = name["non-dropping-particle"] or ""
    full_name = non_drop .. full_name
    local given = name.given or ""
    local drop = name["dropping-particle"] or ""
    if drop ~= "" then
      given = given .. " " .. drop
    end
    if given ~= "" then
      full_name = given .. " " .. full_name
    end
    if full_name ~= "" then
      table.insert(full_names, full_name)
    end
  end
  local full_names_str = table.concat(full_names, " and ")
  if suffix then
    if #names > 1 then
      full_names_str = full_names_str .. " (" .. suffix .. "s)"
    else
      full_names_str = full_names_str .. " (" .. suffix .. ")"
    end
  end

  return full_names_str
end

-- Parse the .json file
local function parse_json_bib(filename)
  local file = io.open(filename, "rb")
  local bibentries = nil
  if file ~= nil then
    bibentries = file:read("*all")
    file:close()
  end

  if not bibentries then
    return
  end

  local data = vim.json.decode(bibentries)
  return vim.tbl_map(function(item)
    local id = item.id or ""
    local doc = {}
    local type = item.type or ""
    type = type:gsub("^%l", string.upper):gsub("-journal", "")
    table.insert(doc, "# " .. type)

    local title = item["title-short"] or item.title or ""
    title = title:gsub("[{}]+", "")
    table.insert(doc, "*" .. title .. "*")

    local authors = item.author or nil
    if authors then
      authors = combine_names(authors, nil)
      table.insert(doc, authors)
    end

    local editors = item.editor or nil
    if editors then
      editors = combine_names(editors, "ed")
      table.insert(doc, editors)
    end

    local translators = item.translator or nil
    if translators then
      translators = combine_names(translators, nil)
      table.insert(doc, translators .. " (trans)")
    end

    local date = item.issued or nil
    if date then
      date = date.literal or nil
      if date then
        table.insert(doc, date)
      else
        date = item.issued["date-parts"] or nil
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

    local original_date = item["original-date"] or nil
    if original_date then
      original_date = original_date.literal or nil
      if original_date then
        original_date = "(" .. original_date .. ")"
        doc[4] = doc[4] .. " " .. original_date
        -- table.insert(doc, original_date)
      else
        original_date = item["original-date"]["date-parts"] or nil
        if original_date then
          original_date = original_date[1] or nil
        end
        if original_date then
          original_date = original_date[1] or nil
        end
        if original_date then
          original_date = "(" .. original_date .. ")"
          doc[4] = doc[4] .. " " .. original_date
          -- table.insert(doc, original_date)
        end
      end
    end

    local doc_str = table.concat(doc, "\n")
    return {
      label = "@" .. id,
      kind = cmp.lsp.CompletionItemKind.Reference,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = doc_str,
      },
    }
  end, data)
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
  local extract_yaml_bibs = M.extract_yaml_bibs(bufnr)

  local bibfield = nil
  if extract_yaml_bibs and extract_yaml_bibs.has_bibs then
    bibfield = extract_yaml_bibs.bibs
  else
    bibfield = opts.bibliography.path
  end

  if bibfield == nil then
    return callback()
  end

  local bibs = {}

  for i = 1, #bibfield do
    local bib_type = string.match(bibfield[i], "[^.]+$")
    if bib_type == "json" or bib_type == "bib" then
      local bibpath = vim.fn.expand(bibfield[i])
      table.insert(bibs, bibpath)
    end
  end

  local bib_items = {}
  for i = 1, #bibs do
    local bib_type = string.match(bibfield[i], "[^.]+$")
    if bib_type == "json" then
      local json_item = parse_json_bib(bibs[i])
      if json_item then
        vim.list_extend(bib_items, json_item)
      end
    elseif bib_type == "bib" then
      local bib_item = parse_bib_bib(bibs[i], opts)
      if bib_item then
        vim.list_extend(bib_items, bib_item)
      end
    end
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
