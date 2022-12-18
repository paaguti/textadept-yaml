-- Copyright 2007-2022 Mitchell. See LICENSE.

local M = {}

--[[ This comment is for LuaDoc.
---
-- The YAML module for Textadept.
-- It provides utilities for editing YAML documents.
--
-- ### Requirements
-- Install yamllint in your PATH
--
-- ### Key Bindings
--
-- + `Ctrl+&` (`⌘&` | `M-&`)
--   Jump to the anchor for the alias under the caret.
module('_M.yaml')]]

-- Initialise the snippets
snippets.yaml = {}

local lyaml = nil

-- The flags passed to yamllint
M.lyaml_flags=' -f parsable --no-warnings '

-- Returns the output of yamllint as a table of strings
-- @param fname: the file to lint
-- @return outputof yamllint split in lines

local function yamllint(fname)
  local result={}
  local yamllint = assert(io.popen('yamllint'.. M.lyaml_flags.. fname, 'r'))
  local output = yamllint:read('*all')
  yamllint:close()
  for str in string.gmatch(output, "([^\n]+)") do
      table.insert(result, str)
    end
  return result
end

-- Always use spaces.
events.connect(events.LEXER_LOADED, function(name)
  if name ~= 'yaml' then return end
  buffer.use_tabs = false
  buffer.word_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-*'
end)

-- Commands.

-- Verify syntax.
events.connect(events.FILE_AFTER_SAVE, function()
  if buffer:get_lexer() ~= 'yaml' or not lyaml then return end
  buffer:annotation_clear_all()
  local parse_result = yamllint(buffer.filename)
  -- if ok then return end
  for _, v in ipairs(parse_result) do
    fname, line, col, cat, msg = v:match('^([.]+):(%d+):(%d+): ([^ ]+) (.+)$')
    local err_style =  cat == '[error]' and lexer.ERROR or lexer.DEFAULT
    if not line or not col then line, col, msg = 1, 1, errmsg end
    buffer.annotation_text[line] = msg
    buffer.annotation_style[line] = buffer:style_of_name(err_style)
    buffer:goto_pos(buffer:find_column(line, col))
  end
end)

---
-- Jumps to the anchor for the alias underneath the caret.
-- @name goto_anchor
function M.goto_anchor()
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos)
  local anchor = buffer:text_range(s, e):match('^%*(.+)$')
  if anchor then
    buffer:target_whole_document()
    buffer.search_flags = buffer.FIND_WHOLEWORD
    if buffer:search_in_target('&' .. anchor) ~= -1 then buffer:goto_pos(buffer.target_start) end
  end
end

keys.yaml[CURSES and 'meta+&' or OSX and 'cmd+&' or 'ctrl+&'] = M.goto_anchor

-- Initialise lyaml

local function which(fname)
  local path=os.getenv("PATH")
  for dir in string.gmatch(path, "([^:]+)") do
    local fn=dir..'/'..fname
    local attr = lfs.attributes(fn)
    if attr ~= nil then
      local mode,perm=attr['mode'],attr['permissions']
      if mode == 'file' and string.find(perm,'^r.x') ~= nil then
        return fn
      end
    end
  end
end

lyaml=which('yamllint')
return M
