-- Auto restore session
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  nested = true,
  once = true,
  callback = function()
    local argc = vim.fn.argc(-1)
    local restore = argc == 0
    if argc == 1 then
      local arg = vim.fn.argv(0)
      if vim.fn.isdirectory(arg) == 1 then
        vim.cmd("cd " .. vim.fn.fnameescape(arg))
        restore = true
      end
    end
    if restore then
      local cwd = vim.fn.getcwd()
      require("lazy").load({ plugins = { "bufferline.nvim", "persistence.nvim" } })
      require("persistence").load()
      vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    end
  end,
})
