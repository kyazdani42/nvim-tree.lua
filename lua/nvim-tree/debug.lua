local luv = vim.loop
local time = {}

local function get_cache_data()
  local fd = luv.fs_open("/tmp/nvim-tree-perf.log", "r", 438)
  if not fd then return "" end
  local stat = luv.fs_fstat(fd)
  local data = luv.fs_read(fd, stat.size, 0)
  luv.fs_close(fd)
  return data
end

local function write_to_cache(value)
  local data = get_cache_data()

  local fd = luv.fs_open("/tmp/nvim-tree-perf.log", "w", 438)
  luv.fs_write(fd, data..value..'\n', 0)
  vim.loop.fs_close(fd)
end

return {
  mark = function(mark_name)
    time[mark_name] = vim.loop.hrtime()
  end,
  debug = function(mark_name)
    local v = (vim.loop.hrtime() - time[mark_name]) / 1000000
    write_to_cache('executed '..mark_name..' in '..v..'ms')
  end
}
