-- lua/mini-setup.lua
local vim = vim

-- Mini.nvim configuration
-- Load only the modules you need
require('mini.comment').setup()
require('mini.pairs').setup()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.snippets').setup({ -- Replaces LuaSnip and friendly-snippets
    -- Define your snippets here or load from files
    -- Example:
    -- {
    --   _ = {
    --     ['func'] = 'function () return true end',
    --   },
    -- },
    -- For full LuaSnip compatibility, you might need to enable `luasnip_compatibility = true`
    -- and make sure your snippets conform to LuaSnip's format.
    -- Otherwise, define simple snippets directly here.
})
require('mini.completion').setup({})
