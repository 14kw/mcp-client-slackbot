variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "app_name" {
  description = "Application name (used for resource naming)"
  type        = string
  default     = "mcp-slackbot"
}

variable "container_image" {
  description = "Docker container image URL (e.g., asia-northeast1-docker.pkg.dev/PROJECT_ID/mcp-slackbot-repo/mcp-slackbot:latest)"
  type        = string
}

# Slack Configuration
variable "slack_bot_token" {
  description = "Slack bot token (xoxb-...)"
  type        = string
  sensitive   = true
}

variable "slack_app_token" {
  description = "Slack app token (xapp-...)"
  type        = string
  sensitive   = true
}

# LLM API Keys
variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "groq_api_key" {
  description = "Groq API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "llm_model" {
  description = "LLM model to use"
  type        = string
  default     = "gpt-4o-mini"
}

# Database Configuration
variable "db_sync_interval" {
  description = "Database sync interval in seconds"
  type        = string
  default     = "300"
}

# Cloud Run Configuration
variable "cloud_run_cpu" {
  description = "CPU allocation for Cloud Run service"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory allocation for Cloud Run service"
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 3
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to Cloud Run service (set to false for production)"
  type        = bool
  default     = true
}
