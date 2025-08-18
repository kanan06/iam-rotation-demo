#!/bin/bash

set -e

echo "🚀 Deploying Multi-User IAM Key Rotation Infrastructure (Simple Approach)..."
echo "=================================================================="

# Set AWS region
aws configure set region us-east-1

# Step 1: Deploy CloudFormation stack
echo "📦 Step 1: Creating CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name iam-rotation-multi-user-simple \
    --template-body file://cloudformation/multi-user-simple.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
        ParameterKey=DemoUserName1,ParameterValue=demo-sns-service \
        ParameterKey=DemoUserName2,ParameterValue=demo-s3-service \
        ParameterKey=PipelineName,ParameterValue=demo-deployment-pipeline

echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name iam-rotation-multi-user-simple

echo "✅ CloudFormation stack created successfully!"

# Step 2: Get stack outputs
echo "📊 Step 2: Getting stack outputs..."
aws cloudformation describe-stacks \
    --stack-name iam-rotation-multi-user-simple \
    --query 'Stacks[0].Outputs' \
    --output json > config/multi-user-simple-stack-outputs.json

echo "📁 Stack outputs saved to config/multi-user-simple-stack-outputs.json"

# Step 3: Deploy Lambda function with actual code
echo "🔧 Step 3: Deploying Lambda function with actual code..."
./scripts/deploy-multi-user-lambda.sh

echo ""
echo "🎯 Multi-user infrastructure deployment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Test multi-user rotation: ./scripts/test-multi-user-simple.sh"
echo "2. Run multi-user demo: cd demo-service && python3 multi-user-demo.py"
echo ""
echo "🔍 Check the deployment:"
echo "   - CloudFormation stack: iam-rotation-multi-user-simple"
echo "   - Lambda function: iam-rotation-multi-user-demo"
echo "   - S3 bucket: Check config/multi-user-simple-stack-outputs.json"
echo ""
