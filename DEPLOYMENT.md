# Deployment Guide

## Google Cloud Platform Deployment

This project includes Terraform configuration for deploying the MCP Slackbot to Google Cloud Platform with persistent SQLite database storage.

### Quick Start

1. **Prerequisites**
   - Google Cloud account with a project
   - `gcloud` CLI installed and authenticated
   - Terraform >= 1.0 installed
   - Docker installed
   - Slack app configured (Bot Token and App Token)
   - LLM API key (OpenAI, Groq, or Anthropic)

2. **Build and Push Docker Image**

   ```bash
   export PROJECT_ID="your-gcp-project-id"
   ./build-and-push.sh
   ```

3. **Configure Terraform**

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Deploy**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Architecture

The deployment includes:

- **Cloud Run**: Hosts the Slackbot application
- **Artifact Registry**: Stores Docker images
- **Cloud Storage (GCS)**: Persists SQLite database
- **Service Account**: Grants Cloud Run access to GCS

### Database Persistence

The SQLite database is persisted using Google Cloud Storage:

- **On startup**: Downloads existing database from GCS
- **While running**: Syncs database to GCS every 5 minutes (configurable)
- **On shutdown**: Uploads latest database to GCS
- **Versioning**: Keeps last 3 versions of the database

### Detailed Documentation

For detailed instructions in Japanese, see [terraform/README.md](terraform/README.md).

### Key Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | Required |
| `region` | GCP region | `asia-northeast1` |
| `container_image` | Docker image URL | Required |
| `slack_bot_token` | Slack bot token | Required |
| `slack_app_token` | Slack app token | Required |
| `llm_model` | LLM model to use | `gpt-4o-mini` |
| `db_sync_interval` | Database sync interval (seconds) | `300` |
| `min_instances` | Minimum Cloud Run instances | `1` |
| `max_instances` | Maximum Cloud Run instances | `3` |

### Updating the Deployment

```bash
# Build new image
./build-and-push.sh

# Apply changes
cd terraform
terraform apply
```

### Monitoring

View logs:
```bash
gcloud run services logs tail mcp-slackbot --region=asia-northeast1
```

Check database backups:
```bash
gsutil ls gs://$(terraform output -raw database_bucket_name)/
```

### Cleanup

To remove all resources:
```bash
cd terraform
terraform destroy
```

**Warning**: This will delete the database bucket and all backups. Make sure to download any important data first.

### Security Notes

1. Never commit `terraform.tfvars` (contains sensitive data)
2. Consider using Google Secret Manager for API keys
3. Set `allow_unauthenticated = false` in production
4. Use least privilege principle for service accounts

### Cost Optimization

- Set `min_instances = 0` to scale to zero (increases cold start time)
- Adjust `db_sync_interval` to balance between sync frequency and costs
- Configure log retention policies

### Troubleshooting

**Database not persisting:**
- Check service account permissions
- Verify GCS bucket exists: `gsutil ls`
- Check logs: `gcloud run services logs read mcp-slackbot`

**Cloud Run deployment fails:**
- Verify image URL is correct
- Check that required APIs are enabled
- Ensure service account has necessary permissions

**Out of memory errors:**
- Increase `cloud_run_memory` in terraform.tfvars
- Consider optimizing application memory usage

For more help, please open an issue on GitHub.
