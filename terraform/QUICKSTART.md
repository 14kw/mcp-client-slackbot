# クイックスタートガイド

このガイドは、MCP SlackbotをGoogle Cloudに最速でデプロイするための手順です。

## 準備（5分）

1. **Google Cloudプロジェクトの作成**
   - https://console.cloud.google.com/ にアクセス
   - 新しいプロジェクトを作成
   - プロジェクトIDをメモ

2. **gcloud CLIのインストール**（未インストールの場合）
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Linux
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   
   # Windows
   # https://cloud.google.com/sdk/docs/install からインストーラーをダウンロード
   ```

3. **認証**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

## デプロイ（10分）

### ステップ1: イメージのビルドとプッシュ

```bash
# プロジェクトIDを設定
export PROJECT_ID="your-project-id"

# イメージをビルドしてプッシュ
./build-and-push.sh
```

### ステップ2: Terraformの設定

```bash
cd terraform

# terraform.tfvarsファイルを作成
cp terraform.tfvars.example terraform.tfvars

# エディタで編集（必須項目のみ）
vim terraform.tfvars
```

**最小限の設定例：**
```hcl
project_id      = "your-project-id"
container_image = "asia-northeast1-docker.pkg.dev/your-project-id/mcp-slackbot-repo/mcp-slackbot:latest"
slack_bot_token = "xoxb-..."
slack_app_token = "xapp-..."
openai_api_key  = "sk-..."
```

### ステップ3: デプロイ実行

```bash
# Terraformを初期化
terraform init

# デプロイ（確認後yesを入力）
terraform apply
```

デプロイが完了したら、サービスURLが表示されます。

### ステップ4: 動作確認

```bash
# ログを確認
gcloud run services logs tail mcp-slackbot --region=asia-northeast1

# Slackで@MCP Assistantにメッセージを送信して動作確認
```

## トラブルシューティング

### イメージのプッシュに失敗する

```bash
# 認証を再設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### Terraformの実行に失敗する

```bash
# APIを手動で有効化
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# 再度実行
terraform apply
```

### ボットが応答しない

```bash
# ログを確認
gcloud run services logs read mcp-slackbot --region=asia-northeast1 --limit=100

# 環境変数を確認
gcloud run services describe mcp-slackbot --region=asia-northeast1 --format=yaml
```

### データベースが保存されない

```bash
# バケットの確認
gsutil ls gs://YOUR_PROJECT_ID-mcp-slackbot-db/

# 権限の確認
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

## 更新方法

新しいコードをデプロイする場合：

```bash
# 1. イメージを再ビルド
export PROJECT_ID="your-project-id"
./build-and-push.sh

# 2. Terraformで更新
cd terraform
terraform apply
```

## クリーンアップ

すべてのリソースを削除：

```bash
cd terraform
terraform destroy
```

## サポート

- 詳細なドキュメント: [README.md](README.md)
- 英語版ガイド: [../DEPLOYMENT.md](../DEPLOYMENT.md)
- GitHub Issues: https://github.com/14kw/mcp-client-slackbot/issues

## コスト見積もり

最小構成（min_instances=1, 512Mi メモリ）の場合：

- Cloud Run: 約 $5-10/月
- Cloud Storage: 約 $0.02/月（1GBまで）
- Artifact Registry: 約 $0.10/月（0.5GBまで無料）

合計: 約 $5-10/月

min_instances=0に設定すると、使用していない時間は課金されません（コールドスタートあり）。
