return {
  -- What types of files cmp-pandoc works.
  -- 'pandoc', 'markdown' and 'rmd' (Rmarkdown)
  -- @type: table of string
  filetypes = { "pandoc", "markdown", "rmd" },
  -- Customize bib documentation
  bibliography = {
    -- Global default bibliography file
    -- @type: string
    path = nil,
    -- Enable bibliography documentation
    -- @type: boolean
    documentation = true,
    -- Fields to show in documentation
    -- @type: table of string
    fields = { "type", "title", "author", "year" },
  },
  -- Crossref
  crossref = {
    -- Enable documetation
    -- @type: boolean
    documentation = true,
  },
}
