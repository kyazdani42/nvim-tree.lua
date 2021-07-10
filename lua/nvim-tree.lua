local luv = vim.loop
local lib = require'nvim-tree.lib'
local config = require'nvim-tree.config'
local colors = require'nvim-tree.colors'
local renderer = require'nvim-tree.renderer'
local fs = require'nvim-tree.fs'
local utils = require'nvim-tree.utils'
local view = require'nvim-tree.view'

local api = vim.api

local M = {}

function M.toggle()
  if view.win_open() then
    view.close()
  else
    if vim.g.nvim_tree_follow == 1 then
      M.find_file(true)
    end
    if not view.win_open() then
      lib.open()
    end
  end
end

function M.close()
  if view.win_open() then
    view.close()
    return true
  end
end

function M.open()
  if not view.win_open() then
    lib.open()
  else
    lib.set_target_win()
  end
end

function M.tab_change()
  vim.schedule(function()
    if not view.win_open() and view.win_open({ any_tabpage = true }) then
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname:match("Neogit") ~= nil or bufname:match("--graph") ~= nil then
        return
      end
      view.open()
    end
  end)
end

local function gen_go_to(mode)
  local icon_state = config.get_icon_state()
  local flags = mode == 'prev_git_item' and 'b' or ''
  local icons = table.concat(vim.tbl_values(icon_state.icons.git_icons), '\\|')
  return function()
    return icon_state.show_git_icon and vim.fn.search(icons, flags)
  end
end

local keypress_funcs = {
  create = fs.create,
  remove = fs.remove,
  rename = fs.rename(false),
  full_rename = fs.rename(true),
  copy = fs.copy,
  copy_name = fs.copy_filename,
  copy_path = fs.copy_path,
  copy_absolute_path = fs.copy_absolute_path,
  cut = fs.cut,
  paste = fs.paste,
  close_node = lib.close_node,
  parent_node = lib.parent_node,
  toggle_ignored = lib.toggle_ignored,
  toggle_dotfiles = lib.toggle_dotfiles,
  toggle_help = lib.toggle_help,
  refresh = lib.refresh_tree,
  first_sibling = function(node) lib.sibling(node, -math.huge) end,
  last_sibling = function(node) lib.sibling(node, math.huge) end,
  prev_sibling = function(node) lib.sibling(node, -1) end,
  next_sibling = function(node) lib.sibling(node, 1) end,
  prev_git_item = gen_go_to('prev_git_item'),
  next_git_item = gen_go_to('next_git_item'),
  dir_up = lib.dir_up,
  close = function() M.close() end,
  preview = function(node)
    if node.entries ~= nil or node.name == '..' then return end
    return lib.open_file('preview', node.relative_path)
  end,
}

function M.on_keypress(mode)
  if view.is_help_ui() and mode ~= 'toggle_help' then return end
  local node = lib.get_node_at_cursor()
  if not node then return end

  if keypress_funcs[mode] then
    return keypress_funcs[mode](node)
  end

  if node.name == ".." then
    return lib.change_dir("..")
  elseif mode == "cd" and node.entries ~= nil then
    return lib.change_dir(lib.get_last_group_node(node).absolute_path)
  elseif mode == "cd" then
    return
  end

  if node.link_to and not node.entries then
    lib.open_file(mode, utils.path_relative(node.absolute_path, vim.fn.getcwd(-1, 0)))
  elseif node.entries ~= nil then
    lib.unroll_dir(node)
  else
    lib.open_file(mode, utils.path_relative(node.absolute_path, vim.fn.getcwd(-1, 0)))
  end
end

function M.refresh()
  lib.refresh_tree()
end

function M.print_clipboard()
  fs.print_clipboard()
end

function M.on_enter()
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  local buftype = api.nvim_buf_get_option(bufnr, 'filetype')
  local ft_ignore = vim.g.nvim_tree_auto_ignore_ft or {}

  local stats = luv.fs_stat(bufname)
  local is_dir = stats and stats.type == 'directory'

  local disable_netrw = vim.g.nvim_tree_disable_netrw or 1
  local hijack_netrw = vim.g.nvim_tree_hijack_netrw or 1
  if is_dir then
    lib.Tree.cwd = vim.fn.expand(bufname)
  end
  local netrw_disabled = hijack_netrw == 1 or disable_netrw == 1
  local should_open = vim.g.nvim_tree_auto_open == 1
    and ((is_dir and netrw_disabled) or bufname == '')
    and not vim.tbl_contains(ft_ignore, buftype)
  lib.init(should_open, should_open)
  if bufname == '' or is_dir then
    vim.cmd ":only"
  end
end

local function is_file_readable(fname)
  local stat = luv.fs_stat(fname)
  if not stat or not stat.type == 'file' or not luv.fs_access(fname, 'R') then return false end
  return true
end

function M.find_file(with_open)
  local bufname = vim.fn.bufname()
  local filepath = vim.fn.fnamemodify(bufname, ':p')
  if not is_file_readable(filepath) or vim.fn.isdirectory(filepath) == 1 then return end

  if with_open then
    M.open()
    view.focus()
  end

  lib.set_index_and_redraw(filepath)
end

function M.resize(size)
  view.View.width = size
  view.resize()
end

function M.on_leave()
  vim.defer_fn(function()
    if not view.win_open() then
      return
    end

    local windows = api.nvim_list_wins()
    local curtab = api.nvim_get_current_tabpage()
    local wins_in_tabpage = vim.tbl_filter(function(w)
      return api.nvim_win_get_tabpage(w) == curtab
    end, windows)
    if #windows == 1 then
      api.nvim_command(':silent qa!')
    elseif #wins_in_tabpage == 1 then
      api.nvim_command(':tabclose')
    end
  end, 50)
end

local function update_root_dir()
  local bufname = api.nvim_buf_get_name(api.nvim_get_current_buf())
  if not is_file_readable(bufname) or not lib.Tree.cwd then return end

  -- this logic is a hack
  -- depending on vim-rooter or autochdir, it would not behave the same way when those two are not enabled
  -- until i implement multiple workspaces/project, it should stay like this
  if bufname:match(utils.path_to_matching_str(lib.Tree.cwd)) then
    return
  end
  local new_cwd = luv.cwd()
  if lib.Tree.cwd == new_cwd then return end

  lib.change_dir(new_cwd)
end

function M.open_on_directory()
  local buf = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(buf)
  if vim.fn.isdirectory(bufname) ~= 1 or bufname == lib.Tree.cwd then
    return
  end

  if not view.win_open() then
    view.open()
  end
  lib.change_dir(bufname)
  lib.set_index_and_redraw(bufname)
  view.focus()
  vim.cmd ":only"
  vim.cmd(":bd "..bufname)
end

function M.buf_enter()
  update_root_dir()
  if vim.g.nvim_tree_follow == 1 then
    M.find_file(false)
  end
end

function M.reset_highlight()
  colors.setup()
  renderer.render_hl(view.View.bufnr)
end

function M.place_cursor_on_node()
  local node = lib.get_node_at_cursor()
  if not node or node.name == ".." then return end
  local line = api.nvim_get_current_line()
  local cursor = api.nvim_win_get_cursor(0)
  local idx = vim.fn.stridx(line, node.name)
  api.nvim_win_set_cursor(0, {cursor[1], idx})
end

view.setup()
colors.setup()
vim.defer_fn(M.on_enter, 1)

return M
