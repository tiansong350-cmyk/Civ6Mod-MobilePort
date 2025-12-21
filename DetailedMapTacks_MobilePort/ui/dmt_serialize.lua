-- ===========================================================================
-- JSON Serializer for DMT (Replaces Metalua to fix iOS loadstring ban)
-- Based on a lightweight JSON implementation
-- ===========================================================================

local json = {}

-- Internal functions
local function kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  -- Escaped characters
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos) end
  return val, pos + #num_str
end

local function parse_val(str, pos)
  local early_end_error = 'End of input found while parsing value.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '{' then -- Object
    local obj = {}
    local delim_found = true
    pos = pos + 1
    while true do
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == '}' then return obj, pos + 1 end
      if not delim_found then error('Comma missing between object items.') end
      local key, new_pos = parse_val(str, pos)
      pos = new_pos
      pos = skip_delim(str, pos, ':', true)
      local val, new_pos = parse_val(str, pos)
      pos = new_pos
      obj[key] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif c == '[' then -- Array
    local arr = {}
    local delim_found = true
    pos = pos + 1
    while true do
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == ']' then return arr, pos + 1 end
      if not delim_found then error('Comma missing between array items.') end
      local val, new_pos = parse_val(str, pos)
      pos = new_pos
      table.insert(arr, val)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif c == '"' then -- String
    return parse_str_val(str, pos + 1)
  elseif c == '-' or c:match('%d') then -- Number
    return parse_num_val(str, pos)
  elseif str:match('^true', pos) then
    return true, pos + 4
  elseif str:match('^false', pos) then
    return false, pos + 5
  elseif str:match('^null', pos) then
    return nil, pos + 4
  else
    error('Unknown token at position ' .. pos)
  end
end

-- Public functions
function json.encode(obj)
  local kind = kind_of(obj)
  if kind == 'array' then
    local s = '['
    for i, val in ipairs(obj) do
      if i > 1 then s = s .. ',' end
      s = s .. json.encode(val)
    end
    return s .. ']'
  elseif kind == 'table' then
    local s = '{'
    local first = true
    for k, v in pairs(obj) do
      if not first then s = s .. ',' end
      s = s .. '"' .. escape_str(tostring(k)) .. '":' .. json.encode(v)
      first = false
    end
    return s .. '}'
  elseif kind == 'string' then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == 'number' then
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    return '"<unserializable>"'
  end
end

function json.decode(str)
  if type(str) ~= 'string' then return nil end
  local status, res, pos = pcall(parse_val, str, 1)
  if status then return res else return nil end
end

-- ===========================================================================
-- DMT Interface (Maps to JSON)
-- ===========================================================================

function serialize(x)
    return json.encode(x);
end

function deserialize(x)
    return json.decode(x);
end
