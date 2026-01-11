-- Bootstrap packer
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Plugins
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- Claude Code integration
  use {
    'coder/claudecode.nvim',
    requires = { 'folke/snacks.nvim' },
    config = function()
      require('claudecode').setup({
        auto_start = true,
        diff_opts = {
          open_in_current_tab = false,  -- Diff opens in new tab, keeps main view clean
          auto_close_on_accept = true,
        },
      })
    end
  }

  use 'folke/snacks.nvim'

  -- Telescope for fuzzy finding
  use {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    requires = { 'nvim-lua/plenary.nvim' }
  }

  -- File explorer
  use {
    'nvim-tree/nvim-tree.lua',
    requires = { 'nvim-tree/nvim-web-devicons' },
  }

  -- Buffer line
  use {
    'akinsho/bufferline.nvim',
    tag = '*',
    requires = { 'nvim-tree/nvim-web-devicons' },
  }

  -- Status line
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons' },
  }

  -- Git signs in the gutter
  use {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup({
        current_line_blame = true,
        current_line_blame_opts = {
          delay = 300,
          virt_text_pos = 'eol',
        },
        signs = {
          add          = { text = '│' },
          change       = { text = '│' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']c', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gs.next_hunk() end)
            return '<Ignore>'
          end, {expr=true, desc='Next hunk'})

          map('n', '[c', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gs.prev_hunk() end)
            return '<Ignore>'
          end, {expr=true, desc='Previous hunk'})

          -- Actions
          map('n', '<leader>hs', gs.stage_hunk, {desc='Stage hunk'})
          map('n', '<leader>hr', gs.reset_hunk, {desc='Reset hunk'})
          map('n', '<leader>hp', gs.preview_hunk, {desc='Preview hunk'})
          map('n', '<leader>hb', function() gs.blame_line{full=true} end, {desc='Blame line (full)'})
          map('n', '<leader>tb', gs.toggle_current_line_blame, {desc='Toggle line blame'})
          map('n', '<leader>hd', gs.diffthis, {desc='Diff this'})
        end
      })
    end
  }

  -- Diffview for viewing git diffs
  use {
    'sindrets/diffview.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
      local actions = require('diffview.actions')
      require('diffview').setup({
        enhanced_diff_hl = true,
        view = {
          default = {
            layout = 'diff2_horizontal',
          },
        },
        file_panel = {
          win_config = {
            position = 'left',
            width = 35,
          },
        },
        keymaps = {
          file_panel = {
            { 'n', 'o', function()
              local view = require('diffview.lib').get_current_view()
              if view then
                local file = view:infer_cur_file()
                if file then
                  local path = file.path
                  vim.cmd('DiffviewClose')
                  vim.schedule(function()
                    vim.cmd('edit ' .. vim.fn.fnameescape(path))
                  end)
                end
              end
            end, { desc = 'Close diffview and open file' } },
          },
        },
      })
    end
  }

  -- LSP Support
  use {
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'neovim/nvim-lspconfig',
  }

  -- Autocompletion
  use {
    'hrsh7th/nvim-cmp',
    requires = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
  }

  if packer_bootstrap then
    require('packer').sync()
  end
end)

-- Leader key
vim.g.mapleader = ' '

-- Relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Auto-reload files changed on disk
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  pattern = '*',
  command = 'checktime',
})

-- Buffer navigation (single-view philosophy)
vim.keymap.set('n', '<leader>bn', ':bn<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bp', ':bp<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>bd', ':bd<CR>', { desc = 'Delete buffer' })

-- Telescope setup
require('telescope').setup({
  defaults = {
    -- Fullscreen layout
    layout_strategy = 'horizontal',
    layout_config = {
      width = 0.999,
      height = 0.99,
      preview_height = 0.6,
    },
    initial_mode = 'normal',
    mappings = {
      i = {
        -- ctrl+j/k to move while in insert mode
        ['<C-j>'] = 'move_selection_next',
        ['<C-k>'] = 'move_selection_previous',
      },
      n = {
        ['q'] = 'close',
        ['h'] = 'close',
        ['l'] = 'select_default',
      },
    },
  },
})

-- Nvim-tree setup (50% split with preview)
local ok, nvim_tree = pcall(require, 'nvim-tree')
if ok then
  local api = require('nvim-tree.api')

  local function on_attach(bufnr)
    local function opts(desc)
      return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- Default mappings
    api.config.mappings.default_on_attach(bufnr)

    -- Custom hjkl mappings
    vim.keymap.set('n', 'l', api.node.open.edit, opts('Open'))
    vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory'))

    -- j/k with auto-preview in split (only for files)
    local function preview_if_file()
      local node = api.tree.get_node_under_cursor()
      if node and node.type == 'file' then
        api.node.open.preview()
      end
    end

    vim.keymap.set('n', 'j', function()
      vim.cmd('normal! j')
      preview_if_file()
    end, opts('Down + Preview'))

    vim.keymap.set('n', 'k', function()
      vim.cmd('normal! k')
      preview_if_file()
    end, opts('Up + Preview'))

    vim.keymap.set('n', '<Tab>', api.node.open.preview, opts('Preview'))
  end

  nvim_tree.setup({
    on_attach = on_attach,
    view = {
      width = '50%',
      side = 'left',
    },
    actions = {
      open_file = {
        quit_on_open = true,
      },
    },
  })
end

vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'File explorer' })

-- Bufferline setup
local ok_bl, bufferline = pcall(require, 'bufferline')
if ok_bl then
  vim.opt.termguicolors = true
  bufferline.setup({})
end

-- Lualine setup
local ok_ll, lualine = pcall(require, 'lualine')
if ok_ll then
  lualine.setup({
    options = {
      theme = 'auto',
      component_separators = { left = '', right = '' },
      section_separators = { left = '', right = '' },
    },
  })
end

-- LSP Setup
local ok_mason, mason = pcall(require, 'mason')
if ok_mason then
  mason.setup()
  require('mason-lspconfig').setup({
    ensure_installed = { 'pyright', 'ts_ls' },
  })

  local lspconfig = require('lspconfig')
  local capabilities = require('cmp_nvim_lsp').default_capabilities()

  -- LSP keybindings (set when LSP attaches to buffer)
  local on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set('n', 'gd', ':Telescope lsp_definitions<CR>', vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
    vim.keymap.set('n', 'gr', ':Telescope lsp_references<CR>', vim.tbl_extend('force', opts, { desc = 'Find references' }))
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, vim.tbl_extend('force', opts, { desc = 'Go to declaration' }))
    vim.keymap.set('n', 'gi', ':Telescope lsp_implementations<CR>', vim.tbl_extend('force', opts, { desc = 'Go to implementation' }))
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'Hover docs' }))
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'Code action' }))
    vim.keymap.set('n', '<leader>ds', ':Telescope lsp_document_symbols<CR>', vim.tbl_extend('force', opts, { desc = 'Document symbols' }))
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, vim.tbl_extend('force', opts, { desc = 'Previous diagnostic' }))
    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, vim.tbl_extend('force', opts, { desc = 'Next diagnostic' }))
  end

  -- Configure language servers
  lspconfig.pyright.setup({ capabilities = capabilities, on_attach = on_attach })
  lspconfig.ts_ls.setup({ capabilities = capabilities, on_attach = on_attach })
end

-- Autocompletion setup
local ok_cmp, cmp = pcall(require, 'cmp')
if ok_cmp then
  local luasnip = require('luasnip')
  cmp.setup({
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { 'i', 's' }),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
    }, {
      { name = 'buffer' },
      { name = 'path' },
    }),
  })
end

-- Telescope keymaps
vim.keymap.set('n', '<leader>ff', ':Telescope find_files<CR>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', ':Telescope live_grep<CR>', { desc = 'Live grep' })
vim.keymap.set('n', '<leader>bb', ':Telescope buffers<CR>', { desc = 'Buffer picker' })
vim.keymap.set('n', '<leader>fh', ':Telescope help_tags<CR>', { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fk', ':Telescope keymaps<CR>', { desc = 'Search keymaps' })
vim.keymap.set('n', '<leader>fc', ':Telescope live_grep<CR>', { desc = 'Search file contents' })

-- Claude Code
vim.keymap.set('n', '<leader>cc', ':ClaudeCode<CR>', { desc = 'Claude Code' })

-- Diffview keymaps
vim.keymap.set('n', '<leader>gd', ':DiffviewOpen<CR>', { desc = 'Open diff view' })
vim.keymap.set('n', '<leader>gc', ':DiffviewClose<CR>', { desc = 'Close diff view' })
vim.keymap.set('n', '<leader>gh', ':DiffviewFileHistory %<CR>', { desc = 'File history (current)' })
vim.keymap.set('n', '<leader>gH', ':DiffviewFileHistory<CR>', { desc = 'File history (branch)' })

-- Transparent background
vim.api.nvim_set_hl(0, 'Normal', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'SignColumn', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'LineNr', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'EndOfBuffer', { bg = 'NONE' })
