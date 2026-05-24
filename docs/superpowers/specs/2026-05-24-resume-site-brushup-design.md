# 履歴書サイト ブラッシュアップ 設計（自分ウェブ / resume）

- 日付: 2026-05-24
- 対象: `~/Desktop/自分ウェブ`（GitHub Pages: https://yangentai181-wq.github.io/resume/ ・remote `resume.git`）
- 構成: バニラ HTML(`index.html`) + CSS(`style.css`) + JS(inline) + `db.js` + 別管理の Cloudflare Worker(`worker.js`、本リポ外)

## 背景・現状

「ソフトウェア製品」メタファーの就活向け履歴書サイト。コンセプトは「パッションモンスター／理不尽を、情熱と仕組みでハックする」。
セクション構成: Hero → お知らせ(ticker) → 基本仕様 → これまでのアップデート(timeline) → 搭載機能+エンジン → 評価とレビュー → Next Good → 大純AIに聞く(Gemini chat) + フローティングチャット。

現状の課題（調査で判明）:

1. **画像が合計143MB**（個別最大27MBのPNG複数）をそのまま GitHub Pages から配信。`loading="lazy"`・寸法指定ゼロ → 表示が極端に重い（最大のボトルネック）。
2. **OGP/メタディスクリプション/favicon が未設定** → URL共有・検索時の見え方が素のまま。
3. **スマホでチャット入力すると入力欄が隠れる**（キーボード表示時のレイアウト崩れ）。
4. AIチャットの回答は `textContent` 表示で **Markdown非整形**。
5. お知らせが 2026.02.15 で停止。**コスモスイニシア内定**（2026.03）が未反映。

## ゴール / 非ゴール

**ゴール**

- A. 内定のお知らせを追加
- B. 画像最適化で初期表示を劇的に軽量化（高画質を保ちつつ）
- C. スマホのチャット入力バグを修正（＋任意でMarkdown整形・会話リセット）
- D. OGP/SEO/favicon を整備し共有・検索時の見え方を改善

**非ゴール（今回やらない）**

- Cloudflare Worker の改修・再デプロイ（真のSSEストリーミングは対象外）
- 「なぜコスモスイニシア」セクションの文言変更（**現状維持**）
- 新セクション追加（ギャラリー等）
- フレームワーク化・ビルドツール導入（バニラ構成を維持）

## 確定した方針（ヒアリング結果）

| 論点       | 決定                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------ |
| 画像最適化 | リサイズ＋WebP、**高画質寄り（圧縮控えめ q90前後）**、**原本は `images_original/` に保全** |
| チャット   | **モバイル入力バグ修正が最優先**（再現→修正）。ストリーミング/Worker改修は対象外           |
| OGP画像    | **hero写真を 1200×630 にトリミング**して流用                                               |
| 志望理由   | 現状維持                                                                                   |

## 詳細設計

### A. 内定のお知らせ追加

- `index.html` の `.news-ticker`（1本目=最新側）先頭に追加:
  - `<li><span class="news-date">2026.03.25</span>株式会社コスモスイニシアより内定をいただきました</li>`
- ticker はループ用に各 `<ul>` 内で項目を複製しているため、**複製ブロックにも同じ項目を追加**して途切れないようにする。
- 既存トーン（「〜しました／〜いただきました」）に合わせる。

### B. 画像パフォーマンス

**B-1. 最適化スクリプト（再現可能）**

- `scripts/optimize-images.sh` を新設。処理:
  1. 既存 `images/` の原本を `images_original/` へ退避（未退避なら）。
  2. 各画像を最大辺 ~1920px にリサイズ＋WebP化（品質 ~90）。透過PNGはアルファ保持。
  3. 出力は `images/<name>.webp`。
- ツールは環境にあるものを使用（優先: `cwebp`／`magick`(ImageMagick)／`sips`）。実装時に `which` で存在確認し、無ければ導入手順を提示。
- **検証**: 出力後に `images/` 合計サイズと各ファイルサイズを計測し、143MB→十数MB を確認。各画像を目視で破綻がないか確認。

**B-2. HTML 側の参照更新と遅延読込**

- 参照を `.webp` に更新（23参照）。slideshow/timeline/feature/profile/avatar 等すべて。
- 全 `<img>` に `loading="lazy"` と `width`/`height`（実寸アスペクト比）を付与。**hero と最初に見える画像のみ `loading="eager"` / `fetchpriority="high"`**。
- WebP 非対応の極端な旧環境は考慮外（GitHub Pages の想定閲覧者は現行ブラウザ）。

**B-3. db.js の遅延読込**

- `<script src="db.js">` を削除し、**チャット初回操作時（入力フォーカス or 送信 or フロート展開）に動的 `import`/`fetch`** で読み込む。
- 読込状態フラグを持ち、二重読込を防止。読込完了まで送信ボタンは待機。
- `SYSTEM_PROMPT` は `JIBUN_DB` ロード後に組み立てる（現在トップレベルで参照しているため、関数内生成に変更）。

### C. AIチャット

**C-1. モバイル入力バグ修正（最優先・再現駆動）**

- 仮説: `header { position: sticky }`（`style.css:44`）＋ 入力フォーカス時 `scrollIntoView({block:'nearest'})` ＋ iOS Safari のキーボード/visualViewport 挙動の相互作用で、入力欄がヘッダー/キーボードに隠れる。
- 進め方（systematic-debugging）: まず**スマホ実機相当で再現**（実機 or レスポンシブ＋visualViewport）し、ページ内 `#chatInput` とフロート `#floatChatInput` のどちらで崩れるか・崩れ方を特定してから最小修正。
- 想定修正の方向性（再現後に確定）:
  - `scrollIntoView` を `block:'center'` に変更、またはキーボード高さ（`visualViewport`）を考慮したオフセットスクロール。
  - 入力欄の固定/配置を visualViewport 基準に補正（既存 `adjustFloatPanelForKeyboard` と整合）。
- **検証**: 修正後、実機相当でキーボード表示時に入力欄が常に可視・操作可能であることを確認（ページ内・フロート両方）。

**C-2. Markdown整形（任意）**

- bot 応答を `textContent` から**安全なMarkdown→HTML**へ。最小実装: `**bold**`・`- 箇条書き`・改行のみ対応の軽量変換を自前実装し、**必ず HTML エスケープしてから**限定タグのみ付与（XSS対策）。外部ライブラリは追加しない方針（バニラ維持）。
- ユーザー発言は従来どおり `textContent`。

**C-3. 会話リセット（任意）**

- チャットヘッダーに「リセット」ボタン。`chatHistory`/`floatHistory` を空にし、履歴DOMを初期メッセージのみへ戻す。

### D. 共有・発見性（OGP/SEO）

**D-1. `<head>` メタ**

- `<meta name="description">`（サイト要約・100字程度）
- OGP: `og:title` / `og:description` / `og:type=website` / `og:url`(canonical) / `og:image`(1200×630) / `og:image:width/height` / `og:locale=ja_JP`
- Twitter: `twitter:card=summary_large_image` / `twitter:title` / `twitter:description` / `twitter:image`
- `<link rel="canonical" href="https://yangentai181-wq.github.io/resume/">`

**D-2. OG画像**

- `images_original/` の hero 元画像（`hero.png`/`hero.jpg`）から **1200×630 にトリミング**して `images/og-image.jpg` を生成。文字なし（hero流用）。
- **形式は JPG または PNG**（WebP は LINE 等一部の OGP クローラで表示されないため OG 画像には使わない）。`scripts/optimize-images.sh` 内 or 個別コマンドで生成。

**D-3. favicon**

- 「岩」マーク（サイトのロゴ調）を SVG favicon として作成（`favicon.svg`）＋ フォールバック用 `favicon.ico`/PNG、`apple-touch-icon`(180×180)。
- `<head>` に `<link rel="icon">` 群を追加。

**D-4. JSON-LD（任意）**

- `Person` schema（名前・所属・URL・職種志望）を `<script type="application/ld+json">` で付与。

## デプロイ / 反映

- 変更は `resume.git` に commit → push、GitHub Pages に反映。
- 大容量原本（`images_original/`）を push に含めるとリポが肥大化するため、**`.gitignore` に `images_original/` を追加**し原本はローカル保全のみ。
- **注意**: 今回の最適化は GitHub Pages が**配信するファイル**を軽量化し**表示速度を改善**する。ただし重い旧画像は既に git 履歴に存在するため、`.git` リポジトリ自体のサイズは縮まない（履歴の縮小＝`git filter-repo` 等は別作業・今回スコープ外）。
- Worker は変更しない。

## テスト / 検証

- **画像**: 最適化後の合計/個別サイズ計測、全画像の目視確認、ローカルで `index.html` を開き全セクションの画像が表示されること。
- **遅延読込**: 初期ロードで `db.js`/原寸画像が読まれないこと（DevTools Network）、チャット初回操作で `db.js` がロードされ応答が返ること。
- **モバイルバグ**: 実機相当でキーボード表示時の入力欄可視性（ページ内・フロート）。
- **OGP**: メタの構文確認、OG画像の存在・寸法、（可能なら）共有プレビュー確認。
- **回帰**: PDF出力（`window.print()`）、スライドショー、もっと見る/続きを読む、ハンバーガー、テキスト選択引用が壊れていないこと。

## リスク / 留意

- iOS Safari のキーボード挙動はエミュレーションで完全再現できない場合がある → 修正後は実機確認を推奨（ユーザー協力）。
- WebP変換ツールが未導入の可能性 → 実装時に存在確認・導入手順提示。
- 個人情報（電話/住所/メール）が公開配信されている点は**今回スコープ外**だが、別途要検討事項として記録。

## 作業順序（概略）

1. A 内定お知らせ（即・低リスク）
2. D-3 favicon / D-1 メタ（低リスク）
3. B 画像最適化（スクリプト→参照更新→遅延読込）※最大効果
4. D-2 OG画像生成
5. C-1 モバイルバグ修正（再現駆動）→ C-2/C-3 任意
6. 検証 → commit/push
