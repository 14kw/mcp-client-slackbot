terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Create Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "mcp_slackbot" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  description   = "Docker repository for MCP Slackbot"
  format        = "DOCKER"
  
  depends_on = [google_project_service.artifactregistry]
}

# Create GCS bucket for SQLite database persistence
resource "google_storage_bucket" "database" {
  name          = "${var.project_id}-${var.app_name}-db"
  location      = var.region
  force_destroy = false
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# Create service account for Cloud Run
resource "google_service_account" "cloudrun" {
  account_id   = "${var.app_name}-sa"
  display_name = "Service Account for MCP Slackbot Cloud Run"
}

# Grant service account access to GCS bucket
resource "google_storage_bucket_iam_member" "cloudrun_bucket_access" {
  bucket = google_storage_bucket.database.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Deploy Cloud Run service
resource "google_cloud_run_v2_service" "mcp_slackbot" {
  name     = var.app_name
  location = var.region
  
  template {
    service_account = google_service_account.cloudrun.email
    
    containers {
      image = var.container_image
      
      env {
        name  = "SLACK_BOT_TOKEN"
        value = var.slack_bot_token
      }
      
      env {
        name  = "SLACK_APP_TOKEN"
        value = var.slack_app_token
      }
      
      env {
        name  = "OPENAI_API_KEY"
        value = var.openai_api_key
      }
      
      env {
        name  = "GROQ_API_KEY"
        value = var.groq_api_key
      }
      
      env {
        name  = "ANTHROPIC_API_KEY"
        value = var.anthropic_api_key
      }
      
      env {
        name  = "LLM_MODEL"
        value = var.llm_model
      }
      
      env {
        name  = "DB_PATH"
        value = "/data/test.db"
      }
      
      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.database.name
      }
      
      env {
        name  = "SYNC_INTERVAL"
        value = var.db_sync_interval
      }
      
      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
        
        cpu_idle = true
      }
      
      # Add startup probe for health check
      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
        
        tcp_socket {
          port = 8080
        }
      }
    }
    
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    
    # Set timeout
    timeout = "600s"
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.run,
    google_storage_bucket.database,
    google_service_account.cloudrun
  ]
}

# Allow unauthenticated invocations (required for Slack webhooks)
# Note: This is controlled by var.allow_unauthenticated
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0
  
  name     = google_cloud_run_v2_service.mcp_slackbot.name
  location = google_cloud_run_v2_service.mcp_slackbot.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
