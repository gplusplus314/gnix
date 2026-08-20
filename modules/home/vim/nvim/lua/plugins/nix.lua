return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nil_ls = { enabled = false },
        nixd = {
          before_init = function(_, config)
            local root = config.root_dir or vim.fn.getcwd()
            local f = root .. "/.nixd.json"
            if vim.fn.filereadable(f) ~= 1 then
              return
            end
            local raw = table.concat(vim.fn.readfile(f), "\n")
            local subs = {
              ROOT = root,
              HOST = vim.uv.os_gethostname(),
              USER = vim.uv.os_get_passwd().username,
            }
            raw = raw:gsub("%${(%w+)}", function(k) return subs[k] or ("${" .. k .. "}") end)
            local ok, data = pcall(vim.json.decode, raw)
            if ok and type(data) == "table" then
              config.settings = vim.tbl_deep_extend("force", config.settings or {}, data)
            end
          end,
          settings = { nixd = {} },
        },
      },
    },
  },
}
