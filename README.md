# ナニカシイラの倫理

ナニカシイラの倫理

EPUB生成コマンド

```bash
pandoc src/main.md \
  --metadata-file=pandoc/metadata.yaml \
  --css=style.css \
  --toc \
  --toc-depth=2 \
  --epub-chapter-level=1 \
  --output build/nanika_sheila_ethics.epub
```