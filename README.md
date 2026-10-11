# tokyu-vote-app

TokyuRuby会議の投票アプリ。参加者が持ち寄った料理（飯王）・酒（酒王）と LT（LT王）に投票し、管理者が集計して結果を公開する。

## 動かすのに必要なもの

- Ruby（バージョンは `.ruby-version`）
- SQLite 3
- libvips（画像のアップロードに使う。macOS は `brew install vips`）

## セットアップ

```bash
bin/setup --skip-server   # gem のインストールと DB の準備
bin/rails demo:setup      # 動作確認用のイベントとユーザーを作る（結果発表まで見るなら demo:results）
bin/dev                   # 開発サーバー。http://localhost:3000/login でユーザーを選んでログインする
```

GitHub ログインを手元で試す場合は `.env` に `GITHUB_CLIENT_ID` と `GITHUB_CLIENT_SECRET` を置く（`.env*` は gitignore 済み）。設定しなくても `/login` の開発用ユーザー切り替えで動く。

## テストと静的解析

```bash
bin/rspec                 # テスト
bin/rubocop               # Ruby のスタイル
bin/erb_lint --lint-all   # ERB のスタイル
bin/brakeman --no-pager   # 脆弱性の静的解析
bin/ci                    # 上記をまとめて実行（CI と同じ内容）
```

## デプロイ

GitHub Actions から staging / production に Kamal でデプロイする。手順と管理者付与は [docs/deploy.md](docs/deploy.md)。
