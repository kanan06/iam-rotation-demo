#!/bin/bash

# Demo Pipeline Trigger
# This script demonstrates how the GitHub Actions pipeline would be triggered

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🚀 GitHub Actions Pipeline Trigger Demo"
print_status "======================================"

# Get the GitHub repository details
GITHUB_REPO="your-username/iam-rotation-demo"
GITHUB_TOKEN="your-github-token"

print_status "📋 Pipeline Configuration:"
echo "  Repository: $GITHUB_REPO"
echo "  Workflow: .github/workflows/iam-rotation-pipeline.yml"
echo "  Trigger: repository_dispatch event"

print_status "🔧 Pipeline Steps:"
echo "  1. 🔐 OIDC Authentication with AWS"
echo "  2. 📥 Fetch encrypted credentials from S3"
echo "  3. 🔓 Decrypt credentials using KMS"
echo "  4. 🏥 Run health checks with new credentials"
echo "  5. 🌐 Deploy demo website to S3"
echo "  6. 📧 Send success/failure notifications"

print_status "📊 Current Rotation State:"
aws dynamodb scan --table-name iam-rotation-state --query 'Items[*].{UserId:UserId.S,AccessKey:CurrentAccessKeyId.S,RotationCount:RotationCount.N}' --output table

print_status "🔑 New Access Keys Created:"
for user in demo-user-1 demo-user-2 demo-user-3 demo-user-4; do
    new_key=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' --output text)
    echo "  $user: $new_key"
done

print_status "📧 SNS Notification Sent:"
echo "  Topic: arn:aws:sns:us-east-1:160885290762:iam-rotation-notifications"
echo "  Message: 'IAM Key Rotation - Success: Successfully rotated keys for 4 users. Pipeline triggered.'"

print_status "🌐 Demo Website Deployment:"
echo "  Source: demo-website.html"
echo "  Destination: s3://iam-rotation-demo-app-160885290762/"
echo "  Website URL: https://iam-rotation-demo-app-160885290762.s3.amazonaws.com/demo-website.html"

print_success "🎉 Pipeline Trigger Demo Complete!"
print_status "The GitHub Actions pipeline would now:"
echo "  ✅ Authenticate using OIDC"
echo "  ✅ Fetch and decrypt new credentials"
echo "  ✅ Run comprehensive health checks"
echo "  ✅ Deploy the updated demo website"
echo "  ✅ Send success notifications"

print_status "🔍 To view the actual pipeline:"
echo "  Visit: https://github.com/$GITHUB_REPO/actions"
echo "  Look for workflow: 'IAM Rotation Pipeline'"
