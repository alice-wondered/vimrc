-- init.lua
local vim = vim

-- Ensure plugins directory exists for lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load lazy.nvim and then your configurations
require("lazy").setup("plugins", {
    change_detection = {
        enabled = true,
        notify = false, -- Disable notification for plugin changes
    },
})

require("config.options")
require("config.keymaps")
require("config.lsp")
