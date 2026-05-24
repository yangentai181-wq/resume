# 履歴書サイト ブラッシュアップ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 就活向け履歴書サイト（`~/Desktop/自分ウェブ`）に内定お知らせを追加し、画像最適化・OGP/SEO 整備・スマホのチャット入力バグ修正で完成度を上げる。

**Architecture:** バニラ HTML(`index.html`) + CSS(`style.css`) + inline JS + `db.js`。ビルドツールなし。画像は再現可能なシェルスクリプトで一括最適化。`db.js` は動的 `<script>` 注入で遅延読込。Cloudflare Worker は不変。

**Tech Stack:** HTML5 / CSS3 / Vanilla JS / `magick`(ImageMagick, webp delegate あり) / `cwebp` / `sips` / GitHub Pages

**前提環境（確認済み）:** `magick` `cwebp` `sips` `node` `python3` 利用可。`--color-navy: #106494` / gold `#D4A84B`。デプロイ先 `https://yangentai181-wq.github.io/resume/`、remote `resume.git`。

**テスト方針:** 静的サイトのためテストランナーは導入しない。各タスクは「具体的な検証コマンド＋期待出力」または「ブラウザ目視」で検証する。`file://` で動くことを壊さない（`db.js` は fetch でなく `<script>` 注入で読む）。

---

## Task 0: 作業ブランチとローカルサーバ

**Files:** なし（git 操作のみ）

- [ ] **Step 1: 作業ブランチを切る**

```bash
cd ~/Desktop/自分ウェブ
git checkout -b feature/brushup-2026-05
git status
```

Expected: `On branch feature/brushup-2026-05` / clean（spec/plan は別途 add 済みなら表示される）

- [ ] **Step 2: ローカル配信サーバを起動（検証用・別ターミナル）**

```bash
cd ~/Desktop/自分ウェブ && python3 -m http.server 8000
```

Expected: `Serving HTTP on :: port 8000`。ブラウザで `http://localhost:8000/` を開き現状表示を確認。

---

## Task 1: A. 内定のお知らせを追加

**Files:**

- Modify: `index.html`（`.news-ticker` ブロック、現状 119-142 付近）

ニュースは2本の `<ul class="news-ticker">` があり、各 `<ul>` は同じ4項目を**ループ用に2回**並べている。1本目（最新側 = 2026.02.15 を含む方）の**両方の複製ブロックの先頭**に内定項目を追加する。

- [ ] **Step 1: 1本目 ul の最初の項目群の直前に内定行を追加**

1本目 `<ul class="news-ticker">` の最初の `<li>`（`2026.02.15 ... 勉強会を開催しました`）の**直前**に挿入：

```html
<li>
  <span class="news-date">2026.03.25</span
  >株式会社コスモスイニシアより内定をいただきました
</li>
```

- [ ] **Step 2: 同 ul のループ複製側（`<!-- ループ用に複製 -->` 直後の最初の li）の直前にも同じ行を追加**

```html
<li>
  <span class="news-date">2026.03.25</span
  >株式会社コスモスイニシアより内定をいただきました
</li>
```

- [ ] **Step 3: 検証**

```bash
grep -c "内定をいただきました" index.html
```

Expected: `2`

ブラウザ `http://localhost:8000/` を再読込し、お知らせティッカー先頭に内定が流れ、途切れず（複製側も）表示されることを目視確認。

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: お知らせにコスモスイニシア内定(2026.03.25)を追加"
```

---

## Task 2: B-1. 画像最適化スクリプト（高画質 WebP・原本保全）

**Files:**

- Create: `scripts/optimize-images.sh`
- Create: `images_original/`（原本退避先・git 追跡しない）
- Modify: `.gitignore`
- Modify(出力): `images/*.webp`

方針：最大辺 1920px・WebP・品質 90（高画質寄り）。原本は `images_original/` に退避し追跡しない。

- [ ] **Step 1: `.gitignore` に原本退避先を追加**

`.gitignore` 末尾に追記：

```
images_original/
```

- [ ] **Step 2: 最適化スクリプトを作成**

`scripts/optimize-images.sh`:

```bash
#!/usr/bin/env bash
# 画像を最大辺1920px・WebP(q90)へ一括最適化。原本は images_original/ に保全。
set -euo pipefail
cd "$(dirname "$0")/.."

SRC_DIR="images"
ORIG_DIR="images_original"
QUALITY=90
MAXDIM=1920

mkdir -p "$ORIG_DIR"

# 原本を退避（未退避のもののみコピー）
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  [ -e "$ORIG_DIR/$base" ] || cp "$f" "$ORIG_DIR/$base"
done

# 原本から webp を生成（拡張子を .webp に統一）
for f in "$ORIG_DIR"/*; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  name="${base%.*}"
  out="$SRC_DIR/$name.webp"
  magick "$f" -resize "${MAXDIM}x${MAXDIM}>" -quality "$QUALITY" -define webp:method=6 "$out"
  echo "  $base -> $name.webp"
done

# 元の非webpファイルを images/ から削除（参照は webp に切替済み前提）
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  case "$f" in
    *.webp) ;;
    *) rm "$f" ;;
  esac
done

echo "done. images/ size:"; du -sh "$SRC_DIR"
```

```bash
chmod +x scripts/optimize-images.sh
```

- [ ] **Step 3: スクリプト実行**

```bash
./scripts/optimize-images.sh
```

Expected: 各画像の変換ログ＋最後に `images/` 合計サイズが**十数MB以下**。

- [ ] **Step 4: 検証（サイズと枚数）**

```bash
du -sh images && ls images/*.webp | wc -l && du -ch images/*.webp | tail -1
```

Expected: `images` が元の143MBから大幅減（目安 5〜20MB）。webp が原本と同数。

- [ ] **Step 5: 全 webp を目視確認**

```bash
open images
```

Quick Look で主要画像（hero, profile, photo-7-_, photo-B-_）に破綻・過圧縮がないか確認。問題あれば `QUALITY=92` 等に上げて再実行。

- [ ] **Step 6: Commit**

```bash
git add scripts/optimize-images.sh .gitignore images
git commit -m "perf: 画像を最大1920px・WebP(q90)に最適化し原本を退避"
```

---

## Task 3: B-2. HTML の画像参照を webp 化＋ lazy/寸法指定

**Files:**

- Modify: `index.html`（`images/...` を参照する全 `<img>`、23参照）

参照拡張子を `.webp` に統一し、全 `<img>` に `loading` と `width`/`height` を付与（CLS 防止）。hero と最初に見える画像は `loading="eager"`。

- [ ] **Step 1: 画像参照を .webp に一括置換**

`index.html` 内の画像拡張子を webp に統一（`images/xxx.jpg|png` → `images/xxx.webp`）:

```bash
sed -i '' -E 's#(images/[A-Za-z0-9._-]+)\.(jpg|jpeg|png)#\1.webp#g' index.html
grep -oE 'images/[A-Za-z0-9._-]+' index.html | sort -u
```

Expected: 列挙結果がすべて `.webp`（`images/hero.webp` 等）。`og-image` はこの時点では未生成（Task 6 で追加）。

- [ ] **Step 2: 各画像の実寸を出力（width/height 用）**

```bash
for f in $(grep -oE 'images/[A-Za-z0-9._-]+\.webp' index.html | sort -u); do
  printf "%-28s " "$f"; magick identify -format "%w %h\n" "$f" 2>/dev/null || echo "MISSING"
done
```

Expected: 各 webp の `幅 高さ`。`MISSING` が出たら参照名と実ファイル名の不一致を修正。

- [ ] **Step 3: 各 `<img>` に loading と width/height を付与**

Step 2 の実寸を使い、各 `<img ... src="images/NAME.webp">` に属性を追加する。

- hero（`class="hero-img-main"`, `src="images/hero.webp"`）と「現在」タイムラインの hero 流用画像（line 406 付近）→ `loading="eager" fetchpriority="high"`
- それ以外すべて → `loading="lazy"`
- 全 img に `width="<実寸幅>" height="<実寸高>"`

例（hero）:

```html
<img
  src="images/hero.webp"
  alt="岩根大純"
  class="hero-img-main"
  width="1888"
  height="2272"
  loading="eager"
  fetchpriority="high"
/>
```

例（slideshow 内、profile）:

```html
<img
  src="images/profile.webp"
  alt="岩根大純 プロフィール写真"
  width="<実寸>"
  height="<実寸>"
  loading="lazy"
/>
```

※ inline style を持つ img（feature-photo 内の `style="width:100%;height:100%;..."` 等）は `style` を残したまま `loading="lazy"` と `width/height` 属性を追加（属性とCSSは併存可。CSSが優先されレンダリングは不変、属性はCLS予約に効く）。

- [ ] **Step 4: 検証**

```bash
echo "img total:"; grep -oE '<img[^>]*>' index.html | wc -l
echo "with loading:"; grep -oE '<img[^>]*>' index.html | grep -c 'loading='
echo "with width:"; grep -oE '<img[^>]*>' index.html | grep -c 'width='
```

Expected: 3行とも同数（= 全 img に loading と width が付与）。1つだけ eager、残り lazy であることも目視確認：

```bash
grep -oE '<img[^>]*>' index.html | grep -c 'loading="eager"'   # => 2 (hero + 現在)
```

ブラウザ `http://localhost:8000/` を再読込し全セクションの画像が表示されること、DevTools Network で初期表示時に下部セクションの画像が読まれない（lazy）ことを確認。

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "perf: 画像参照をwebp化し loading/寸法指定でCLS低減"
```

---

## Task 4: B-3. db.js の遅延読込

**Files:**

- Modify: `index.html`（line 948 の `<script src="db.js">` 削除、949 以降の inline script を変更）

`db.js`(270KB) を初期ロードから外し、チャット初回操作時に `<script>` 注入で読む（`file://` でも動く方式）。`SYSTEM_PROMPT` の組み立てを DB ロード後に行う。

- [ ] **Step 1: 静的 `<script src="db.js">` を削除**

`index.html` の以下の行を削除：

```html
<script src="db.js"></script>
```

- [ ] **Step 2: 遅延ローダと SYSTEM_PROMPT ビルダを追加**

inline script の先頭（`const GEMINI_API_URL = ...` の直後）に追加。**既存の `const SYSTEM_PROMPT = ` 宣言は削除し**、その中身（テンプレートリテラル）を `buildSystemPrompt()` に移す：

```js
let JIBUN_DB_LOADED = false;
let dbLoadingPromise = null;
function ensureDbLoaded() {
  if (JIBUN_DB_LOADED) return Promise.resolve();
  if (dbLoadingPromise) return dbLoadingPromise;
  dbLoadingPromise = new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = "db.js";
    s.onload = () => {
      JIBUN_DB_LOADED = true;
      resolve();
    };
    s.onerror = () => reject(new Error("db.js の読み込みに失敗しました"));
    document.head.appendChild(s);
  });
  return dbLoadingPromise;
}
function buildSystemPrompt() {
  return `あなたは岩根大純（いわねたいじゅん）のポートフォリオサイトに搭載されたAIアシスタントです。
採用担当者や面接官からの質問に、以下の自己分析データを元に回答してください。

【回答ルール】
- 丁寧な日本語で、簡潔かつ具体的に回答する
- データにない情報は「その情報は持ち合わせていません」と答える
- 岩根大純の強みや経験を前向きに伝える
- 回答は3〜5文程度を目安にする
- データベースに登場する岩根大純以外の個人名（友人・家族・教員・委員会メンバー等）は一切出さない。人物を指す場合は「後輩」「同期」「先生」などの関係性のみで表現する

【岩根大純のデータベース】
${JIBUN_DB}`;
}
```

- [ ] **Step 3: 送信関数で DB ロードを待ち、SYSTEM_PROMPT をビルド時生成に変更**

`sendMessage()` 内、`setLoading(true); showTyping();` の直後に追加：

```js
try {
  await ensureDbLoaded();
} catch (e) {
  hideTyping();
  setLoading(false);
  appendMessage("bot", "データ読み込みエラー。少し待って再度お試しください。");
  return;
}
```

同関数内の `const body = {` を以下に変更（`SYSTEM_PROMPT` → `buildSystemPrompt()`）：

```js
const body = {
  system_instruction: { parts: [{ text: buildSystemPrompt() }] },
  contents: chatHistory,
};
```

`floatSendMessage()` も同様に：`floatSetLoading(true); floatShowTyping();` の直後に

```js
try {
  await ensureDbLoaded();
} catch (e) {
  floatHideTyping();
  floatSetLoading(false);
  floatAppendMessage(
    "bot",
    "データ読み込みエラー。少し待って再度お試しください。",
  );
  return;
}
```

を追加し、`const body = { system_instruction: { parts: [{ text: SYSTEM_PROMPT }] }, ... }` を `buildSystemPrompt()` に変更。

- [ ] **Step 4: 先読み（任意・UX 向上）**

入力欄フォーカス／フロート展開時に先読みを開始（fire-and-forget）。`chatInput` の既存 focus リスナ内、および `toggleFloatChat()` の open 分岐に追加：

```js
ensureDbLoaded().catch(() => {});
```

- [ ] **Step 5: 検証**

```bash
grep -c '<script src="db.js"></script>' index.html   # => 0
grep -c 'buildSystemPrompt' index.html                # => 3 (定義1 + 使用2)
```

ブラウザ `http://localhost:8000/`：

- DevTools Network を開きリロード → 初期ロードに `db.js` が**無い**こと
- チャットに質問送信 → `db.js` がこのタイミングでロードされ、AIが回答すること（Worker 経由）
- 2回目の送信で `db.js` が再ロードされないこと

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "perf: db.js(270KB)をチャット初回操作時の遅延読込に変更"
```

---

## Task 5: D-1 / D-3. head メタ（OGP/SEO）＋ favicon

**Files:**

- Modify: `index.html`（`<head>` 内、現状 3-8）
- Create: `favicon.svg`
- Create: `apple-touch-icon.png`（favicon.svg から生成）

OG 画像は Task 6 で生成するが、参照（`images/og-image.jpg`）はここで先に書いておく。

- [ ] **Step 1: favicon.svg を作成（「岩」マーク・navy 背景）**

`favicon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#106494"/>
  <text x="32" y="46" font-family="'Hiragino Mincho ProN','Yu Mincho',serif" font-size="42" font-weight="700" fill="#ffffff" text-anchor="middle">岩</text>
</svg>
```

- [ ] **Step 2: apple-touch-icon.png（180×180）を生成**

```bash
cd ~/Desktop/自分ウェブ
magick -background "#106494" favicon.svg -resize 180x180 apple-touch-icon.png
magick identify -format "%wx%h\n" apple-touch-icon.png
```

Expected: `180x180`

- [ ] **Step 3: `<head>` を差し替え**

現状：

```html
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>岩根大純 | パッションモンスター</title>
  <link rel="stylesheet" href="style.css" />
</head>
```

↓ 差し替え：

```html
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>岩根大純 | パッションモンスター</title>
  <meta
    name="description"
    content="京都工芸繊維大学でデザイン・建築・AIを学ぶ岩根大純のポートフォリオ。「理不尽を、情熱と仕組みでハックする」をテーマに、実績・搭載機能・他者評価・AIチャットを掲載しています。"
  />

  <link rel="canonical" href="https://yangentai181-wq.github.io/resume/" />

  <!-- OGP -->
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://yangentai181-wq.github.io/resume/" />
  <meta property="og:title" content="岩根大純 | パッションモンスター" />
  <meta
    property="og:description"
    content="理不尽を、情熱と仕組みでハックする。京都工芸繊維大学・デザイン×建築×AI。実績・他者評価・AIチャットを掲載したポートフォリオ。"
  />
  <meta
    property="og:image"
    content="https://yangentai181-wq.github.io/resume/images/og-image.jpg"
  />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:locale" content="ja_JP" />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="岩根大純 | パッションモンスター" />
  <meta
    name="twitter:description"
    content="理不尽を、情熱と仕組みでハックする。デザイン×建築×AI のポートフォリオ。"
  />
  <meta
    name="twitter:image"
    content="https://yangentai181-wq.github.io/resume/images/og-image.jpg"
  />

  <!-- favicon -->
  <link rel="icon" type="image/svg+xml" href="favicon.svg" />
  <link rel="apple-touch-icon" href="apple-touch-icon.png" />

  <link rel="stylesheet" href="style.css" />
</head>
```

- [ ] **Step 4: 検証**

```bash
grep -c 'og:image' index.html        # => 3 (image, width, height)
grep -c 'twitter:card' index.html    # => 1
grep -c 'rel="icon"' index.html      # => 1
ls -la favicon.svg apple-touch-icon.png
```

ブラウザでタブに favicon（「岩」）が出ることを確認。

- [ ] **Step 5: Commit**

```bash
git add index.html favicon.svg apple-touch-icon.png
git commit -m "feat: OGP/Twitterカード/description/canonical と favicon を追加"
```

---

## Task 6: D-2. OG 画像（hero を 1200×630 にトリミング）

**Files:**

- Create: `images/og-image.jpg`

- [ ] **Step 1: hero 原本から 1200×630 を中央上寄りで切り出し**

```bash
cd ~/Desktop/自分ウェブ
SRC=images_original/hero.png
[ -f "$SRC" ] || SRC=images_original/hero.jpg
magick "$SRC" -resize 1200x630^ -gravity north -extent 1200x630 -quality 88 images/og-image.jpg
magick identify -format "%wx%h %b\n" images/og-image.jpg
```

Expected: `1200x630` かつ数百KB程度。

- [ ] **Step 2: 目視確認**

```bash
open images/og-image.jpg
```

顔が切れていないか確認。切れる場合は `-gravity north` を `-gravity center` 等に調整して再生成。

- [ ] **Step 3: Commit**

```bash
git add images/og-image.jpg
git commit -m "feat: OGP用画像(1200x630, hero流用)を追加"
```

---

## Task 7: C-1. スマホでチャット入力欄が隠れるバグの修正（再現駆動）

**Files:**

- Modify: `index.html`（inline script の入力 focus 処理）/ 必要に応じ `style.css`

> **REQUIRED SUB-SKILL:** superpowers:systematic-debugging を用いる。**先に再現してから**最小修正する。

症状（ユーザー報告）: スマホでチャットに入力する際、**入力欄が隠れて見えない**。対象はページ内 `#chatInput` とフロート `#floatChatInput` のいずれか/両方。

- [ ] **Step 1: 再現（まず観察）**

実機 iPhone が最も確実。ローカルを同一 LAN で開くか、後述の preview 反映後に確認：

```bash
# Mac の LAN IP を表示（iPhone の Safari から http://<IP>:8000/ を開く）
ipconfig getifaddr en0
```

iPhone で各チャット（ページ内「大純AIに聞く」セクション／右下フローティング）の入力欄をタップ → キーボード表示時に入力欄が隠れる状況を再現し、**どちらで・どう隠れるか**を記録。
（補助）Safari「レスポンシブデザインモード」でも確認可だが、ソフトキーボード/visualViewport は実機が確実。

- [ ] **Step 2: 原因仮説の確認**

関係箇所：

- `.header { position: sticky; top:0; z-index:1000 }`（`style.css:41-46`）
- ページ内入力 focus 時：`chatInput.addEventListener('focus', ...)` 内 `chatInput.scrollIntoView({ behavior:'smooth', block:'nearest' })`（`index.html` 末尾付近）
- フロートは `adjustFloatPanelForKeyboard()`（visualViewport 対応済み）

`block:'nearest'` だとキーボード表示でビューポートが縮んだ際、入力欄がキーボード or sticky ヘッダーに隠れることがある。

- [ ] **Step 3: 修正（ページ内 #chatInput）**

`chatInput` の focus リスナを以下に変更（`block:'center'` ＋ visualViewport 高さ考慮で確実に可視化）：

```js
chatInput.addEventListener("focus", function () {
  if (window.innerWidth <= 768) {
    setTimeout(function () {
      chatInput.scrollIntoView({ behavior: "smooth", block: "center" });
    }, 350);
  }
});
```

- [ ] **Step 4: 修正（フロート側が原因だった場合のみ）**

再現がフロートで起きる場合、`adjustFloatPanelForKeyboard()` が `floatChatInput` を可視域に収めるよう、関数末尾に追加：

```js
setTimeout(function () {
  document.getElementById("floatChatInput").scrollIntoView({ block: "center" });
}, 50);
```

- [ ] **Step 5: 検証（実機）**

iPhone で再度 `http://<IP>:8000/`（または preview）を開き、ページ内・フロート両方で入力欄をタップ → **入力欄が常に可視・操作可能**であることを確認。直らなければ Step 1 に戻り観察し直す（推測で重ねない）。

- [ ] **Step 6: Commit**

```bash
git add index.html style.css
git commit -m "fix: スマホでチャット入力欄がキーボードに隠れる問題を修正"
```

---

## Task 8（任意）: C-2. AI 回答の Markdown 整形

**Files:**

- Modify: `index.html`（`appendMessage` / `floatAppendMessage` の bot 描画）

Gemini 応答中の `**太字**`・箇条書き・改行を安全に HTML 化（必ずエスケープ後に限定タグのみ）。

- [ ] **Step 1: renderMarkdown を追加**

inline script に追加：

```js
function renderMarkdown(text) {
  const esc = (s) =>
    s.replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const lines = esc(text).split("\n");
  let html = "",
    inList = false;
  for (let raw of lines) {
    const line = raw.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    const m = line.match(/^\s*[-・*]\s+(.*)$/);
    if (m) {
      if (!inList) {
        html += "<ul>";
        inList = true;
      }
      html += "<li>" + m[1] + "</li>";
    } else {
      if (inList) {
        html += "</ul>";
        inList = false;
      }
      if (line.trim() === "") html += "<br>";
      else html += "<p>" + line + "</p>";
    }
  }
  if (inList) html += "</ul>";
  return html;
}
```

- [ ] **Step 2: bot メッセージのみ innerHTML 描画に変更**

`appendMessage(role, text)` の `bubble.textContent = text;` を：

```js
if (role === "bot") {
  bubble.innerHTML = renderMarkdown(text);
} else {
  bubble.textContent = text;
}
```

`floatAppendMessage` も同様に変更（user は textContent 維持）。

- [ ] **Step 3: 検証**

ローカルで「箇条書きで教えて」等と質問し、太字・リスト・改行が整形表示されること。`<script>` を含む入力をしても**実行されない**こと（エスケープ確認）。

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: AIチャット回答のMarkdown(太字/箇条書き)整形(XSS対策込み)"
```

---

## Task 9（任意）: C-3. 会話リセットボタン

**Files:**

- Modify: `index.html`（chatbot-header 785-793 ＋ リセット関数）

- [ ] **Step 1: ヘッダーにリセットボタンを追加**

`.chatbot-header` の最後（`</div>` 直前、subtitle の div の後ろ）に追加：

```html
<button
  class="chat-reset-btn"
  onclick="resetChat()"
  title="会話をリセット"
  style="margin-left:auto;background:none;border:1px solid var(--color-border);border-radius:8px;padding:6px 10px;font-size:12px;cursor:pointer;color:var(--color-gray);"
>
  リセット
</button>
```

- [ ] **Step 2: resetChat 関数を追加**

```js
function resetChat() {
  chatHistory.length = 0;
  document.getElementById("chatHistory").innerHTML =
    '<div class="chat-message bot"><div class="chat-avatar"><img src="images/hero.webp" alt="AI"></div>' +
    '<div class="chat-bubble">ここまでご覧いただきありがとうございました。岩根の考え方、経験、他者からの評価を集めたデータベースをもとにAIが回答します。</div></div>';
}
```

- [ ] **Step 3: 検証**

ローカルで数往復した後リセット → 履歴が初期メッセージのみに戻り、続けて質問でき文脈が新規になること。

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: AIチャットに会話リセットボタンを追加"
```

---

## Task 10: 総合検証・回帰確認・デプロイ

**Files:** なし（検証＋ push）

- [ ] **Step 1: 回帰チェック（ローカル `http://localhost:8000/`）**

以下が壊れていないことを目視確認：

- PDF出力ボタン（`window.print()`）でレイアウトが崩れない（print CSS）
- スライドショー自動送り、各「もっと見る」「続きを読む」トグル
- ハンバーガーメニュー開閉
- テキスト選択 →「大純AIに聞く」引用ツールチップ
- AIチャット（ページ内・フロート）が応答する
- 全画像表示・お知らせティッカー

- [ ] **Step 2: サイズ最終確認**

```bash
du -sh images && du -ch index.html style.css db.js images/*.webp favicon.svg 2>/dev/null | tail -1
```

Expected: 配信総量が元（143MB+）から大幅減。

- [ ] **Step 3: ブランチを main に統合**

> REQUIRED SUB-SKILL: superpowers:finishing-a-development-branch に従い統合方法を決める（merge / PR）。

```bash
git checkout main
git merge --no-ff feature/brushup-2026-05
```

- [ ] **Step 4: push（※ユーザー確認のうえ実行）**

```bash
git push origin main
```

push 後、GitHub Pages 反映（数分）を待ち、`https://yangentai181-wq.github.io/resume/` で表示・スマホのチャット入力・OGP（共有プレビュー）を確認。
OGP は反映確認に Facebook Sharing Debugger / X Card Validator でキャッシュ更新可。

---

## Self-Review メモ（プラン作成者による確認）

- spec の A/B/C/D・非ゴール（Worker不変・志望理由維持）をすべてタスク化済み（A=T1, B=T2-4, C=T7+任意T8/9, D=T5-6）。
- OG 画像形式は JPG（webp 不使用）で spec と一致。
- `db.js` は fetch でなく `<script>` 注入のため `file://`/Pages 双方で動作。
- 関数名一貫：`ensureDbLoaded` / `buildSystemPrompt` / `renderMarkdown` / `resetChat` を定義箇所と使用箇所で一致。
- 画像 width/height の具体値は実寸依存のため、Task3-Step2 で実測して埋める手順を明示（プレースホルダではなく導出手順）。
- モバイルバグは再現駆動（systematic-debugging）。実機検証が必要な点はリスクとして明記。
