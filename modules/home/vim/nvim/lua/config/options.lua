-- Mode detection (gdot used to do this in init.lua;
-- lazyvim-nix owns init.lua, so we set _G.config_mode here, before
-- the rest of options/plugins/autocmds reference it).
local mode = "nvim"
if vim.env.NVIM_APPNAME == "nvim-vscode" then
  mode = "vscode"
elseif vim.env.KITTY_SCROLLBACK_NVIM == "true" then
  mode = "scrollback"
elseif vim.fn.has("ttyin") == 0 then
  mode = "pager"
end
_G.config_mode = mode

if vim.fn.filereadable(vim.fn.expand("~/.config/vim/vimrc")) == 1 then
  vim.cmd('source ~/.config/vim/vimrc')
end

vim.g.snacks_picker = "snacks"

vim.diagnostic.config({
  float = { source = true },
})

if vim.fn.executable("zsh") == 1 then
  vim.o.shell = "zsh"
end

if _G.config_mode == "pager" then
  vim.opt.number = false
  vim.opt.relativenumber = false
  vim.opt.showtabline = 0
  vim.diagnostic.config({ signs = false, virtual_text = false })

  local map = vim.keymap.set
  map("n", "q", "<cmd>quit!<cr>", { noremap = true })
  map("n", "<PageUp>", "<C-b>", { noremap = true })
  map("n", "<PageDown>", "<C-f>", { noremap = true })

  vim.api.nvim_create_autocmd("StdinReadPost", {
    callback = function() vim.bo.buftype = "nofile" end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.schedule(function() vim.bo.modifiable = false end)
    end,
  })
end
