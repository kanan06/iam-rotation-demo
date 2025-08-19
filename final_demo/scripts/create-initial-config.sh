#!/bin/bash

# Create Initial Configuration Files
# This script creates the initial .env files with placeholder credentials

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: $ACCOUNT_ID"

# Get KMS key ID
KMS_KEY_ID=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`KmsKeyId`].OutputValue' --output text)
print_status "KMS Key ID: $KMS_KEY_ID"

# Get config bucket name
CONFIG_BUCKET=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`ConfigBucket`].OutputValue' --output text)
print_status "Config Bucket: $CONFIG_BUCKET"

# Create env1.env with placeholder credentials
print_status "Creating env1.env..."
cat > env1.env << 'EOF'
ENVIRONMENT=env1
AWS_REGION=us-east-1

# User 1 credentials
AWS_ACCESS_KEY_ID_USER1=PLACEHOLDER_ACCESS_KEY_1
AWS_SECRET_ACCESS_KEY_USER1=PLACEHOLDER_SECRET_KEY_1

# User 2 credentials
AWS_ACCESS_KEY_ID_USER2=PLACEHOLDER_ACCESS_KEY_2
AWS_SECRET_ACCESS_KEY_USER2=PLACEHOLDER_SECRET_KEY_2
EOF

# Create env2.env with placeholder credentials
print_status "Creating env2.env..."
cat > env2.env << 'EOF'
ENVIRONMENT=env2
AWS_REGION=us-east-1

# User 2 credentials (shared with env1)
AWS_ACCESS_KEY_ID_USER2=PLACEHOLDER_ACCESS_KEY_2
AWS_SECRET_ACCESS_KEY_USER2=PLACEHOLDER_SECRET_KEY_2

# User 3 credentials
AWS_ACCESS_KEY_ID_USER3=PLACEHOLDER_ACCESS_KEY_3
AWS_SECRET_ACCESS_KEY_USER3=PLACEHOLDER_SECRET_KEY_3

# User 4 credentials
AWS_ACCESS_KEY_ID_USER4=PLACEHOLDER_ACCESS_KEY_4
AWS_SECRET_ACCESS_KEY_USER4=PLACEHOLDER_SECRET_KEY_4
EOF

# Create metadata files
print_status "Creating metadata files..."

cat > env1.env.metadata << EOF
{
  "file_name": "env1.env",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "encryption_key_id": "$KMS_KEY_ID",
  "users": ["demo-user-1", "demo-user-2"],
  "environment": "env1"
}
EOF

cat > env2.env.metadata << EOF
{
  "file_name": "env2.env",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "encryption_key_id": "$KMS_KEY_ID",
  "users": ["demo-user-2", "demo-user-3", "demo-user-4"],
  "environment": "env2"
}
EOF

print_success "Initial .env files created successfully"
print_status "Files created:"
echo "  - env1.env"
echo "  - env2.env"
echo "  - env1.env.metadata"
echo "  - env2.env.metadata"
