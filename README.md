# ナニカシイラの倫理

本書は、ナニカシイラの倫理をまとめた文書です。
この倫理は正しさを導く倫理ではなく、判断が破綻する地点を検知するための、倫理システムの記述です。

---

本リポジトリは、Markdown で記述した原稿を Pandoc で HTML / EPUB / PDF へ変換するためのプロジェクトです。  
Mermaid 図は Lua フィルター（`src/pandoc/filter/mermaid_to_svg.lua`）で自動的に SVG/PNG/PDF を生成し、HTML/EPUB/Pages では SVG、PDF では縦横比に応じた PNG を埋め込むので図版の再書き出し忘れがありません。

## 必要なソフトウェア

| 種別           | 必須 | 説明                                                                             |
| -------------- | ---- | -------------------------------------------------------------------------------- |
| Pandoc         | はい | 3.x 系推奨。`winget install --id=Pandoc.Pandoc` などで導入。                     |
| Node.js + npm  | はい | Mermaid CLI を npm から取得するため。LTS（18 以上）を推奨。                      |
| Mermaid CLI    | はい | `npm install` でローカルに導入される（`@mermaid-js/mermaid-cli`）。              |
| LaTeX エンジン | 任意 | PDF を生成したい場合のみ。`xelatex` / `lualatex` / `pdflatex` のいずれかが必要。 |

> **ヒント**: Windows の場合、`winget install --id=OpenJS.NodeJS.LTS` を実行すると Node.js と npm をまとめて入れられます。

## セットアップ手順

1. Pandoc をインストールし、`pandoc --version` でパスが通っていることを確認します。
2. Node.js（npm 含む）をインストールします。
3. リポジトリ直下で `npm install` を実行し、`@mermaid-js/mermaid-cli` をローカルに展開します。  
   - `node_modules/.bin` が作成され、`build.bat` 実行時に自動で PATH に追加されます。
4. PDF を生成したい場合は、TeX Live / MiKTeX などを用意します。

この手順を踏めば、他の端末でも同じ環境を再現できます。

## ビルド方法

### 一括ビルド（推奨）

```powershell
# Windows PowerShell
.\build.bat

# または npm スクリプト経由
npm run build
```

- `build/` 以下に `nanika_sheila_ethics.html` / `nanika_sheila_ethics.epub` / `nanika_sheila_ethics.pdf`（利用可能な LaTeX エンジンが見つかった場合）が出力されます。
  - PDF では既定で `Yu Mincho` / `Yu Gothic` / `MS Gothic` を指定しています（`PDF_MAINFONT` / `PDF_SANFONT` / `PDF_MONOFONT` で任意フォントに変更可）。必要に応じて `Noto Serif/Sans CJK JP` などボールドを含むフォントに切り替えてください。
  - Mermaid 図は SVG と同時に PNG/PDF も生成され、縦長図は自動で PNG に切り替わるため、LaTeX の制約を気にせず図を配置できます。
- `docs/` に GitHub Pages 公開用のファイル（`index.html`、`style.css`、`assets/`）が再生成されます。`docs/` のみコミットすれば GitHub Pages へそのまま反映できます。

### GitHub Pages に公開する

`build.bat` 実行後に生成される `docs/` をそのまま Pages の公開ルートに置いてください。  
例: `gh-pages` ブランチに `docs/` の中身だけをコミットして push する。

### Pandoc コマンドを直接実行したい場合

```powershell
# HTML
pandoc src/main.md `
  --resource-path=src `
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers `
  --wrap=preserve `
  --metadata-file=src/pandoc/metadata.yaml `
  --css=src/css/style.css `
  --lua-filter=src/pandoc/filter/mermaid_to_svg.lua `
  --shift-heading-level-by=-1 `
  --toc --toc-depth=2 `
  --metadata toc-title="目次" `
  --standalone `
  --mathjax `
  --output build/nanika_sheila_ethics.html

# EPUB
pandoc src/main.md `
  --resource-path=src `
  --number-sections=false `
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers `
  --wrap=preserve `
  --metadata-file=src/pandoc/metadata.yaml `
  --css=src/css/style.css `
  --lua-filter=src/pandoc/filter/mermaid_to_svg.lua `
  --shift-heading-level-by=-1 `
  --toc --toc-depth=2 `
  --metadata toc-title="目次" `
  --split-level=1 `
  --output build/nanika_sheila_ethics.epub
```

### PDF について

`build.bat` は PC に `xelatex` / `lualatex` / `pdflatex` のいずれかが見つかれば自動的に PDF を生成します。手動で実行したい場合は下記の通りです。

```powershell
pandoc src/main.md `
  --resource-path=src `
  --from=markdown+hard_line_breaks+auto_identifiers+ascii_identifiers `
  --wrap=preserve `
  --metadata-file=src/pandoc/metadata.yaml `
  --toc --toc-depth=2 `
  --metadata toc-title="目次" `
  --pdf-engine=xelatex `
  --lua-filter=src/pandoc/filter/mermaid_to_svg.lua `
  --output build/nanika_sheila_ethics.pdf
```

`xelatex` が無い場合は `--pdf-engine=lualatex` などに差し替えてください。

### Mermaid のテーマを編集したいとき

- `src/pandoc/filter/mermaid_config.json` に `themeVariables` と `themeCSS` を定義しており、`mmdc --configFile` で自動適用されます。
- 自分のテーマファイルを使いたい場合は、環境変数 `MERMAID_CONFIG` に好きなパスを設定してから `build.bat` / `npm run build` を実行してください。
- CSS ルール内で本文と同じフォント・配色を指定しているので、SVG に直接焼き込まれた図版でもレイアウトが揃います。

## トラブルシューティング

- `mmdc` が見つからない: `npm install` 済みか確認する。`node_modules/.bin/mmdc --version` で確認可能。
- Mermaid のレンダリングに失敗する: `npm install --force` で Puppeteer の依存がそろっているか確認し、再ビルドする。`npx -y @mermaid-js/mermaid-cli@11.12.0` が単体で動けばフィルターからも利用できます。
- 字体に関する警告: PDF 生成時には日本語フォントの設定が必要になる場合があります。
