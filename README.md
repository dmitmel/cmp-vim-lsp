# cmp-vim-lsp

Integration between [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) and [vim-lsp](https://github.com/prabirshrestha/vim-lsp).

## Setup

```vim
Plug 'hrsh7th/nvim-cmp'
Plug 'prabirshrestha/vim-lsp'
Plug 'dmitmel/cmp-vim-lsp'
```

```lua
require('cmp').setup({
  sources = {
    { name = 'vim_lsp' },
  },
})
```
