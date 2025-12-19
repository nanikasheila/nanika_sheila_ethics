-- filters/mermaid_to_svg.lua
-- Pandoc Lua filter: Mermaid fenced code -> SVG file -> image include
-- Requires: mmdc (mermaid-cli)
-- Usage: pandoc ... --lua-filter=filters/mermaid_to_svg.lua

local system = pandoc.system
local path = pandoc.path
local utils = pandoc.utils

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

local function read_file(pathname)
  local f = io.open(pathname, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
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

local function render_mermaid(mmd_path, output_path)
  local mmdc_cmd = find_command("mmdc")
  if mmdc_cmd then
    if run_renderer(mmdc_cmd, {}, mmd_path, output_path) then
      return true
    else
      resolved_cmd["mmdc"] = false
    end
  end

  local npx_cmd = find_command("npx")
  if npx_cmd then
    if run_renderer(npx_cmd, {"-y", MERMAID_NPM_SPEC}, mmd_path, output_path) then
      return true
    else
      resolved_cmd["npx"] = false
    end
  end

  io.stderr:write("[mermaid_to_svg] Mermaid CLI (mmdc) not found. Install with `npm install` or ensure it is on PATH.\n")
  return false
end

local function is_latex_output()
  local format = (FORMAT or ""):lower()
  return format:match("latex") or format:match("beamer") or format:match("pdf")
end

local function latex_friendly_path(p)
  if IS_WINDOWS then
    return p:gsub("\\", "/")
  end
  return p
end

local function svg_aspect_ratio(svg_file)
  local content = read_file(svg_file)
  if not content then
    return nil
  end
  local minx, miny, width, height =
    content:match('viewBox%s*=%s*"([%-0-9%.]+)%s+([%-0-9%.]+)%s+([%-0-9%.]+)%s+([%-0-9%.]+)"')
  if not width or not height then
    return nil
  end
  local w = tonumber(width)
  local h = tonumber(height)
  if not w or not h or w == 0 then
    return nil
  end
  return h / w
end

local first_section_seen = false

function CodeBlock(el)
  if not el.classes:includes("mermaid") then
    return nil
  end

  ensure_dir(outdir)

  local src = el.text
  local id = sha1(src)
  local mmd_path = path.join({outdir, id .. ".mmd"})
  local svg_path = path.join({outdir, id .. ".svg"})
  local pdf_path = path.join({outdir, id .. ".pdf"})
  local png_path = path.join({outdir, id .. ".png"})

  -- Always rewrite source to ensure renderer gets latest text
  write_file(mmd_path, src)

  -- Always re-render so build.bat output never goes stale
  if not render_mermaid(mmd_path, svg_path) then
    return el
  end

  local format = (FORMAT or ""):lower()
  local need_pdf = format:match("latex") or format:match("beamer") or format:match("pdf")
  local need_png_base = format:match("docx") or format:match("pptx") or format:match("odt") or format:match("rtf")

  local aspect_ratio = svg_aspect_ratio(svg_path)
  local latex_tall_diagram = false

  if need_pdf then
    local rendered = render_mermaid(mmd_path, pdf_path)
    if not rendered then
      return el
    end
    if is_latex_output() and aspect_ratio and aspect_ratio > 1.8 then
      latex_tall_diagram = true
    end
  end

  local need_png = need_png_base or (latex_tall_diagram and is_latex_output())
  if need_png then
    if not render_mermaid(mmd_path, png_path) then
      return el
    end
  end

  if is_latex_output() then
    local latex_path = latex_tall_diagram and latex_friendly_path(png_path) or latex_friendly_path(pdf_path)
    local tall_diagram = latex_tall_diagram
    local figure_tex
    if tall_diagram then
      figure_tex = string.format([[
\begin{center}
\includegraphics[keepaspectratio,width=\linewidth,height=0.9\textheight]{%s}
\end{center}
\par\medskip
]], latex_path)
    else
      figure_tex = string.format([[
\begin{center}
\includegraphics[keepaspectratio,width=\linewidth,height=0.8\textheight]{%s}
\end{center}
\par\medskip
]], latex_path)
    end
    return pandoc.RawBlock("latex", figure_tex)
  end

  local chosen_path = svg_path
  if need_png then
    chosen_path = png_path
  end
  local img = pandoc.Image({}, chosen_path, "diagram")
  img.attributes["style"] = "display:block;margin:1em auto;text-align:center;"
  return pandoc.Para({img})
end

function Header(el)
  if not is_latex_output() then
    return nil
  end
  local blocks = {}
  local heading_text = utils.stringify(el.content or {}):gsub("%s+", "")
  if el.level == 2 then
    if not first_section_seen then
      first_section_seen = true
      table.insert(blocks, pandoc.RawBlock("latex", "\\clearpage"))
    elseif heading_text:find("奥付") then
      table.insert(blocks, pandoc.RawBlock("latex", "\\clearpage"))
    end
    table.insert(blocks, pandoc.RawBlock("latex", "\\Needspace{10\\baselineskip}"))
  elseif el.level == 3 then
    table.insert(blocks, pandoc.RawBlock("latex", "\\Needspace{10\\baselineskip}"))
  elseif el.level == 4 then
    table.insert(blocks, pandoc.RawBlock("latex", "\\Needspace{7\\baselineskip}"))
  end

  if #blocks > 0 then
    table.insert(blocks, el)
    return blocks
  end
  return nil
end
