# アーキテクチャ概要

## システム構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                         Google Cloud Platform                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    Cloud Run Service                    │    │
│  │                                                         │    │
│  │  ┌─────────────────────────────────────────────────┐  │    │
│  │  │         MCP Slackbot Container                  │  │    │
│  │  │                                                 │  │    │
│  │  │  ┌──────────────┐    ┌──────────────────┐     │  │    │
│  │  │  │   Main App   │───>│  MCP Servers     │     │  │    │
│  │  │  │  (main.py)   │    │  - SQLite        │     │  │    │
│  │  │  │              │    │  - Fetch         │     │  │    │
│  │  │  └──────────────┘    └──────────────────┘     │  │    │
│  │  │         │                     │                │  │    │
│  │  │         │              ┌──────▼──────┐        │  │    │
│  │  │         │              │   test.db   │        │  │    │
│  │  │         │              │ (/data/)    │        │  │    │
│  │  │         │              └──────┬──────┘        │  │    │
│  │  │         │                     │                │  │    │
│  │  │    ┌────▼─────┐        ┌─────▼────────┐      │  │    │
│  │  │    │ db_sync  │───────>│  gsutil      │      │  │    │
│  │  │    │  (sync)  │        │  (GCS CLI)   │      │  │    │
│  │  │    └──────────┘        └──────┬───────┘      │  │    │
│  │  └──────────────────────────────┼───────────────┘  │    │
│  └────────────────────────────────┼──────────────────┘    │
│                                    │                        │
│                      ┌─────────────▼────────────────┐      │
│                      │  Cloud Storage Bucket        │      │
│                      │  (Database Persistence)      │      │
│                      │                              │      │
│                      │  test.db (current)           │      │
│                      │  test.db#version1            │      │
│                      │  test.db#version2            │      │
│                      │  test.db#version3            │      │
│                      └──────────────────────────────┘      │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │           Artifact Registry                        │   │
│  │  mcp-slackbot:latest                              │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         ▲                                    │
         │                                    │
         │ WebSocket                          │ HTTPS API
         │ (Socket Mode)                      │
         │                                    ▼
    ┌────┴─────────┐                    ┌──────────┐
    │    Slack     │                    │   LLM    │
    │   Platform   │                    │   APIs   │
    └──────────────┘                    └──────────┘
```

## コンポーネント説明

### 1. Cloud Run Service
- **役割**: コンテナ化されたアプリケーションの実行環境
- **特徴**: 
  - 自動スケーリング（min 1 - max 3 instances）
  - HTTPSエンドポイントの提供
  - サービスアカウントによる権限管理

### 2. MCP Slackbot Container
- **ベースイメージ**: Python 3.10-slim
- **含まれるもの**:
  - Python依存関係
  - Node.js（MCP servers用）
  - Google Cloud SDK（gsutil）
  - アプリケーションコード

### 3. データベース同期メカニズム

#### 起動時
```
1. Container starts
2. entrypoint.sh executes
3. db_sync.py checks GCS bucket
4. If database exists in GCS → Download to /data/test.db
5. If not exists → Use empty/new database
6. Start main application
```

#### 実行中
```
1. Background sync process starts
2. Every 5 minutes (configurable):
   - Upload current database to GCS
   - GCS maintains versions
3. Continue serving requests
```

#### シャットダウン時
```
1. SIGTERM signal received
2. Sync database to GCS (final backup)
3. Stop background processes
4. Exit gracefully
```

### 4. Cloud Storage Bucket
- **役割**: SQLiteデータベースの永続化ストレージ
- **機能**:
  - バージョニング有効（最新3バージョン保持）
  - 自動的に古いバージョンを削除
  - 高可用性・高耐久性

### 5. Artifact Registry
- **役割**: Dockerイメージの保管
- **利点**:
  - プライベートレジストリ
  - GCP内でのネットワーク高速化
  - 脆弱性スキャン対応

## データフロー

### メッセージ処理フロー

```
1. User sends message in Slack
   │
   ├─> Slack API (WebSocket) ──> Cloud Run
   │
2. Cloud Run receives message
   │
   ├─> Process with LLM API (OpenAI/Groq/Anthropic)
   │
   ├─> If tool call needed:
   │   └─> Execute MCP tool (SQLite/Fetch)
   │       └─> SQLite: Read/Write to /data/test.db
   │
3. Generate response
   │
   └─> Send back to Slack via API
```

### データベース同期フロー

```
┌─────────────────┐
│  Container      │
│  starts         │
└────────┬────────┘
         │
         ├─> Check GCS: gs://bucket/test.db exists?
         │
         ├─> YES: Download to /data/test.db
         │   NO:  Create new database
         │
┌────────▼────────┐
│  App running    │
│                 │
│  Every 5 min:   │───┐
│  sync to GCS    │   │
└─────────────────┘   │
         │            │
         │            └──> gsutil cp /data/test.db gs://bucket/
         │
┌────────▼────────┐
│  SIGTERM        │
│  received       │
└────────┬────────┘
         │
         └─> Final sync to GCS
             Exit
```

## セキュリティ

### 認証・認可
- Service Account: Cloud RunがGCSにアクセスするための専用アカウント
- IAM Role: `roles/storage.objectAdmin` でバケットへの読み書き権限

### シークレット管理
- 環境変数としてCloud Runに設定
- terraform.tfvarsはGitにコミットされない
- 推奨: Google Secret Manager使用（オプション）

### ネットワーク
- Cloud Run: HTTPSのみ
- Slack: WebSocket (wss://) で安全な通信
- LLM APIs: HTTPS

## スケーリング戦略

### 垂直スケーリング
- CPU: 1コア（調整可能）
- Memory: 512Mi（調整可能）
- より多くのメモリが必要な場合: `cloud_run_memory = "1Gi"`

### 水平スケーリング
- Min instances: 1（コールドスタート回避）
- Max instances: 3（コスト管理）
- 設定可能: `min_instances = 0`（コスト削減、コールドスタートあり）

## 可用性とディザスタリカバリ

### 高可用性
- Cloud Run: 自動的に複数ゾーンに分散
- Cloud Storage: 11 nines（99.999999999%）の耐久性

### バックアップ
- 自動: GCSバージョニング（最新3バージョン）
- 手動バックアップ: `gsutil cp gs://bucket/test.db ./backup.db`

### リカバリ
```bash
# 特定バージョンへの復元
gsutil ls -a gs://bucket/test.db  # バージョン一覧
gsutil cp gs://bucket/test.db#VERSION gs://bucket/test.db

# サービス再起動
gcloud run services update mcp-slackbot --region=asia-northeast1
```

## パフォーマンス考慮事項

### レイテンシ
- Cold start: 5-10秒（min_instances=0の場合）
- Warm start: <1秒
- LLM API call: 1-5秒（モデルによる）

### データベース同期
- 同期頻度: 5分（調整可能）
- 同期時間: 通常<1秒（小さいDB）
- 影響: バックグラウンド処理のため、ユーザー体験に影響なし

## モニタリング

### ログ
```bash
# リアルタイム
gcloud run services logs tail mcp-slackbot --region=asia-northeast1

# 検索
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=mcp-slackbot" --limit=50
```

### メトリクス
- Cloud Runダッシュボード: リクエスト数、レイテンシ、エラー率
- Cloud Storageメトリクス: ストレージ使用量、API呼び出し回数

### アラート（オプション）
- エラー率が閾値を超えた場合
- メモリ使用率が高い場合
- データベース同期失敗

## コスト最適化

### 推奨設定

**開発環境**:
```hcl
min_instances = 0
cloud_run_memory = "512Mi"
db_sync_interval = "600"  # 10分
```

**本番環境**:
```hcl
min_instances = 1
cloud_run_memory = "512Mi"
db_sync_interval = "300"  # 5分
max_instances = 5
```

### コスト削減のヒント
1. min_instances=0でアイドル時のコストを削減
2. 不要なログを減らす
3. db_sync_intervalを長くする（データロスリスクとのトレードオフ）
4. Cloud Run CPU allocationを"cpu_idle = true"に設定（既に設定済み）
