# デプロイと管理者付与（GitHub Actions）

デプロイと管理者付与は GitHub の Actions タブから行う。手元に Docker や秘密情報を持たなくてよい。
手元から `bin/kamal` で行う場合の手順は本ファイル末尾。

## 構成

| 環境 | URL | Kamal の destination | 備考 |
|---|---|---|---|
| staging | https://vote-staging.gohansummit.com | `staging` | Basic 認証と noindex 付き |
| production | https://vote.gohansummit.com | `production` | 実行に承認が必要 |

両環境は同じ VPS に同居し、`config/deploy.<環境>.yml` で service 名とボリューム名を分けている。

## デプロイする

1. Actions タブ → **Deploy** → **Run workflow**
2. **Use workflow from** でデプロイしたいブランチを選ぶ（通常は `main`）
3. **デプロイ先** で `staging` か `production` を選んで Run
4. production は Environment の Required reviewers に承認を求める通知が飛ぶ。承認されると続きが動く
5. 完了後に `https://<環境の URL>/up` が 200 を返すことを確認する

ワークフロー（`.github/workflows/deploy.yml`）がやること: Ruby と Kamal を用意 → SSH 鍵と秘密情報を Secrets から書き出す → `bin/kamal deploy -d <環境>`。
イメージはランナー上でビルドして ghcr.io に push し、サーバーが pull して入れ替える。所要時間は 5 分程度。

## 管理者にする

対象の人に、**先にその環境へ GitHub でログインしてもらう**（ログインで `User` が作られる）。

1. Actions タブ → **Grant admin** → **Run workflow**
2. **対象の環境** と **GitHub ユーザー名** を入力して Run
3. ログに「○○ を管理者にしました」と出れば完了。対象の人はログインし直さなくてよい

ワークフロー（`.github/workflows/grant_admin.yml`）は稼働中のコンテナで `bin/rails "admin:grant[ユーザー名]"`（`lib/tasks/admin.rake`）を実行する。
「まだログインしていません」と出たら手順の前提を確認する。「複数います」と出たら、改名した人に再ログインしてもらってから再実行する。

## 初期設定（リポジトリ管理者が一度だけ行う）

### Secrets

Settings → Secrets and variables → Actions で登録する。**Secrets 名は `GITHUB_` で始められない**ため、OAuth の値は `OAUTH_GITHUB_*` という名前にし、`.github/scripts/write_kamal_secrets` が Kamal の期待する名前に書き換える。

| 名前 | 置き場所 | 値 |
|---|---|---|
| `RAILS_MASTER_KEY` | Repository secrets | `config/master.key` の中身 |
| `SSH_PRIVATE_KEY` | Repository secrets | Actions 専用の SSH 秘密鍵（下記） |
| `OAUTH_GITHUB_CLIENT_ID` | Environment `staging` | staging 用 GitHub OAuth App の Client ID |
| `OAUTH_GITHUB_CLIENT_SECRET` | Environment `staging` | 同 Client Secret |
| `STAGING_BASIC_AUTH_PASSWORD` | Environment `staging` | Basic 認証のパスワード |
| `OAUTH_GITHUB_CLIENT_ID` | Environment `production` | production 用 GitHub OAuth App の Client ID |
| `OAUTH_GITHUB_CLIENT_SECRET` | Environment `production` | 同 Client Secret |

ghcr.io への push は Actions の `GITHUB_TOKEN` を使うので登録不要。値に `'` は使えない（dotenv の単引用符で囲むため）。

`gh` で登録する例（値を画面に出さずに済む）:

```bash
gh secret set RAILS_MASTER_KEY < config/master.key
```

```bash
gh secret set OAUTH_GITHUB_CLIENT_ID --env staging
```

### Actions 用の SSH 鍵

Actions はパスフレーズを入力できないので、専用の鍵を作ってサーバーの root に登録する。

```bash
ssh-keygen -t ed25519 -N "" -C "github-actions tokyu-vote-app" -f ~/.ssh/tokyu-vote-app-deploy
```

```bash
ssh root@<サーバーの IP> 'cat >> ~/.ssh/authorized_keys' < ~/.ssh/tokyu-vote-app-deploy.pub
```

```bash
gh secret set SSH_PRIVATE_KEY < ~/.ssh/tokyu-vote-app-deploy
```

登録後、手元の秘密鍵は消してよい。サーバーの IP は `config/deploy.<環境>.yml` の `servers.web`。

### Environments

Settings → Environments に `staging` と `production` を作る。`production` には **Required reviewers**（承認者）を設定し、Deployment branches を `main` に限定する。

### ghcr.io のイメージ

`GITHUB_TOKEN` でイメージを push できるのは、イメージ（Package）がこのリポジトリに紐づいているときだけ。
Actions から最初に push すれば自動で紐づく。手元の PAT で先に push していた場合は、Package settings → **Manage Actions access** でこのリポジトリを Write で追加する。

### 初回だけ手元から行うこと

サーバーの初期化（Docker と kamal-proxy のインストール、証明書の取得）は `bin/kamal setup -d <環境>` を手元から一度行う。2 回目以降は Actions でよい。

## ログの見方

- 「デプロイする」に大量に出る `DEBUG` 行は、Kamal が流す Docker のビルドログ（apt-get や bundle install の進捗）。手元で `bin/kamal deploy` したときと同じもので、異常ではない
- 各ステップ冒頭の `env:` に Secrets の名前が並ぶのは GitHub Actions の仕様。値は `***` に置き換えられる
- ログは実行ページ右上の「...」→ Delete all logs で消せる。放置しても 90 日で自動的に消える

## よくある失敗

| 症状 | 原因 | 対処 |
|---|---|---|
| `Permission denied (publickey)` | 公開鍵が `authorized_keys` に無い、または `SSH_PRIVATE_KEY` が壊れている | 鍵を作り直す。秘密鍵は改行を含めて丸ごと登録する |
| ghcr.io に `denied` | Package がリポジトリに紐づいていない | 上記「ghcr.io のイメージ」 |
| `GITHUB_CLIENT_ID` が空でログインボタンが出ない | Environment secrets の登録漏れ | `OAUTH_GITHUB_*` を該当 Environment に登録 |
| `ActiveSupport::MessageEncryptor::InvalidMessage` | `RAILS_MASTER_KEY` が違う | 手元の `config/master.key` と一致させる |
| 管理者付与で「まだログインしていません」 | 対象の人が未ログイン | その環境に一度ログインしてもらう |

## 手元から行う場合

秘密情報を `.kamal/secrets.<環境>`（gitignore 済み）に置き、Docker Desktop を起動した状態で:

```bash
bin/kamal deploy -d staging
```

```bash
bin/kamal app exec -d staging --reuse 'bin/rails "admin:grant[ユーザー名]"'
```
