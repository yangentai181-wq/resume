# デザインに動きを追加（スクロールモーション）設計

- 日付: 2026-05-25
- 対象: `~/Desktop/自分ウェブ`（`index.html` + `style.css`）
- トーン: **控えめ・上品**（ユーザー選択）。「過剰なアニメを避ける」原則に準拠。

## ゴール

ページを見ていく中での「動き」を足し、生きて見せる。ただし上品・控えめに。

## 非ゴール

- ライブラリ追加（AOS/GSAP等）はしない（軽量化方針と整合・バニラ維持）
- 既存の動き（ティッカー／スライドショー／タイピング／ホバー）は変更しない
- パララックス・派手なホバー・連続演出はしない

## 方式（採用：A）

- **バニラ `IntersectionObserver` 1つ＋CSS**。要素が画面に入ったら `.is-visible` を付与→CSSトランジション。
- **FOUC回避**: `<head>` 末尾の同期 inline script で `document.documentElement.classList.add('js-motion')` を付与。初期非表示CSSは `html.js-motion` 下でのみ適用＝最初の描画前に非表示が効く。JS無効環境は常時表示（プログレッシブエンハンスメント）。
- **アクセシビリティ**: 初期非表示CSSはすべて `@media (prefers-reduced-motion: no-preference)` 内に置く。`reduce` 指定ユーザーは非表示にならず常時表示。JS側も `reduce` 検出時は全要素を即 `is-visible`。

## 動き（4種・すべて `.is-visible` で発火）

1. **スクロールリビール**: 対象ブロックが画面に入るとフェードイン＋16px下→上（opacity/transform、約0.5s ease-out、1回のみ）。同一親内の対象は index×60ms（最大6段）で軽くスタッガー。
   - 対象セレクタ: `.section-title, .hero-title, .hero-subtitle, .credentials-inline, .spec-block, .timeline-item, .feature-card, .engine-item, .review-block, .ultimate-goal, .skill-progress-item, .requirement-card, .step-item`
2. **進捗バー（Next Good）**: `.progress-current` を `transform: scaleX(0)→1`（transform-origin:left、約0.8s ease-out）。幅%はインラインのまま＝バー長を規定、scaleXで充填演出。
3. **★評価**: `.rating-stars` が入ると子 `.star` が左から順にフェード＋スケールで満ちる（nth-child で遅延）。
4. **ヒーロー登場**: 上記1のうち hero 系（`.hero-title/.hero-subtitle/.credentials-inline`）が初回ロード時の IO 発火で登場＝専用コード不要。

## 実装ファイル

- `style.css`: 末尾に `@media (prefers-reduced-motion: no-preference){ html.js-motion ... }` ブロックを追加（初期非表示＋`.is-visible`復帰、バー scaleX、star stagger）。`:is()` でセレクタをまとめる。
- `index.html`:
  - `<head>` 末尾に同期 inline script（js-motion付与）。
  - `</body>` 前の inline script 群の末尾に IO 初期化スクリプト（対象収集→reduce/IO非対応なら全is-visible→observe→交差でis-visible付与しunobserve→staggerはブロック対象のみ）。

## テスト/検証

- `node --check` で inline JS 構文OK、`HTMLParser` でHTML健全。
- ローカルブラウザ目視: スクロールで各セクションが一度だけふわっと出現、進捗バーが伸び、★が満ちる。再読込で再発火。
- DevTools で `prefers-reduced-motion: reduce` をエミュレート→全要素が即表示・動かないこと。
- 既存（ティッカー/スライドショー/チャット/PDF印刷/ハンバーガー/もっと見る）が無傷。
- 旧ブラウザ（IObserver無し）フォールバックで全表示。

## デプロイ

`resume.git` にコミット→（ユーザー確認後）push、GitHub Pages 反映。
