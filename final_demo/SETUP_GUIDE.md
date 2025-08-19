# 🚀 IAM Key Rotation Demo - Setup Guide

This guide will walk you through setting up the complete IAM key rotation demo from scratch.

## 📋 Prerequisites

Before starting, ensure you have:

- ✅ AWS CLI installed and configured
- ✅ Python 3.9+ installed
- ✅ jq (JSON processor) installed
- ✅ A GitHub account and repository
- ✅ AWS account with appropriate permissions

### Install Prerequisites

```bash
# Install jq (Ubuntu/Debian)
sudo apt-get install jq

# Install jq (macOS)
brew install jq

# Install jq (CentOS/RHEL)
sudo yum install jq

# Verify AWS CLI
aws --version

# Verify Python
python3 --version

# Verify jq
jq --version
```

## 🏗️ Step 1: Deploy Infrastructure

### 1.1 Navigate to the Demo Directory

```bash
cd final_demo
```

### 1.2 Run the Setup Script

```bash
./scripts/setup-pipeline.sh
```

This script will:
- ✅ Deploy CloudFormation infrastructure
- ✅ Create 4 demo IAM users
- ✅ Create and encrypt `.env` files
- ✅ Deploy Lambda function
- ✅ Test the setup

**Expected Output:**
```
🚀 IAM Key Rotation Demo - Complete Setup
==========================================

[INFO] Checking prerequisites...
[SUCCESS] All prerequisites are satisfied
[INFO] Getting AWS account ID...
[SUCCESS] AWS Account ID: 123456789012
[INFO] Deploying CloudFormation infrastructure...
[SUCCESS] Infrastructure deployed successfully
...
🎉 IAM Key Rotation Demo Setup Complete!
```

### 1.3 Verify Infrastructure

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name iam-rotation-demo

# List created resources
aws s3 ls | grep iam-rotation-demo
aws dynamodb list-tables | grep iam-rotation-state
aws iam list-users | grep demo-user
```

## 🔧 Step 2: Set Up GitHub Repository

### 2.1 Create GitHub Repository

1. Go to [GitHub](https://github.com) and create a new repository
2. Name it something like `iam-rotation-demo`
3. Make it public or private (your choice)

### 2.2 Add Workflow File

1. In your repository, create the directory structure:
   ```bash
   mkdir -p .github/workflows
   ```

2. Copy the workflow file:
   ```bash
   cp final_demo/.github/workflows/iam-rotation-pipeline.yml .github/workflows/
   ```

3. Commit and push:
   ```bash
   git add .github/workflows/iam-rotation-pipeline.yml
   git commit -m "Add IAM rotation pipeline workflow"
   git push origin main
   ```

### 2.3 Add GitHub Secret

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AWS_ACCOUNT_ID`
5. Value: Your AWS account ID (found in the setup output)
6. Click **Add secret**

## 🧪 Step 3: Test the System

### 3.1 Run Comprehensive Tests

```bash
./scripts/test-rotation.sh
```

This will test:
- ✅ Infrastructure components
- ✅ .env file encryption/decryption
- ✅ IAM users and access keys
- ✅ Lambda rotation function
- ✅ Health checks
- ✅ SNS notifications

### 3.2 Manual Testing

```bash
# Test Lambda function
aws lambda invoke \
  --function-name iam-rotation-function \
  --payload '{"target_files": ["env1.env"], "force_rotation": true}' \
  response.json

# Check response
cat response.json | jq .
```

## 🔄 Step 4: Trigger the Pipeline

### 4.1 Manual Trigger

You can manually trigger the pipeline by:

1. Going to your GitHub repository
2. Navigate to **Actions** tab
3. Select **IAM Key Rotation Pipeline**
4. Click **Run workflow**
5. Choose **Run workflow**

### 4.2 Automatic Trigger

The pipeline will be triggered automatically when:
- Lambda function rotates keys (every 7 days)
- Manual Lambda invocation with rotation

## 📊 Step 5: Monitor and Verify

### 5.1 Check GitHub Actions

1. Go to your repository's **Actions** tab
2. Monitor the pipeline execution
3. Check for any failures or issues

### 5.2 Check AWS Resources

```bash
# Check Lambda logs
aws logs tail /aws/lambda/iam-rotation-function --follow

# Check DynamoDB state
aws dynamodb scan --table-name iam-rotation-state

# Check S3 buckets
aws s3 ls s3://iam-rotation-demo-config-ACCOUNT_ID/
aws s3 ls s3://iam-rotation-demo-app-ACCOUNT_ID/
```

### 5.3 Check Demo Website

After successful pipeline execution, you should see:
- A demo website deployed to S3
- Beautiful UI showing rotation information
- Health check results

## 🔍 Step 6: Understanding the Demo

### 6.1 Environment Files

The demo uses two `.env` files:

- **env1.env**: Contains `demo-user-1` and `demo-user-2`
- **env2.env**: Contains `demo-user-2`, `demo-user-3`, and `demo-user-4`

**Note**: `demo-user-2` is common between both files.

### 6.2 Rotation Process

1. **Trigger**: Lambda checks for keys older than 7 days
2. **Rotation**: Creates new keys, deactivates old ones
3. **Update**: Updates encrypted `.env` files in S3
4. **Health Check**: Validates new credentials
5. **Pipeline**: Triggers GitHub Actions
6. **Deployment**: Deploys demo website
7. **Cleanup**: Deletes old keys

### 6.3 Security Features

- 🔒 **KMS Encryption**: All files encrypted at rest
- 🔐 **OIDC Authentication**: No stored credentials
- 🛡️ **IAM Least Privilege**: Minimal permissions
- 📊 **DynamoDB Tracking**: Audit trail
- ✅ **Health Checks**: Validation
- 🔄 **Rollback**: Automatic on failures

## 🚨 Troubleshooting

### Common Issues

#### 1. Setup Script Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check prerequisites
which aws python3 jq

# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name iam-rotation-demo
```

#### 2. GitHub Actions Fails

- ✅ Verify `AWS_ACCOUNT_ID` secret is set
- ✅ Check OIDC provider exists in AWS
- ✅ Review workflow logs in GitHub

#### 3. Lambda Function Fails

```bash
# Check Lambda logs
aws logs tail /aws/lambda/iam-rotation-function --follow

# Test Lambda manually
aws lambda invoke \
  --function-name iam-rotation-function \
  --payload '{"target_files": ["env1.env"], "force_rotation": false}' \
  test-response.json
```

#### 4. Health Checks Fail

- ✅ Verify IAM user permissions
- ✅ Check S3 bucket access
- ✅ Review DynamoDB permissions

### Debug Commands

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name iam-rotation-demo \
  --query 'Stacks[0].Outputs' \
  --output table

# Test S3 access
aws s3 ls s3://iam-rotation-demo-config-ACCOUNT_ID/

# Test DynamoDB
aws dynamodb scan --table-name iam-rotation-state

# Test SNS
aws sns list-topics

# Check IAM users
aws iam list-users --query 'Users[?contains(UserName, `demo-user-`)].UserName'
```

## 🎯 Next Steps

After successful setup:

1. **Monitor the system** for 7 days to see automatic rotation
2. **Customize the rotation policy** if needed
3. **Add more users** or environment files
4. **Integrate with your existing systems**
5. **Set up additional monitoring** and alerting

## 📚 Additional Resources

- [Complete README](README.md)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)

---

**🎉 Congratulations! Your IAM Key Rotation Demo is now ready!**
