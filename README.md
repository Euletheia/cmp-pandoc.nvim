# 📑 cmp-pandoc

Pandoc source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

![image](https://user-images.githubusercontent.com/16160544/148705351-6ff6fe46-0061-4c7f-989b-31f9e7be3c1c.png)

## This fork

This fork tries to provide the "best of both worlds" by expanding the work of [dsanson](https://github.com/dsanson/cmp-pandoc.nvim) and [aspeddro](https://github.com/aspeddro/cmp-pandoc.nvim/) (the plugin original author) and adding key features I needed for my work.

## Features

### Exclusive Features

* Two ways of providing bibliographies files :
  * in the plugin configuration (`setup({})` / `opts = {}`)
  * in the document yaml metadata block
* Support for csl `.json` and `.bib` formats
* Multiple **named** bibliographies in the style recognized by the [`multibib`](https://github.com/pandoc-ext/multibib) pandoc filter.
* Additional documentation fields (only for `.json` files) :
  * `original-date`
  * `original-author`

### Original Features

- Multiple bibliography files
- Support [`pandoc-crossref`](https://github.com/lierdakil/pandoc-crossref)
- Equation preview with [`nabla.nvim`](https://github.com/jbyuki/nabla.nvim)

## Requirements

- `Neovim >= 0.5.0`
- [`nabla.nvim`](https://github.com/jbyuki/nabla.nvim) (needed : for equation preview)

## Installation

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

NB: If you are installing the plugin from Codeberg, you need to state its full url like this (at least for lazy):

```lua
return{
  url = "https://codeberg.org/Euletheia/cmp-pandoc.nvim"
  opts = {},
}
```

```lua
return {
  "Euletheia/cmp-pandoc.nvim",
  opts = {},
}
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'aspeddro/cmp-pandoc.nvim',
  requires = {
    'jbyuki/nabla.nvim' -- optional
  }
}
```

#### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'jbyuki/nabla.nvim' "optional
Plug 'aspeddro/cmp-pandoc.nvim'
```
## Setup

```lua
require'cmp'.setup{
  -- nvim-cmp config
  sources = {
    { name = 'cmp_pandoc' }
    -- other cmp sources
  }
  -- more nvim-cmp config
}
```
With lazy you could also do something like that:



If you are not using lazy, then you should explicitly call `setup()`:
```lua
require("cmp-pandoc").setup({
  -- Your configuration goes here
})
```

## Configuration (optional)

Following are the default configuration for the `setup()` (or `opts = {}` when using lazy).
If you want to override, just modify the option that you want then it will be merged with the default specs.

```lua
{
  -- What types of files cmp-pandoc works.
  -- 'pandoc', 'markdown' and 'rmd' (Rmarkdown)
  -- @type: table of string
  filetypes = { "pandoc", "markdown", "rmd" },
  -- Customize bib documentation
  bibliography = {
    path = {
      "/Path/to/a/bibfile.json", "/Path/to/another/bibfile.bib"
    },
    -- Enable bibliography documentation
    -- @type: boolean
    documentation = true,
    -- Fields to show in documentation
    -- @type: table of string
    fields = { "type", "title", "author", "year" },
  },
  -- Crossref
  crossref = {
    -- Enable documentation
    -- @type: boolean
    documentation = true,
    -- Use nabla.nvim to render LaTeX equation to ASCII
    -- @type: boolean
    enable_nabla = false,
  }
}
```

## YAML Syntax

### Add bibliography file on YAML Header
```yaml
---
bibliography: path/to/references.bib
---
```

### Multiple bibliography files:
```yaml
---
bibliography:
- path/to/references.bib
- path/to/other/references.bib
---
```

### Multiple named bibliography files:
```yaml
---
bibliography:
  main: path/to/references.json
  subbib: path/to/other/references.bib
```

> A YAML metadata block is a valid YAML object, delimited by a line of three hyphens `---` at the top and a line of three hyphens `---` or three dots `...` at the bottom. A YAML metadata block may occur anywhere in the document, but if it is not at the beginning, it must be preceded by a blank line. [Pandoc.org](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block)

For more details, see [pandoc-crossref](https://lierdakil.github.io/pandoc-crossref/)

## Limitations

- YAML metadata inside code blocks with `bibliography` field enable `cmp-pandoc`. The parser does not check if it is inside a fenced code block.
- Pandoc crossref support a couple options to add code block labels, but only the following style is supported:

  ~~~ 
  ```haskell
  main :: IO ()
  main = putStrLn "Hello World!"
  ```

  : Listing caption {#lst:code}
  ~~~

## Recommendations

- [vim-pandoc](https://github.com/vim-pandoc/vim-pandoc)
- [pandoc.nvim](https://github.com/aspeddro/pandoc.nvim)

## Alternatives

- [cmp-pandoc-references](https://github.com/jc-doyle/cmp-pandoc-references/)
