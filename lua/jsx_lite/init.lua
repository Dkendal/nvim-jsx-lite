local a = require 'async'
local async, await, main = a.sync, a.wait, a.main

local Mod = {}

local node_path = '/home/dylan/.asdf/installs/nodejs/12.18.2/bin/node'
local bin_path = '/home/dylan/code/github.com/Dkendal/jsx-lite/packages/cli/bin/jsx-lite'

-- Create a new window for the buffer
local function openbuf(buf)
  if fn.bufwinnr(buf) == -1 then
    cmd(F('vertical botright sb ${buf}', { buf = buf }))
  end
end

local function getbuf()
  local name = '[Jsx-lite Output]'

  local buf = nil

  if fn.bufexists(name) == 0 then
    buf = api.nvim_create_buf(true, true)
    api.nvim_buf_set_name(buf, name)
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'buflisted', true)
    api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  else
    buf = fn.bufnr(name)
  end

  if (buf == -1) then
    error('couldn\'t create buffer')
  end

  return buf
end

local timer
local id = 0

function Mod.live_preview(target)
  id = id + 1
  local local_id = id

  api.nvim_buf_attach(0, false, {
    on_lines = vim.schedule_wrap(function()
      if id ~= local_id then
        return true
      end

      if timer then
        timer:close()
      end

      timer = vim.defer_fn(function()
        Mod.preview(target)
        timer = nil
      end, 100)
    end)
  })

  Mod.preview(target)
end

-- @param target string
-- @return nil
function Mod.preview(target)
  local buf = getbuf()
  api.nvim_buf_set_option(buf, 'filetype', 'typescriptreact')

  if fn.executable(bin_path) ~= 1 then
    error('executable ${bin_path} not found' % { bin_path = bin_path })
  end

  -- @type table<number, string>
  local lines = fn.nvim_buf_get_lines(0, 0, -1, false)

  local cmd = { node_path, bin_path, '--to', target, '-' }

  local chunks = {}

  local job = fn.jobstart(cmd, {
    on_exit = function(job, data, err)
      api.nvim_buf_set_lines(buf, 0, -1, false, chunks)
    end,

    on_sterr = function(job, data, err)
      for index, line in ipairs(data) do
        table.insert(chunks, line)
      end
    end,

    on_stdout = function(job, data, err)
      for index, line in ipairs(data) do
        table.insert(chunks, line)
      end
    end
  })

  if job == 0 then
    error 'job failed: invalid args'
  end

  if job == -1 then
    error 'job failed: not executable'
  end

  fn.chansend(job, lines)
  fn.chanclose(job, 'stdin')

  openbuf(buf)
end

function Mod.init()
  vim.cmd [[
  command! -nargs=1 JsxLiteLivePreview :lua require("jsx-lite").live_preview(<f-args>)<CR>
  ]]
end

Mod.init()

return Mod

return Mod
