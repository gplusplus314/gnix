return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      event_handlers = {
        {
          event = "file_opened",
          handler = function()
            require("neo-tree.command").execute({ action = "close" })
          end,
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      input = { enabled = false },
      picker = {
        layout = "vertical",
        height = { min = 30, max = 0.9 },
        width = { min = 80, max = 0.9 },
        win = {
          input = {
            keys = {
              ["<C-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["<C-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["<C-f>"] = { "list_scroll_down", mode = { "i", "n" } },
              ["<C-b>"] = { "list_scroll_up", mode = { "i", "n" } },
              ["<Esc>"] = { "close", mode = { "i", "n" } },
            },
          },
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
    },
  },
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        always_show_bufferline = _G.config_mode == "nvim",
      },
    },
  },
  {
    "folke/persistence.nvim",
    opts = {
      enabled = _G.config_mode == "nvim",
    },
  },
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = false,
      },
      notify = { enabled = false },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = (_G.config_mode == "scrollback" or _G.config_mode == "pager")
        and "retrobox" or "tokyonight-night",
    },
  },
  {
    "m00qek/baleia.nvim",
    cond = function() return _G.config_mode == "pager" end,
    lazy = false,
    config = function()
      local baleia = require("baleia").setup({})
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function() baleia.once(0) end,
      })
    end,
  },
}
