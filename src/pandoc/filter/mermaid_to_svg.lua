-- filters/mermaid_to_svg.lua
-- Pandoc Lua filter: Mermaid fenced code -> SVG file -> image include
-- Requires: mmdc (mermaid-cli)
-- Usage: pandoc ... --lua-filter=filters/mermaid_to_svg.lua

local system = pandoc.system
local path = pandoc.path

local outdir = "assets/mermaid"

local function ensure_dir(dir)
  -- mkdir -p compatible
  system.make_directory(dir, true)
end

local function file_exists(fname)
  local f = io.open(fname, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function write_file(fname, content)
  local f = assert(io.open(fname, "w"))
  f:write(content)
  f:close()
end

local function sha1(s)
  -- pandoc has a built-in sha1 helper for filters
  -- If not available in your pandoc build, replace with a simple hash scheme.
  return pandoc.sha1(s)
end

local function script_dir()
  local info = debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local script_path = path.normalize(info.source:sub(2))
    return path.directory(script_path)
  end
  return "."
end

local MERMAID_NPM_SPEC = "@mermaid-js/mermaid-cli@11.12.0"
local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local resolved_cmd = { mmdc = nil, npx = nil }
local FILTER_DIR = script_dir()
local DEFAULT_CONFIG = path.join({FILTER_DIR, "mermaid_config.json"})
local CONFIG_PATH = os.getenv("MERMAID_CONFIG") or DEFAULT_CONFIG
local CONFIG_WARNED = false

local function split_path(path_env)
  local entries = {}
  if not path_env then
    return entries
  end
  local sep = IS_WINDOWS and ";" or ":"
  for part in string.gmatch(path_env, "([^" .. sep .. "]+)") do
    table.insert(entries, part)
  end
  return entries
end

local function find_command(base)
  if resolved_cmd[base] ~= nil then
    return resolved_cmd[base] or nil
  end

  local path_env = os.getenv("PATH")
  local dirs = split_path(path_env)
  local exts
  if IS_WINDOWS then
    exts = {".cmd", ".bat", ".exe", ".com", ""}
  else
    exts = {""}
  end

  local sep = IS_WINDOWS and "\\" or "/"

  local function try_dirs(list)
    for _, dir in ipairs(list) do
      local clean_dir = dir:gsub('"', "")
      if #clean_dir > 0 then
        for _, ext in ipairs(exts) do
          local candidate = clean_dir .. sep .. base .. ext
          local f = io.open(candidate, "rb")
          if f then
            f:close()
            resolved_cmd[base] = candidate
            return candidate
          end
        end
      end
    end
    return nil
  end

  local found = try_dirs(dirs)
  if found then
    return found
  end

  if IS_WINDOWS then
    local fallbacks = {}
    local pf = os.getenv("ProgramFiles")
    if pf then
      table.insert(fallbacks, pf .. "\\nodejs")
    end
    local pf86 = os.getenv("ProgramFiles(x86)")
    if pf86 then
      table.insert(fallbacks, pf86 .. "\\nodejs")
    end
    local appdata = os.getenv("APPDATA")
    if appdata then
      table.insert(fallbacks, appdata .. "\\npm")
    end
    local sysroot = os.getenv("SystemRoot")
    if sysroot then
      table.insert(fallbacks, sysroot .. "\\System32")
    end

    local fallback_found = try_dirs(fallbacks)
    if fallback_found then
      return fallback_found
    end
  end

  resolved_cmd[base] = false
  return nil
end

local function run_renderer(cmd, prefix_args, mmd_path, svg_path)
  local args = {}
  for _, v in ipairs(prefix_args) do
    table.insert(args, v)
  end
  table.insert(args, "-i")
  table.insert(args, mmd_path)
  table.insert(args, "-o")
  table.insert(args, svg_path)
  table.insert(args, "-b")
  table.insert(args, "transparent")
  if CONFIG_PATH and file_exists(CONFIG_PATH) then
    table.insert(args, "--configFile")
    table.insert(args, CONFIG_PATH)
  elseif not CONFIG_WARNED then
    io.stderr:write("[mermaid_to_svg] Mermaid config not found at " .. tostring(CONFIG_PATH) .. "\n")
    CONFIG_WARNED = true
  end

  local ok, err = pcall(function()
    pandoc.pipe(cmd, args, "")
  end)
  if not ok then
    io.stderr:write("[mermaid_to_svg] " .. cmd .. " failed: " .. tostring(err) .. "\n")
    return false, err
  end
  return true
end

local function run_mermaid(mmd_path, svg_path)
  local mmdc_cmd = find_command("mmdc")
  if mmdc_cmd then
    if run_renderer(mmdc_cmd, {}, mmd_path, svg_path) then
      return true
    else
      resolved_cmd["mmdc"] = false
    end
  end

  local npx_cmd = find_command("npx")
  if npx_cmd then
    if run_renderer(npx_cmd, {"-y", MERMAID_NPM_SPEC}, mmd_path, svg_path) then
      return true
    else
      resolved_cmd["npx"] = false
    end
  end

  io.stderr:write("[mermaid_to_svg] Mermaid CLI (mmdc) not found. Install with `npm install` or ensure it is on PATH.\n")
  return false
end

function CodeBlock(el)
  if not el.classes:includes("mermaid") then
    return nil
  end

  ensure_dir(outdir)

  local src = el.text
  local id = sha1(src)
  local mmd_path = path.join({outdir, id .. ".mmd"})
  local svg_path = path.join({outdir, id .. ".svg"})

  -- Always rewrite source to ensure renderer gets latest text
  write_file(mmd_path, src)

  -- Always re-render so build.bat output never goes stale
  if not run_mermaid(mmd_path, svg_path) then
    return el
  end

  -- Replace CodeBlock with an image referencing the SVG
  -- Use Relative path so resource-path / packaging picks it up
  local img = pandoc.Image({}, svg_path, "diagram")
  -- Optional: set width via attributes (works best in HTML/PDF; EPUB readers vary)
  -- img.attributes["style"] = "max-width: 100%; height: auto;"
  return pandoc.Para({img})
end
