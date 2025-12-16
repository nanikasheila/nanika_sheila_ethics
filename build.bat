@echo off
setlocal enabledelayedexpansion

REM === (optional) UTF-8 console ===
REM chcp 65001 >nul

REM === Resolve project root (directory of this bat) ===
set "ROOT=%~dp0"
cd /d "%ROOT%"

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
set "ASSET=src\assets\flow.drawio.svg"

set "BUILD_DIR=build"
set "HTML_OUT=%BUILD_DIR%\nanika_sheila_ethics.html"
set "EPUB_OUT=%BUILD_DIR%\nanika_sheila_ethics.epub"

REM === Create output dirs ===
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM === Copy CSS for web output (so paths never break) ===
copy /y "%STYLE%" "%BUILD_DIR%\style.css" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy style.css
  exit /b 1
)

REM === Copy ASSET for web output (so paths never break) ===
copy /y "%ASSET%" "%BUILD_DIR%\flow.drawio.svg" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy flow.drawio.svg
  exit /b 1
)

REM === Build HTML ===
pandoc "%SRC_MD%" ^
  --from=markdown+hard_line_breaks ^
  --wrap=preserve ^
  --metadata-file="%META%" ^
  --css=style.css ^
  --toc --toc-depth=3 ^
  --variable toc-title="–ÚŽŸ" ^
  --standalone ^
  --mathjax ^
  --output "%HTML_OUT%"
if errorlevel 1 (
  echo [ERROR] pandoc HTML build failed
  exit /b 1
)

REM === Build EPUB ===
pandoc "%SRC_MD%" ^
  --from=markdown+hard_line_breaks ^
  --wrap=preserve ^
  --metadata-file="%META%" ^
  --css=src\css\style.css ^
  --toc --toc-depth=3 ^
  --variable toc-title="–ÚŽŸ" ^
  --split-level=2 ^
  --output "%EPUB_OUT%"
if errorlevel 1 (
  echo [ERROR] pandoc EPUB build failed
  exit /b 1
)

echo [OK] Build finished:
echo   %HTML_OUT%
echo   %EPUB_OUT%
exit /b 0
