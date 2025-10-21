#!/bin/bash
# Script to build and push Docker image to Google Artifact Registry

set -e

# Check if required environment variables are set
if [ -z "$PROJECT_ID" ]; then
    echo "Error: PROJECT_ID environment variable is not set"
    echo "Usage: export PROJECT_ID=your-project-id && ./build-and-push.sh"
    exit 1
fi

# Configuration
REGION="${REGION:-asia-northeast1}"
REPO_NAME="${REPO_NAME:-mcp-slackbot-repo}"
IMAGE_NAME="${IMAGE_NAME:-mcp-slackbot}"
TAG="${TAG:-latest}"

# Construct full image URL
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"

echo "Building Docker image..."
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Repository: ${REPO_NAME}"
echo "Image: ${IMAGE_NAME}"
echo "Tag: ${TAG}"
echo "Full URL: ${IMAGE_URL}"
echo ""

# Build the image
echo "Building image..."
docker build -t ${IMAGE_NAME}:${TAG} .

# Tag the image
echo "Tagging image..."
docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_URL}

# Configure Docker authentication if not already done
echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet || true

# Check if repository exists, create if it doesn't
echo "Checking if Artifact Registry repository exists..."
if ! gcloud artifacts repositories describe ${REPO_NAME} --location=${REGION} &>/dev/null; then
    echo "Repository does not exist. Creating..."
    gcloud artifacts repositories create ${REPO_NAME} \
        --repository-format=docker \
        --location=${REGION} \
        --description="Docker repository for MCP Slackbot"
    echo "Repository created successfully."
else
    echo "Repository already exists."
fi

# Push the image
echo "Pushing image to Artifact Registry..."
docker push ${IMAGE_URL}

echo ""
echo "✓ Image successfully pushed!"
echo "Image URL: ${IMAGE_URL}"
echo ""
echo "You can now update your terraform.tfvars with:"
echo "container_image = \"${IMAGE_URL}\""
