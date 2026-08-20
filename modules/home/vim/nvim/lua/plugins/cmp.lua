return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      ghost_text = { enabled = false },
      list = { selection = { preselect = true, auto_insert = false } },
    },
    keymap = {
      preset = "super-tab",
      ["<C-c>"] = { function(cmp)
        _G.copilot_mode = not (_G.copilot_mode or false)
        cmp.cancel()
        cmp.show()
      end },
      ["<C-t>"] = { function(cmp)
        _G.snippets_mode = not (_G.snippets_mode or false)
        cmp.cancel()
        cmp.show()
      end },
    },
    sources = {
      providers = {
        buffer = { enabled = false },
      },
      transform_items = function(_, items)
        local Snippet = vim.lsp.protocol.CompletionItemKind.Snippet
        local filtered = {}
        for _, item in ipairs(items) do
          if item.kind == Snippet and not (_G.snippets_mode or false) then
            goto continue
          end
          if item.source_id == "copilot" and not (_G.copilot_mode or false) then
            goto continue
          end
          table.insert(filtered, item)
          ::continue::
        end
        return filtered
      end,
    },
  },
}
