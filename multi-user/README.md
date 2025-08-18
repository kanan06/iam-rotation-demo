# Multi-User IAM Key Rotation Demo

This directory contains the **Multi-User IAM Key Rotation** implementation - a system for rotating IAM keys for multiple users simultaneously with different permissions.

## 🎯 **Overview**

The multi-user system demonstrates:
- ✅ **Simultaneous Key Rotation** for multiple users
- ✅ **Permission Isolation** between different users
- ✅ **KMS Encryption** for secure secret storage
- ✅ **Multi-User Configuration** management
- ✅ **DynamoDB State Tracking** per user
- ✅ **SNS Notifications** for rotation events
- ✅ **Demo Services** for different user types

## 📁 **Project Structure**

```
multi-user/
├── lambda/
│   └── multi-user-lambda.py         # Multi-user rotation logic
├── cloudformation/
│   └── multi-user-simple.yaml       # Multi-user infrastructure
├── scripts/
│   ├── deploy-multi-user-simple.sh  # Deploy infrastructure
│   ├── deploy-multi-user-lambda.sh  # Deploy Lambda function
│   └── test-multi-user-simple.sh    # Test rotation
├── demo-service/
│   ├── multi-user-demo.py           # Multi-user demo service
│   └── test-multi-user-working.py   # Working concept test
└── README.md                        # This file
```

## 🚀 **Quick Start**

### **1. Deploy Infrastructure**
```bash
cd multi-user
./scripts/deploy-multi-user-simple.sh
```

### **2. Deploy Lambda Function**
```bash
./scripts/deploy-multi-user-lambda.sh
```

### **3. Test Multi-User Rotation**
```bash
./scripts/test-multi-user-simple.sh
```

### **4. Run Multi-User Demo**
```bash
cd demo-service
python3 multi-user-demo.py
```

### **5. Test Working Concept**
```bash
python3 test-multi-user-working.py
```

## 🔧 **Architecture**

### **Users and Permissions:**
- **`demo-sns-service`**: SNS permissions (publish, list topics)
- **`demo-s3-service`**: S3 permissions (list buckets, access config bucket)

### **Components:**
- **IAM Users**: Two separate users with different permissions
- **Lambda Function**: `iam-rotation-multi-user-demo` for rotation logic
- **S3 Bucket**: Stores multi-user configuration files
- **DynamoDB Table**: Tracks rotation state per user with TTL
- **KMS Key**: Encrypts secret keys for all users
- **SNS Topics**: Notifications and demo messaging

### **Security Features:**
- 🔐 **KMS Encryption**: Secret keys encrypted at rest
- 🛡️ **Permission Isolation**: Each user has only necessary permissions
- 🗑️ **TTL Cleanup**: Automatic cleanup of old keys
- 🔒 **S3 Encryption**: Server-side encryption for config files
- 🚫 **Public Access Blocked**: S3 buckets secured

## 📊 **Configuration**

The system generates a multi-user `.env` file in S3 containing:
```bash
# User 1: demo-sns-service (SNS Permissions)
DEMO_SNS_SERVICE_ACCESS_KEY_ID=AKIA...
DEMO_SNS_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED=AQICAHjcWLQLoiwsTET6mTjc4wRBECn4Ehuq1eIj7SlwX5KmCwGe+kVAS7uq/Zx+mGmk9h6zAAAAhzCBhAYJKoZIhvcNAQcGoHcwdQIBADBwBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDMVa2SnFxkw7w+PjQgIBEIBDLxPUfd0J0OSQvuhXzlBAwuk8XdstDebh9tjAHE4f5uzlG7UVe+hfgzyGzC/rIEbPT4Mq3LyapXo/G1d6OoYk4UVJUQ==

# User 2: demo-s3-service (S3 Permissions)
DEMO_S3_SERVICE_ACCESS_KEY_ID=AKIA...
DEMO_S3_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED=AQICAHjcWLQLoiwsTET6mTjc4wRBECn4Ehuq1eIj7SlwX5KmCwHLpuOjqbbbvBs0kyFa0S9tAAAAhzCBhAYJKoZIhvcNAQcGoHcwdQIBADBwBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDJn+m3MRSUZkEnP1RAIBEIBDq8kdWmQWmRMfLcmJOX5CuiDY50RJNVs3jeb/OPU5HAUnqkjH2rR5ea8+md2EBjUH79aXnJ+0w0PslLi7ZajF+gB1iQ==

# KMS Configuration
KMS_KEY_ID=7e5418a3-908e-4249-bb8c-a0f9b3b18b95
AWS_REGION=us-east-1
```

## 🔄 **How It Works**

### **Simple Approach (All Users Simultaneously):**

1. **Key Rotation Phase:**
   ```
   For each user (demo-sns-service, demo-s3-service):
   - Check current active keys
   - Deactivate oldest key if limit reached
   - Create new access key
   - Store in DynamoDB with TTL
   ```

2. **Configuration Update Phase:**
   ```
   - Retrieve all user keys from DynamoDB
   - Encrypt secret keys using KMS
   - Generate multi-user .env file
   - Upload to S3 bucket
   ```

3. **Notification Phase:**
   ```
   - Send success/failure notifications via SNS
   - Include rotation results for all users
   ```

## 🧪 **Testing**

### **Test Multi-User Rotation:**
```bash
./scripts/test-multi-user-simple.sh
```

### **Test Multi-User Demo:**
```bash
cd demo-service
python3 multi-user-demo.py
```

### **Test Working Concept:**
```bash
python3 test-multi-user-working.py
```

### **Check Status:**
```bash
# Check IAM keys for both users
aws iam list-access-keys --user-name demo-sns-service
aws iam list-access-keys --user-name demo-s3-service

# Check DynamoDB state
aws dynamodb get-item --table-name iam-rotation-multi-user-state --key '{"UserId": {"S": "demo-sns-service"}}'
aws dynamodb get-item --table-name iam-rotation-multi-user-state --key '{"UserId": {"S": "demo-s3-service"}}'

# Check S3 config
aws s3 cp s3://iam-rotation-multi-user-config-160885290762/.env -
```

## 🎯 **Status: CONCEPT VALIDATED**

✅ **Users**: Both users exist with correct permissions  
✅ **Permission Isolation**: SNS user can access SNS, S3 user can access S3  
✅ **Key Management**: Each user has proper access keys  
✅ **Infrastructure**: CloudFormation templates and scripts ready  
✅ **Lambda Function**: Multi-user rotation logic implemented  
✅ **Demo Services**: Working with existing infrastructure  

## 🔗 **Related**

- **Single-User Scenario**: See `../single-user/` directory
- **Main Documentation**: See `../README.md`
- **Multi-User Documentation**: See `../MULTI_USER_README.md`
