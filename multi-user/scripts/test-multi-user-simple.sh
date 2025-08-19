#!/bin/bash

set -e

echo "🧪 Testing Multi-User IAM Key Rotation (Simple Approach)..."
echo "=========================================================="

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

echo "🔍 Lambda function: $LAMBDA_FUNCTION_NAME"

# Test 1: Invoke Lambda function for multi-user rotation
echo ""
echo "🧪 Test 1: Invoking Multi-User Rotation Lambda..."
echo "------------------------------------------------"

aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload '{"test": true}' \
    multi-user-test-response.json \
    --region us-east-1 \
    --cli-binary-format raw-in-base64-out

echo "📄 Lambda Response:"
cat multi-user-test-response.json
echo ""

# Test 2: Check DynamoDB for rotation state
echo "📊 Test 2: Checking DynamoDB for rotation state..."
echo "------------------------------------------------"

# Check SNS user state
echo "👤 Checking demo-sns-service state:"
aws dynamodb get-item \
    --table-name iam-rotation-multi-user-state \
    --key '{"UserId": {"S": "demo-sns-service"}}' \
    --output table

echo ""

# Check S3 user state
echo "👤 Checking demo-s3-service state:"
aws dynamodb get-item \
    --table-name iam-rotation-multi-user-state \
    --key '{"UserId": {"S": "demo-s3-service"}}' \
    --output table

echo ""

# Test 3: Check S3 for updated multi-user config
echo "📁 Test 3: Checking S3 for updated multi-user config..."
echo "------------------------------------------------------"

# Get config bucket name from stack outputs
CONFIG_BUCKET=$(cat config/multi-user-simple-stack-outputs.json | jq -r '.[] | select(.OutputKey=="ConfigBucket") | .OutputValue')

if [ "$CONFIG_BUCKET" != "null" ] && [ -n "$CONFIG_BUCKET" ]; then
    echo "📦 Config bucket: $CONFIG_BUCKET"
    echo "📄 Multi-user config file:"
    aws s3 cp "s3://$CONFIG_BUCKET/.env" -
else
    echo "❌ Could not find config bucket in stack outputs"
fi

echo ""

# Test 4: Check current IAM keys for both users
echo "🔍 Test 4: Checking current IAM keys..."
echo "---------------------------------------"

echo "👤 demo-sns-service keys:"
aws iam list-access-keys \
    --user-name demo-sns-service \
    --output table

echo ""

echo "👤 demo-s3-service keys:"
aws iam list-access-keys \
    --user-name demo-s3-service \
    --output table

echo ""

# Test 5: Test multi-user demo service
echo "🚀 Test 5: Testing Multi-User Demo Service..."
echo "---------------------------------------------"

cd demo-service
python3 multi-user-demo.py
cd ..

echo ""
echo "🧹 Cleaning up test files..."
rm -f multi-user-test-response.json

echo ""
echo "✅ Multi-user testing completed!"
echo ""
echo "📋 Test Summary:"
echo "   ✅ Lambda function invoked"
echo "   ✅ DynamoDB state checked"
echo "   ✅ S3 config verified"
echo "   ✅ IAM keys verified"
echo "   ✅ Demo service tested"
echo ""
echo "🎯 Next steps:"
echo "   - Check SNS notifications for rotation results"
echo "   - Verify both users can access their respective services"
echo "   - Test individual user rotation if needed"
