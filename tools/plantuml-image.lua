--[[
  Pandoc Lua filter: renders ```plantuml fenced code blocks to PNG images
  so that the generated PDF contains diagrams instead of raw PlantUML source.
  On GitHub the same Markdown keeps the readable PlantUML code block.

  Requires: java on PATH and a plantuml.jar (path via PLANTUML_JAR env var,
  defaults to <cwd>/tools/plantuml.jar). Rendered PNGs are cached by content
  hash in <cwd>/tools/_puml_cache.
]]

local system = require 'pandoc.system'
local path = require 'pandoc.path'

local cwd = system.get_working_directory()

local jar = os.getenv("PLANTUML_JAR")
if jar == nil or jar == "" then
  jar = path.join({ cwd, "tools", "plantuml.jar" })
end

local outdir = path.join({ cwd, "tools", "_puml_cache" })

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

function CodeBlock(block)
  if not block.classes:includes("plantuml") then
    return nil
  end

  pandoc.system.make_directory(outdir, true)

  local hash = pandoc.utils.sha1(block.text)
  local base = path.join({ outdir, hash })
  local puml = base .. ".puml"
  local png = base .. ".png"

  if not file_exists(png) then
    local fh = io.open(puml, "w")
    fh:write(block.text)
    fh:close()
    local cmd = string.format('java -jar "%s" -charset UTF-8 -tpng "%s"', jar, puml)
    os.execute(cmd)
  end

  -- Emit a Windows-style absolute path with forward slashes so that the
  -- native pandoc binary (and the typst PDF engine) can read/embed the image.
  local src = png:gsub("\\", "/")
  return pandoc.Para({ pandoc.Image({}, src) })
end
