# ナニカシイラの倫理

ナニカシイラの倫理

EPUB生成コマンド

```bash
pandoc src/main.md --from=markdown+hard_line_breaks --wrap=preserve --metadata-file=src/pandoc/metadata.yaml --include-in-header=src/css/style.css --toc --toc-depth=3 --variable toc-title="目次" --split-level=2 --output build/nanika_sheila_ethics.epub
```

HTML生成コマンド

```bash
pandoc src/main.md --from=markdown+hard_line_breaks --wrap=preserve --metadata-file=src/pandoc/metadata.yaml --include-in-header=src/css/style.css --toc --toc-depth=3 --variable toc-title="目次" --standalone --mathjax --output build/nanika_sheila_ethics.html
```

TeX生成コマンド

```bash
pandoc src/main.md --from=markdown+hard_line_breaks --wrap=preserve --metadata-file=src/pandoc/metadata.yaml --toc --toc-depth=2 --variable toc-title="目次" -t latex --output build/nanika_sheila_ethics.tex
```

PDF生成コマンド（TeX経由）

```bash
pandoc src/main.md --from=markdown+hard_line_breaks --wrap=preserve --metadata-file=src/pandoc/metadata.yaml --toc --toc-depth=2 --variable toc-title="目次" --pdf-engine=xelatex --output build/nanika_sheila_ethics.pdf
```

※ xelatex が無い場合は `--pdf-engine=lualatex` や `--pdf-engine=pdflatex` など、環境にある LaTeX エンジンに差し替えてください（`build.bat` は xelatex → lualatex → pdflatex の順で自動検出し、見つからない場合は PDF をスキップします）。
