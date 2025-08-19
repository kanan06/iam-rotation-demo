#!/bin/bash

# Test Lambda Function
# This script tests the Lambda function to verify the username mapping fix

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Get Lambda function name
LAMBDA_FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' --output text)
print_status "Lambda Function Name: $LAMBDA_FUNCTION_NAME"

# Test 1: Test with env1.env file
print_status "Testing Lambda function with env1.env file..."
aws lambda invoke \
    --function-name $LAMBDA_FUNCTION_NAME \
    --payload '{"target_files": ["env1.env"], "force_rotation": false}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-response-1.json

print_status "Response for env1.env:"
cat /tmp/lambda-response-1.json | jq '.'

# Test 2: Test with env2.env file
print_status "Testing Lambda function with env2.env file..."
aws lambda invoke \
    --function-name $LAMBDA_FUNCTION_NAME \
    --payload '{"target_files": ["env2.env"], "force_rotation": false}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-response-2.json

print_status "Response for env2.env:"
cat /tmp/lambda-response-2.json | jq '.'

# Test 3: Test with both files
print_status "Testing Lambda function with both files..."
aws lambda invoke \
    --function-name $LAMBDA_FUNCTION_NAME \
    --payload '{"target_files": ["env1.env", "env2.env"], "force_rotation": false}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-response-both.json

print_status "Response for both files:"
cat /tmp/lambda-response-both.json | jq '.'

print_success "Lambda function testing completed!"
print_status "Check the responses above to verify the username mapping is working correctly."
