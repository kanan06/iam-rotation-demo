# IAM Key Rotation Demo

A comprehensive demonstration of automated IAM key rotation systems for both single-user and multi-user scenarios using AWS services.

## 🎯 **Overview**

This project demonstrates two different approaches to IAM key rotation:

1. **Single-User System** (`single-user/`) - Complete, working system for rotating keys for one user
2. **Multi-User System** (`multi-user/`) - System for rotating keys for multiple users simultaneously

Both systems include:
- ✅ **Automated IAM Key Rotation**
- ✅ **KMS Encryption** for secure secret storage
- ✅ **S3 Configuration Management**
- ✅ **DynamoDB State Tracking** with TTL cleanup
- ✅ **SNS Notifications** for rotation events
- ✅ **Demo Services** that consume rotated keys

## 📁 **Project Structure**

```
iam-rotation-demo/
├── single-user/                    # Single-user IAM key rotation
│   ├── lambda/
│   │   └── lambda_function.py
│   ├── cloudformation/
│   │   └── infrastructure.yaml
│   ├── scripts/
│   │   ├── deploy-infrastructure.sh
│   │   ├── deploy-lambda.sh
│   │   ├── test-rotation.sh
│   │   └── setup-demo-pipeline.sh
│   ├── demo-service/
│   │   └── sns-publisher.py
│   └── README.md
├── multi-user/                     # Multi-user IAM key rotation
│   ├── lambda/
│   │   └── multi-user-lambda.py
│   ├── cloudformation/
│   │   └── multi-user-simple.yaml
│   ├── scripts/
│   │   ├── deploy-multi-user-simple.sh
│   │   ├── deploy-multi-user-lambda.sh
│   │   └── test-multi-user-simple.sh
│   ├── demo-service/
│   │   ├── multi-user-demo.py
│   │   └── test-multi-user-working.py
│   └── README.md
├── demo-app/                       # Demo web application
│   └── index.html
├── config/                         # Configuration files
├── .gitignore
└── README.md                       # This file
```

## 🚀 **Quick Start**

### **Single-User System (Fully Operational)**
```bash
cd single-user
./scripts/deploy-infrastructure.sh
./scripts/deploy-lambda.sh
./scripts/setup-demo-pipeline.sh
./scripts/test-rotation.sh
cd demo-service && python3 sns-publisher.py
```

### **Multi-User System (Ready for Deployment)**
```bash
cd multi-user
./scripts/deploy-multi-user-simple.sh
./scripts/deploy-multi-user-lambda.sh
./scripts/test-multi-user-simple.sh
cd demo-service && python3 multi-user-demo.py
```

## 🔧 **Architecture Comparison**

| Feature | Single-User | Multi-User |
|---------|-------------|------------|
| **Users** | 1 user (`demo-sns-service`) | 2 users (`demo-sns-service`, `demo-s3-service`) |
| **Rotation** | Individual user | All users simultaneously |
| **Permissions** | SNS only | SNS + S3 (isolated) |
| **Config** | Single-user `.env` | Multi-user `.env` |
| **State Tracking** | Single user in DynamoDB | Multiple users in DynamoDB |
| **Pipeline Integration** | ✅ Working | 🔄 Ready |
| **Status** | ✅ Fully Operational | ✅ Concept Validated |

## 🎯 **System Status**

### **Single-User System: FULLY OPERATIONAL**
- ✅ Infrastructure deployed and working
- ✅ Lambda function rotating keys successfully
- ✅ KMS encryption/decryption working
- ✅ S3 config updates working
- ✅ DynamoDB state tracking working
- ✅ Demo service consuming rotated keys
- ✅ Pipeline integration working

### **Multi-User System: CONCEPT VALIDATED**
- ✅ Both users exist with correct permissions
- ✅ Permission isolation working
- ✅ Key management working
- ✅ Infrastructure templates ready
- ✅ Lambda function implemented
- ✅ Demo services working

## 🔐 **Security Features**

Both systems include:
- **KMS Encryption**: Secret keys encrypted at rest
- **Least Privilege**: Minimal required permissions
- **TTL Cleanup**: Automatic cleanup of old keys
- **S3 Encryption**: Server-side encryption for config files
- **Public Access Blocked**: S3 buckets secured
- **Permission Isolation**: Users can only access their designated services

## 📊 **Configuration Examples**

### **Single-User Config:**
```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY_ENCRYPTED=AQICAHjcWLQLoiwsTET6mTjc4wRBECn4Ehuq1eIj7SlwX5KmCwGe+kVAS7uq/Zx+mGmk9h6zAAAAhzCBhAYJKoZIhvcNAQcGoHcwdQIBADBwBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDMVa2SnFxkw7w+PjQgIBEIBDLxPUfd0J0OSQvuhXzlBAwuk8XdstDebh9tjAHE4f5uzlG7UVe+hfgzyGzC/rIEbPT4Mq3LyapXo/G1d6OoYk4UVJUQ==
KMS_KEY_ID=7e5418a3-908e-4249-bb8c-a0f9b3b18b95
AWS_REGION=us-east-1
```

### **Multi-User Config:**
```bash
# User 1: demo-sns-service (SNS Permissions)
DEMO_SNS_SERVICE_ACCESS_KEY_ID=AKIA...
DEMO_SNS_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED=AQICAHjcWLQLoiwsTET6mTjc4wRBECn4Ehuq1eIj7SlwX5KmCwGe+kVAS7uq/Zx+mGmk9h6zAAAAhzCBhAYJKoZIhvcNAQcGoHcwdQIBADBwBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDMVa2SnFxkw7w+PjQgIBEIBDLxPUfd0J0OSQvuhXzlBAwuk8XdstDebh9tjAHE4f5uzlG7UVe+hfgzyGzC/rIEbPT4Mq3LyapXo/G1d6OoYk4UVJUQ==

# User 2: demo-s3-service (S3 Permissions)
DEMO_S3_SERVICE_ACCESS_KEY_ID=AKIA...
DEMO_S3_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED=AQICAHjcWLQLoiwsTET6mTjc4wRBECn4Ehuq1eIj7SlwX5KmCwHLpuOjqbbbvBs0kyFa0S9tAAAAhzCBhAYJKoZIhvcNAQcGoHcwdQIBADBwBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDJn+m3MRSUZkEnP1RAIBEIBDq8kdWmQWmRMfLcmJOX5CuiDY50RJNVs3jeb/OPU5HAUnqkjH2rR5ea8+md2EBjUH79aXnJ+0w0PslLi7ZajF+gB1iQ==

KMS_KEY_ID=7e5418a3-908e-4249-bb8c-a0f9b3b18b95
AWS_REGION=us-east-1
```

## 🧪 **Testing**

### **Single-User Testing:**
```bash
cd single-user
./scripts/test-rotation.sh
cd demo-service && python3 sns-publisher.py
```

### **Multi-User Testing:**
```bash
cd multi-user
./scripts/test-multi-user-simple.sh
cd demo-service && python3 multi-user-demo.py
```

## 📚 **Documentation**

- **Single-User Guide**: See `single-user/README.md`
- **Multi-User Guide**: See `multi-user/README.md`
- **Multi-User Details**: See `MULTI_USER_README.md`

## 🔗 **AWS Services Used**

- **AWS Lambda**: Key rotation logic
- **Amazon S3**: Configuration storage
- **Amazon SNS**: Notifications and messaging
- **Amazon DynamoDB**: State tracking
- **AWS IAM**: User and key management
- **AWS KMS**: Secret encryption
- **AWS CodePipeline**: Deployment automation
- **AWS CodeBuild**: Build process
- **AWS CloudFormation**: Infrastructure as Code

## 🎉 **Key Achievements**

1. **Complete Single-User System**: Fully operational with pipeline integration
2. **Multi-User Concept**: Validated and ready for deployment
3. **Security Best Practices**: KMS encryption, least privilege, TTL cleanup
4. **Automated Operations**: Lambda functions, SNS notifications, state tracking
5. **Clean Architecture**: Separate directories for different scenarios
6. **Comprehensive Testing**: Working demo services and test scripts

## 🚀 **Next Steps**

1. **Deploy Multi-User System**: Use the provided scripts to deploy the multi-user infrastructure
2. **Test Both Scenarios**: Verify both single-user and multi-user systems work correctly
3. **Customize for Production**: Adapt the systems for your specific use cases
4. **Add Monitoring**: Implement CloudWatch dashboards and alarms
5. **Scale Up**: Extend to more users or different permission sets
