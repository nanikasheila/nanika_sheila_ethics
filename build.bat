@echo off
setlocal enabledelayedexpansion

REM === (optional) UTF-8 console ===
REM chcp 65001 >nul

REM === Resolve project root (directory of this bat) ===
set "ROOT=%~dp0"
cd /d "%ROOT%"

REM === Add local node_modules/.bin to PATH so local mmdc works ===
set "NODE_BIN=%ROOT%node_modules\.bin"
if exist "%NODE_BIN%" (
  set "PATH=%NODE_BIN%;%PATH%"
)

REM === Check pandoc exists ===
where pandoc >nul 2>nul
if errorlevel 1 (
  echo [ERROR] pandoc not found in PATH.
  echo Install pandoc and ensure it is on PATH.
  exit /b 1
)

REM === Paths (adjust if needed) ===
set "SRC_MD=src\main.md"
set "META=src\pandoc\metadata.yaml"
set "STYLE=src\css\style.css"
set "FILTER=src\pandoc\filter\mermaid_to_svg.lua"
set "ASSETS_DIR=src\assets"

set "BUILD_DIR=build"
set "HTML_NAME=nanika_sheila_ethics.html"
set "EPUB_NAME=nanika_sheila_ethics.epub"
set "HTML_OUT=%BUILD_DIR%\%HTML_NAME%"
set "EPUB_OUT=%BUILD_DIR%\%EPUB_NAME%"
set "ASSETS_OUT=%BUILD_DIR%\assets"

REM === Create output dirs ===
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM === Copy CSS for web output (so paths never break) ===
copy /y "%STYLE%" "%BUILD_DIR%\style.css" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy style.css
  exit /b 1
)

REM === Copy ASSETS for web/epub output (so paths never break) ===
if exist "%ASSETS_DIR%" (
  if not exist "%ASSETS_OUT%" mkdir "%ASSETS_OUT%"
  xcopy "%ASSETS_DIR%\*" "%ASSETS_OUT%\" /E /I /Y >nul
  if errorlevel 4 (
    echo [ERROR] Failed to copy assets from %ASSETS_DIR% to %ASSETS_OUT%
    exit /b 1
  )
) else (
  echo [WARN] Assets directory not found: %ASSETS_DIR%
)

set "SRC_MD_REL=..\%SRC_MD%"
set "META_REL=..\%META%"
set "FILTER_REL=..\%FILTER%"
set "RESOURCE_PATH=.;..\\src"

pushd "%BUILD_DIR%"

REM === Build HTML ===
pandoc "%SRC_MD_REL%" ^
  --resource-path="%RESOURCE_PATH%" ^
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers ^
  --wrap=preserve ^
  --metadata-file="%META_REL%" ^
  --css=style.css ^
  --lua-filter="%FILTER_REL%" ^
  --shift-heading-level-by=-1 ^
  --toc --toc-depth=2 ^
  --metadata toc-title="–ÚŽŸ" ^
  --standalone ^
  --mathjax ^
  --output "%HTML_NAME%"
if errorlevel 1 (
  popd
  echo [ERROR] pandoc HTML build failed
  exit /b 1
)

REM === Build EPUB ===
pandoc "%SRC_MD_REL%" ^
  --resource-path="%RESOURCE_PATH%" ^
  --number-sections=false ^
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers ^
  --wrap=preserve ^
  --metadata-file="%META_REL%" ^
  --css=style.css ^
  --lua-filter="%FILTER_REL%" ^
  --shift-heading-level-by=-1 ^
  --toc --toc-depth=2 ^
  --metadata toc-title="–ÚŽŸ" ^
  --split-level=1 ^
  --output "%EPUB_NAME%"
if errorlevel 1 (
  popd
  echo [ERROR] pandoc EPUB build failed
  exit /b 1
)

popd

echo [OK] Build finished:
echo   %HTML_OUT%
echo   %EPUB_OUT%
exit /b 0
