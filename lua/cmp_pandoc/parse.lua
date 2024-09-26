local vim = vim
local cmp = require("cmp")
local utils = require("cmp_pandoc.utils")

local M = {}

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
        -- NOTE : Is that an duplicate mistake ?
        -- if date then
        --   date = date[1] or nil
        -- end
        if date then
          table.insert(doc, date)
        end
      end
    end

    local original_date = item["original-date"] or nil
    if original_date then
      original_date = original_date.literal or nil
      if original_date then
        table.insert(doc, original_date)
      else
        original_date = item["original-date"]["date-parts"] or nil
        if original_date then
          original_date = original_date[1] or nil
        end
        if date then
          table.insert(doc, original_date)
        end
      end
    end

    -- TODO : Add original_publisher / original_publisher_place

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

-- NOTE : The objective here is to allow multiple csl to be parsed into the all_entrys cmp source
M.init = function(self, callback, bufnr)
  local opts = self and self.opts or require("cmp_pandoc.config")

  local bibfield = opts.bibliography.path
  if bibfield == nil then
    return callback()
  end

  local bibs = {}

  for i = 1, #bibfield do
    local bib_type = string.match(bibfield[i], "[^.]+$")
    if bib_type == "json" then
      local bibpath = vim.fn.expand(bibfield[i])
      print(bibpath)
      -- vim.fn.table_insert(bibs, bibpath)
      table.insert(bibs, bibpath)
      -- vim.list_extend(bibs, { bibpath })
    end
  end
  print(bibs)

  local bib_items = {}
  for i = 1, #bibs do
    local bib_item = parse_json_bib(bibs[i])
    vim.list_extend(bib_items, bib_item)
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
