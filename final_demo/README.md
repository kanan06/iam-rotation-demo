# 🔐 IAM Key Rotation Demo

A comprehensive, automated IAM key rotation system with multi-file support, 7-day rotation policy, health checks, and GitHub Actions integration using OIDC authentication.

## 🎯 Features

- **Multi-file Rotation**: Handle multiple `.env` files with different user sets
- **7-day Rotation Policy**: Automatically rotate keys older than 7 days
- **Common User Handling**: Properly manage users that appear in multiple files
- **OIDC Authentication**: Secure GitHub Actions integration without stored credentials
- **Health Checks**: Comprehensive pre and post-deployment validation
- **Automated Rollback**: Rollback on health check failures
- **KMS Encryption**: Full encryption of configuration files
- **DynamoDB State Tracking**: Maintain rotation history and state
- **SNS Notifications**: Real-time notifications for rotation events
- **Demo Website**: Beautiful demo website deployed after successful rotation

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Lambda        │    │   GitHub        │    │   AWS           │
│   Function      │───▶│   Actions       │───▶│   Services      │
│                 │    │   (OIDC)        │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Config     │    │   Health        │    │   Demo          │
│   (Encrypted)   │    │   Checks        │    │   Website       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
final_demo/
├── cloudformation/
│   └── infrastructure.yaml          # Complete infrastructure template
├── lambda/
│   └── lambda_function.py           # Enhanced rotation logic
├── scripts/
│   ├── setup-pipeline.sh            # Complete setup script
│   ├── test-rotation.sh             # Testing script
│   ├── fetch-aws-credentials.py     # Credential fetching
│   └── health-check.py              # Health check script
├── .github/workflows/
│   └── iam-rotation-pipeline.yml    # GitHub Actions workflow
└── README.md                        # This file
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.9+
- jq (JSON processor)
- GitHub repository (for the pipeline)

### 1. Deploy Infrastructure

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the complete setup
./scripts/setup-pipeline.sh
```

This script will:
- Deploy CloudFormation infrastructure
- Create 4 demo IAM users
- Create and encrypt `.env` files
- Deploy Lambda function
- Test the setup

### 2. Set Up GitHub Repository

1. **Create a new GitHub repository**
2. **Copy the workflow file**:
   ```bash
   cp .github/workflows/iam-rotation-pipeline.yml /path/to/your/repo/.github/workflows/
   ```
3. **Add GitHub secret**:
   - Go to your repository Settings → Secrets and variables → Actions
   - Add secret: `AWS_ACCOUNT_ID` with your AWS account ID

### 3. Test the System

```bash
# Run comprehensive tests
./scripts/test-rotation.sh
```

## 📋 Configuration

### Environment Files

The demo uses two `.env` files:

- **env1.env**: Contains `demo-user-1` and `demo-user-2`
- **env2.env**: Contains `demo-user-2`, `demo-user-3`, and `demo-user-4`

Note: `demo-user-2` is common between both files.

### File Format

```bash
# Environment Configuration
AWS_ACCESS_KEY_ID_USER1=AKIA...
AWS_SECRET_ACCESS_KEY_USER1=...
AWS_ACCESS_KEY_ID_USER2=AKIA...
AWS_SECRET_ACCESS_KEY_USER2=...
ENVIRONMENT=env1
AWS_REGION=us-east-1
```

## 🔄 Rotation Process

1. **Trigger**: Lambda function checks for keys older than 7 days
2. **Rotation**: Creates new keys and deactivates old ones
3. **Update**: Updates encrypted `.env` files in S3
4. **Health Check**: Validates new credentials work
5. **Pipeline**: Triggers GitHub Actions pipeline
6. **Deployment**: Deploys demo website
7. **Cleanup**: Deletes old keys after successful deployment

## 🛡️ Security Features

- **KMS Encryption**: All `.env` files are encrypted at rest
- **OIDC Authentication**: No AWS credentials stored in GitHub
- **IAM Least Privilege**: Minimal required permissions
- **DynamoDB State Tracking**: Audit trail of all rotations
- **Health Checks**: Validation before and after rotation
- **Rollback Capability**: Automatic rollback on failures

## 🧪 Testing

### Manual Testing

```bash
# Test infrastructure
./scripts/test-rotation.sh

# Test specific components
aws lambda invoke \
  --function-name iam-rotation-function \
  --payload '{"target_files": ["env1.env"], "force_rotation": true}' \
  response.json
```

### Automated Testing

The GitHub Actions pipeline includes:
- Credential fetching from S3
- Health checks with new credentials
- Application deployment
- Post-deployment validation
- Rollback on failures

## 📊 Monitoring

### CloudWatch Logs

- Lambda function logs: `/aws/lambda/iam-rotation-function`
- GitHub Actions logs: Available in GitHub repository

### DynamoDB State

```bash
# Check rotation state
aws dynamodb scan --table-name iam-rotation-state
```

### SNS Notifications

All rotation events are sent to the SNS topic for monitoring.

## 🔧 Customization

### Adding More Users

1. Update the CloudFormation template parameters
2. Modify the `.env` files
3. Update the Lambda function logic if needed

### Changing Rotation Policy

Edit the `ROTATION_DAYS` constant in `lambda/lambda_function.py`.

### Adding More Environment Files

1. Create new `.env` files
2. Update the `ENV_FILES` list in the Lambda function
3. Modify the rotation logic as needed

## 🚨 Troubleshooting

### Common Issues

1. **Lambda Function Fails**:
   - Check CloudWatch logs
   - Verify IAM permissions
   - Ensure `.env` files exist in S3

2. **GitHub Actions Fails**:
   - Verify OIDC setup
   - Check `AWS_ACCOUNT_ID` secret
   - Review workflow logs

3. **Health Checks Fail**:
   - Verify IAM user permissions
   - Check S3 bucket access
   - Review DynamoDB permissions

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/iam-rotation-function --follow

# Test S3 access
aws s3 ls s3://iam-rotation-demo-config-ACCOUNT_ID/

# Test DynamoDB
aws dynamodb scan --table-name iam-rotation-state

# Test SNS
aws sns list-topics
```

## 📚 Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Open an issue in the repository

---

**�� Happy Rotating!**
# Pipeline Trigger
