local M = {}

M.setup = function()
  -- nothing
end

local function create_floating_window(opts)
  opts = opts or {}

  local width = opts.width or math.floor(vim.o.columns)
  local height = opts.height or math.floor(vim.o.lines)

  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = { " ", " ", " ", " ", " ", " ", " ", " " }
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

---@class present.Slides
---@field slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: The title of the slide
---@field body string[]: The body of the slide

--- Take some lines and parses them
--- @param lines string[]: The lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {}
  }

  local separator = "^#"

  for _, line in ipairs(lines) do
    -- print(line, "find:", line:find(separator), "|")

    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {}
      }
    else
      table.insert(current_slide.body, line)
    end
  end

  table.insert(slides.slide, current_slide)

  -- print(vim.inspect(slides))
  return slides
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parse_slides(lines)


  -- local win_config = {
  --   relative = "editor",
  --   width = width,
  --   height = height,
  --   col = col,
  --   row = row,
  --   style = "minimal",
  --   border = { " ", " ", " ", " ", " ", " ", " ", " " }
  -- }
  local width = vim.o.columns
  local height = vim.o.lines

  --@type vim.api.keyset.win_config[]
  local windows = {
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      col = 1,
      row = 1,
    },
    body = {
      relative = "editor",
      width = width,
      height = height - 1,
      border = { " ", }
    },
    -- footer = {}
  }

  local float = create_floating_window()

  local set_slide_content = function(idx)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[idx].body)
  end

  local map = require('utils').local_map(float.buf)

  local current_slide = 1
  map('n', 'n', function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    set_slide_content(current_slide)
  end)

  map('n', 'N', function()
    current_slide = math.min(current_slide - 1, 1)
    set_slide_content(current_slide)
  end)

  map('n', 'q', function()
    vim.api.nvim_win_close(float.win, true)
  end)

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0
    }
  }

  for option, config in pairs(restore) do
    vim.opt[option] = config.present
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = float.buf,
    callback = function()
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end
    end
  })

  set_slide_content(current_slide)
end

-- M.start_presentation({ bufnr = 1 })
-- parse_slides {
--   "# Hello",
--   "this is something else",
--   "# World",
--   "this is another thing"
-- }

return M
