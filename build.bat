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
set "PDF_NAME=nanika_sheila_ethics.pdf"
set "HTML_OUT=%BUILD_DIR%\%HTML_NAME%"
set "EPUB_OUT=%BUILD_DIR%\%EPUB_NAME%"
set "PDF_OUT=%BUILD_DIR%\%PDF_NAME%"
set "ASSETS_OUT=%BUILD_DIR%\assets"
set "PDF_HEADER=src\pandoc\latex\preamble.tex"
set "SITE_DIR=docs"
set "SITE_INDEX=%SITE_DIR%\index.html"
set "SITE_ASSETS=%SITE_DIR%\assets"

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
set "PDF_ENGINE="
set "PDF_HEADER_REL=..\%PDF_HEADER%"
set "PDF_MAINFONT=%PDF_MAINFONT%"
set "PDF_SANFONT=%PDF_SANFONT%"
set "PDF_MONOFONT=%PDF_MONOFONT%"
if "%PDF_MAINFONT%"=="" set "PDF_MAINFONT=Yu Mincho"
if "%PDF_SANFONT%"=="" set "PDF_SANFONT=Yu Gothic"
if "%PDF_MONOFONT%"=="" set "PDF_MONOFONT=MS Gothic"
call :try_find_pdf_engine
if not defined PDF_ENGINE (
  call :augment_texlive_path
  call :try_find_pdf_engine
)

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

REM === Build PDF (if TeX engine exists) ===
if defined PDF_ENGINE (
  goto build_pdf
) else (
  goto skip_pdf
)

:build_pdf
set "SKIP_PDF_BUILD="
if exist "%PDF_NAME%" (
  del /f /q "%PDF_NAME%" >nul 2>&1
  if exist "%PDF_NAME%" (
    set "SKIP_PDF_BUILD=1"
  )
)
if defined SKIP_PDF_BUILD goto pdf_locked
pandoc "%SRC_MD_REL%" ^
  --resource-path="%RESOURCE_PATH%" ^
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers ^
  --wrap=preserve ^
  --metadata-file="%META_REL%" ^
  --shift-heading-level-by=-1 ^
  --toc --toc-depth=2 ^
  --metadata toc-title="–ÚŽŸ" ^
  --lua-filter="%FILTER_REL%" ^
  --include-in-header="%PDF_HEADER_REL%" ^
  --variable mainfont="%PDF_MAINFONT%" ^
  --variable romanfont="%PDF_MAINFONT%" ^
  --variable sansfont="%PDF_SANFONT%" ^
  --variable monofont="%PDF_MONOFONT%" ^
  --variable CJKmainfont="%PDF_MAINFONT%" ^
  --pdf-engine="%PDF_ENGINE%" ^
  --output "%PDF_NAME%"
if errorlevel 1 (
  popd
  echo [ERROR] pandoc PDF build failed
  exit /b 1
)
goto after_pdf

:pdf_locked
echo [WARN] Could not overwrite %PDF_NAME% (is it open?). Skipping PDF build.
goto after_pdf

:skip_pdf
echo [WARN] No LaTeX engine (xelatex/lualatex/pdflatex) found; skipping PDF build.

:after_pdf

popd

REM === Prepare GitHub Pages site output ===
if exist "%SITE_DIR%" (
  rmdir /s /q "%SITE_DIR%"
  if exist "%SITE_DIR%" (
    echo [ERROR] Failed to clean %SITE_DIR%
    exit /b 1
  )
)

mkdir "%SITE_DIR%"
if errorlevel 1 (
  echo [ERROR] Failed to create %SITE_DIR%
  exit /b 1
)

copy /y "%HTML_OUT%" "%SITE_INDEX%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy HTML to %SITE_INDEX%
  exit /b 1
)

copy /y "%BUILD_DIR%\style.css" "%SITE_DIR%\style.css" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy style.css to site
  exit /b 1
)

if exist "%ASSETS_OUT%" (
  xcopy "%ASSETS_OUT%\*" "%SITE_ASSETS%\" /E /I /Y >nul
  if errorlevel 4 (
    echo [ERROR] Failed to copy assets into %SITE_ASSETS%
    exit /b 1
  )
) else (
  echo [WARN] Build assets missing; skipping copy to site.
)

echo [OK] Build finished:
echo   %HTML_OUT%
echo   %EPUB_OUT%
if exist "%PDF_OUT%" echo   %PDF_OUT%
echo   %SITE_INDEX%
exit /b 0

:try_find_pdf_engine
for %%E in (xelatex lualatex pdflatex) do (
  if not defined PDF_ENGINE (
    where %%E >nul 2>nul
    if not errorlevel 1 (
      set "PDF_ENGINE=%%E"
    )
  )
)
exit /b

:augment_texlive_path
for %%B in ("C:\texlive" "%ProgramFiles%\texlive" "%ProgramFiles(x86)%\texlive" "%USERPROFILE%\texlive") do (
  if exist "%%~B" (
    for %%P in ("%%~B\bin\windows" "%%~B\bin\win32") do (
      if exist "%%~P" (
        set "PATH=%%~P;%PATH%"
      )
    )
    for /d %%V in ("%%~B\*") do (
      for %%P in ("%%~fV\bin\windows" "%%~fV\bin\win32") do (
        if exist "%%~P" (
          set "PATH=%%~P;%PATH%"
        )
      )
    )
  )
)
exit /b
