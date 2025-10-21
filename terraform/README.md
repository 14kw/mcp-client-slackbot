# Google Cloud デプロイメントガイド

このガイドでは、MCP SlackbotをGoogle Cloud Platform (GCP)にTerraformを使ってデプロイする方法を説明します。

## 前提条件

- Google Cloud Platformアカウント
- gcloudコマンドラインツールのインストール
- Terraformのインストール (>= 1.0)
- Dockerのインストール
- Slackアプリの設定完了（Bot TokenとApp Token）
- LLMプロバイダーのAPIキー（OpenAI、Groq、またはAnthropic）

## アーキテクチャ

このデプロイメントには以下のリソースが含まれます：

- **Cloud Run**: Slackbotアプリケーションをホスト
- **Artifact Registry**: Dockerイメージを保存
- **Cloud Storage (GCS)**: SQLiteデータベースの永続化
- **Service Account**: Cloud RunがGCSにアクセスするための権限

### データベース永続化の仕組み

SQLiteデータベースは以下の方法で永続化されます：

1. **起動時**: GCSバケットから既存のデータベースをダウンロード
2. **実行中**: 定期的（デフォルト5分ごと）にGCSへバックアップ
3. **シャットダウン時**: 最新のデータベースをGCSへアップロード

バージョニングが有効化されており、最新3バージョンまで保持されます。

## セットアップ手順

### 1. Google Cloudプロジェクトの準備

```bash
# gcloudにログイン
gcloud auth login

# プロジェクトIDを設定
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# 必要なAPIを有効化（Terraformでも自動的に有効化されます）
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Artifact Registryに認証
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### 2. Dockerイメージのビルドとプッシュ

```bash
# リポジトリのルートディレクトリに移動
cd /path/to/mcp-client-slackbot

# Dockerイメージをビルド
docker build -t mcp-slackbot:latest .

# イメージにタグ付け（リージョンとプロジェクトIDを自分のものに変更）
export REGION="asia-northeast1"
docker tag mcp-slackbot:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-slackbot-repo/mcp-slackbot:latest

# 注: 最初のプッシュ前に、Terraformでリポジトリを作成するか、手動で作成する必要があります
# 手動で作成する場合:
gcloud artifacts repositories create mcp-slackbot-repo \
    --repository-format=docker \
    --location=${REGION} \
    --description="Docker repository for MCP Slackbot"

# イメージをプッシュ
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-slackbot-repo/mcp-slackbot:latest
```

### 3. Terraform変数の設定

```bash
cd terraform

# terraform.tfvars.exampleをコピー
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvarsを編集して、必要な値を設定
# - project_id: あなたのGCPプロジェクトID
# - container_image: 上記でプッシュしたイメージのURL
# - slack_bot_token: SlackのBot Token
# - slack_app_token: SlackのApp Token
# - openai_api_key: OpenAIのAPIキー（または他のLLMプロバイダー）
```

`terraform.tfvars`の例：

```hcl
project_id = "my-gcp-project"
region     = "asia-northeast1"
app_name   = "mcp-slackbot"

container_image = "asia-northeast1-docker.pkg.dev/my-gcp-project/mcp-slackbot-repo/mcp-slackbot:latest"

slack_bot_token = "xoxb-xxxxx"
slack_app_token = "xapp-xxxxx"

openai_api_key = "sk-xxxxx"
llm_model      = "gpt-4o-mini"

# オプション設定
db_sync_interval      = "300"  # 5分ごと
cloud_run_cpu         = "1"
cloud_run_memory      = "512Mi"
min_instances         = 1
max_instances         = 3
allow_unauthenticated = true
```

### 4. Terraformの実行

```bash
# Terraformを初期化
terraform init

# プランを確認
terraform plan

# リソースをデプロイ
terraform apply
```

デプロイが完了すると、以下の情報が表示されます：

- `cloud_run_service_url`: デプロイされたCloud RunサービスのURL
- `database_bucket_name`: データベース用のGCSバケット名
- `artifact_registry_repository`: Docker イメージのリポジトリID

### 5. デプロイの確認

```bash
# Cloud Runサービスのログを確認
gcloud run services logs read mcp-slackbot --region=asia-northeast1 --limit=50

# データベースバケットの内容を確認
gsutil ls gs://$(terraform output -raw database_bucket_name)/
```

## 更新とメンテナンス

### アプリケーションの更新

```bash
# 1. 新しいイメージをビルド
docker build -t mcp-slackbot:latest .

# 2. イメージをプッシュ
docker tag mcp-slackbot:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-slackbot-repo/mcp-slackbot:latest
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-slackbot-repo/mcp-slackbot:latest

# 3. Cloud Runサービスを更新
cd terraform
terraform apply
```

### データベースのバックアップ

データベースは自動的にGCSにバックアップされますが、手動でダウンロードすることもできます：

```bash
# 最新のデータベースをダウンロード
gsutil cp gs://$(terraform output -raw database_bucket_name)/test.db ./test.db.backup

# 特定のバージョンをダウンロード（バージョニングが有効）
gsutil ls -a gs://$(terraform output -raw database_bucket_name)/test.db
gsutil cp gs://$(terraform output -raw database_bucket_name)/test.db#<version> ./test.db.backup
```

### 設定の変更

環境変数を変更する場合：

```bash
# terraform.tfvarsを編集
vim terraform.tfvars

# 変更を適用
terraform apply
```

## トラブルシューティング

### ログの確認

```bash
# リアルタイムログ
gcloud run services logs tail mcp-slackbot --region=asia-northeast1

# 過去のログ
gcloud run services logs read mcp-slackbot --region=asia-northeast1 --limit=100
```

### データベースの復元

```bash
# 特定のバージョンのデータベースを復元
gsutil cp gs://BUCKET_NAME/test.db#VERSION gs://BUCKET_NAME/test.db

# Cloud Runサービスを再起動して新しいデータベースを読み込む
gcloud run services update mcp-slackbot --region=asia-northeast1
```

### サービスの再起動

```bash
gcloud run services update mcp-slackbot --region=asia-northeast1
```

## クリーンアップ

すべてのリソースを削除する場合：

```bash
cd terraform
terraform destroy
```

注意: データベースバケット内のデータも削除されます。必要に応じて事前にバックアップを取得してください。

## セキュリティに関する注意事項

1. **terraform.tfvars**: このファイルには機密情報（APIキー、トークン）が含まれるため、Gitにコミットしないでください。`.gitignore`に追加されていることを確認してください。

2. **Allow Unauthenticated**: 本番環境では`allow_unauthenticated = false`に設定し、適切な認証メカニズムを実装することを推奨します。

3. **APIキーの管理**: より安全な管理のため、Google Secret Managerの使用を検討してください。

4. **最小権限の原則**: Service Accountには必要最小限の権限のみを付与してください。

## コスト最適化

- `min_instances = 0`に設定すると、トラフィックがない時にインスタンスをゼロにできますが、コールドスタートが発生します。
- `db_sync_interval`を調整して、同期頻度とコストのバランスを取ってください。
- 不要なログの保持期間を短縮してください。

## サポート

問題が発生した場合は、GitHubのIssueを作成してください。
