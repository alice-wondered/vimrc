local vim = vim
local Plug = vim.fn['plug#']

vim.call('plug#begin')
--- " The default plugin directory will be as follows:
--- "   - Vim (Linux/macOS): '~/.vim/plugged'
--- "   - Vim (Windows): '~/vimfiles/plugged'
--- "   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
--- " You can specify a custom plugin directory by passing it as the argument
--- "   - e.g. `call plug#begin('~/.vim/plugged')`
--- "   - Avoid using standard Vim directory names like 'plugin'

--- " Make sure you use single quotes


Plug('nvim-lualine/lualine.nvim')
Plug('nvim-tree/nvim-web-devicons')
Plug('junegunn/fzf', { ['do'] = function() 
  vim.fn['fzf#install()']() 
end })
Plug('junegunn/fzf.vim')


Plug('preservim/nerdtree')
--- Plug('vim-airline/vim-airline')

Plug('joshdick/onedark.vim')

vim.call('plug#end')

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
