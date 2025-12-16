# ナニカシイラの倫理

ナニカシイラの倫理

EPUB生成コマンド

```bash
pandoc src/main.md --metadata-file=pandoc/metadata.yaml --css=style.css --toc --toc-depth=2 --variable toc-title="目次" --epub-chapter-level=1 --output build/nanika_sheila_ethics.epub
```

HTML生成コマンド

```bash
pandoc src/main.md --metadata-file=pandoc/metadata.yaml --include-in-header=pandoc/style.css --toc --toc-depth=2 --variable toc-title="目次" --standalone --mathjax --output build/nanika_sheila_ethics.html
```

TeX生成コマンド

```bash
pandoc src/main.md --metadata-file=pandoc/metadata.yaml --toc --toc-depth=2 --variable toc-title="目次" -t latex --output build/nanika_sheila_ethics.tex
```

PDF生成コマンド（TeX経由）

```bash
pandoc src/main.md --metadata-file=pandoc/metadata.yaml --toc --toc-depth=2 --variable toc-title="目次" --pdf-engine=xelatex --output build/nanika_sheila_ethics.pdf
```