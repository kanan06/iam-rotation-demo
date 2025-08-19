#!/bin/bash

set -e

echo "🔧 Deploying Multi-User Lambda Function..."
echo "=========================================="

# Check if stack outputs exist
if [ ! -f "config/multi-user-simple-stack-outputs.json" ]; then
    echo "❌ Stack outputs file not found. Please run deploy-multi-user-simple.sh first."
    exit 1
fi

# Get Lambda function name from stack outputs
LAMBDA_FUNCTION_NAME=$(cat config/multi-user-simple-stack-outputs.json | jq -r '.[] | select(.OutputKey=="RotationLambdaName") | .OutputValue')

if [ "$LAMBDA_FUNCTION_NAME" == "null" ] || [ -z "$LAMBDA_FUNCTION_NAME" ]; then
    echo "❌ Could not find Lambda function name in stack outputs"
    exit 1
fi

echo "📦 Lambda function name: $LAMBDA_FUNCTION_NAME"

# Create package directory
echo " Creating package directory..."
rm -rf lambda-package
mkdir -p lambda-package

# Copy Lambda function
echo "Copying Lambda function..."
cp lambda/multi-user-simple-lambda.py lambda-package/multi-user-simple-lambda.py

# Create deployment package
echo "🗜️ Creating deployment package..."
cd lambda-package
zip -r ../multi-user-lambda-deployment.zip .
cd ..

# Deploy to Lambda
echo "🚀 Deploying to Lambda..."
aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --zip-file fileb://multi-user-lambda-deployment.zip \
    --region us-east-1

# Wait for update to complete
echo "⏳ Waiting for Lambda update to complete..."
aws lambda wait function-updated \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region us-east-1

# Clean up
echo "🧹 Cleaning up..."
rm -rf lambda-package
rm multi-user-lambda-deployment.zip

echo "✅ Multi-user Lambda function deployed successfully!"
echo "🔍 Function: $LAMBDA_FUNCTION_NAME"
echo "📝 Handler: multi-user-simple-lambda.lambda_handler"
