local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Split navigation (override LazyVim defaults)
map("n", "<C-Left>", "<C-w>h", opts)
map("n", "<C-Right>", "<C-w>l", opts)
map("n", "<C-Up>", "<C-w>k", opts)
map("n", "<C-Down>", "<C-w>j", opts)

-- Buffers
map("n", "<Home>", "<cmd>bprevious<cr>", opts)
map("n", "<End>", "<cmd>bnext<cr>", opts)
map("n", "<S-Home>", "<cmd>BufferLineMovePrev<cr>", opts)
map("n", "<S-End>", "<cmd>BufferLineMoveNext<cr>", opts)
map("n", "<A-p>", "<cmd>BufferLineTogglePin<cr>", opts)
map("n", "<A-x>", "<cmd>BufferLinePickClose<cr>", opts)
