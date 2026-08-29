# ==============================================================================
# Deploy oracle-llm (Qwen3-0.6B) to Google Cloud Run (PowerShell / Windows)
# ==============================================================================

$ErrorActionPreference = "Stop"

$SERVICE_NAME = "oracle-llm"
$REGION = "us-central1"

$PROJECT_ID = gcloud config get-value project
if (-not $PROJECT_ID) {
    Write-Error "No GCP project found. Please run 'gcloud config set project YOUR_PROJECT_ID' first."
    exit 1
}

$IMAGE_TAG = "gcr.io/$PROJECT_ID/${SERVICE_NAME}:latest"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Project ID: $PROJECT_ID"
Write-Host " Service:    $SERVICE_NAME"
Write-Host " Region:     $REGION"
Write-Host " Image:      $IMAGE_TAG"
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Enable required GCP services
Write-Host "[1/3] Enabling Cloud Build and Cloud Run APIs..." -ForegroundColor Yellow
gcloud services enable run.googleapis.com cloudbuild.googleapis.com

# 2. Build image using Cloud Build
Write-Host "[2/3] Building container image in Google Cloud Build..." -ForegroundColor Yellow
gcloud builds submit --tag $IMAGE_TAG .

# 3. Deploy to Cloud Run with Free Tier parameters (Qwen3-0.6B only needs 2GB)
Write-Host "[3/3] Deploying to Cloud Run..." -ForegroundColor Yellow
gcloud run deploy $SERVICE_NAME `
  --image $IMAGE_TAG `
  --platform managed `
  --region $REGION `
  --allow-unauthenticated `
  --cpu 2 `
  --memory 2Gi `
  --min-instances 0 `
  --max-instances 1 `
  --concurrency 4 `
  --timeout 300 `
  --no-cpu-throttling=false

Write-Host "============================================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
$SERVICE_URL = gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format="value(status.url)"
Write-Host "Service URL: $SERVICE_URL" -ForegroundColor Cyan
Write-Host "API Endpoint: $SERVICE_URL/v1/chat/completions" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Green
