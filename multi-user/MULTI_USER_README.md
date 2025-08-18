# 🔐 Multi-User IAM Key Rotation Demo

## 🎯 **Use Case: Multiple IAM Users with Different Permissions**

This demo shows how to handle IAM key rotation when you have **multiple IAM users** in the same application, each with **different permissions**. This is a common real-world scenario where:

- **User 1**: `demo-sns-service` - Has SNS permissions for sending notifications
- **User 2**: `demo-s3-service` - Has S3 permissions for file operations

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    Multi-User Application                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   SNS Service   │    │   S3 Service    │                │
│  │ (demo-sns-      │    │ (demo-s3-       │                │
│  │  service)       │    │  service)       │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           └───────────────────────┼────────────────────────┘
│                                   │
└───────────────────────────────────┼─────────────────────────┘
                                    │
┌───────────────────────────────────┼─────────────────────────┐
│              AWS Lambda           │                         │
│      (Multi-User Rotation)        │                         │
│                                   │                         │
│  ┌─────────────────────────────┐  │                         │
│  │ 1. Check current state      │  │                         │
│  │ 2. Create new keys          │  │                         │
│  │ 3. Test new keys            │  │                         │
│  │ 4. Update config file       │  │                         │
│  │ 5. Trigger pipeline         │  │                         │
│  └─────────────────────────────┘  │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
┌───────────────────────────────────┼─────────────────────────┐
│              S3 Config            │                         │
│  ┌─────────────────────────────┐  │                         │
│  │ DEMO_SNS_SERVICE_ACCESS_    │  │                         │
│  │ KEY_ID=AKIA...              │  │                         │
│  │ DEMO_SNS_SERVICE_SECRET_    │  │                         │
│  │ ACCESS_KEY_ENCRYPTED=...    │  │                         │
│  │                             │  │                         │
│  │ DEMO_S3_SERVICE_ACCESS_     │  │                         │
│  │ KEY_ID=AKIA...              │  │                         │
│  │ DEMO_S3_SERVICE_SECRET_     │  │                         │
│  │ ACCESS_KEY_ENCRYPTED=...    │  │                         │
│  └─────────────────────────────┘  │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
┌───────────────────────────────────┼─────────────────────────┐
│            KMS Encryption         │                         │
│  ┌─────────────────────────────┐  │                         │
│  │ 🔐 Encrypts all secret keys │  │                         │
│  │ 🔓 Decrypts on demand       │  │                         │
│  │ 🛡️ Secure key storage       │  │                         │
│  └─────────────────────────────┘  │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
┌───────────────────────────────────┼─────────────────────────┐
│         DynamoDB State            │                         │
│  ┌─────────────────────────────┐  │                         │
│  │ User: demo-sns-service      │  │                         │
│  │ Status: ACTIVE              │  │                         │
│  │ CurrentKey: AKIA...         │  │                         │
│  │                             │  │                         │
│  │ User: demo-s3-service       │  │                         │
│  │ Status: ACTIVE              │  │                         │
│  │ CurrentKey: AKIA...         │  │                         │
│  └─────────────────────────────┘  │                         │
└───────────────────────────────────┴─────────────────────────┘
```

## 🔧 **Key Features**

### **1. Multi-User Support**
- **Individual Rotation**: Rotate keys for specific users
- **Bulk Rotation**: Rotate keys for all users at once
- **State Tracking**: Track rotation state per user in DynamoDB

### **2. Permission Validation**
- **User-Specific Testing**: Test each user's permissions after rotation
- **Service Validation**: Verify SNS/S3 permissions work correctly
- **Identity Verification**: Ensure keys belong to correct users

### **3. Secure Configuration**
- **KMS Encryption**: All secret keys encrypted with AWS KMS
- **User-Specific Variables**: Separate environment variables per user
- **Permission Isolation**: Each user has only necessary permissions

## 📋 **Configuration Structure**

The `.env` file contains separate sections for each user:

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

## 🚀 **Quick Start**

### **1. Deploy Multi-User Infrastructure**
```bash
./scripts/deploy-multi-user-infrastructure.sh
```

### **2. Test Individual User Rotation**
```bash
# Rotate keys for SNS service user
aws lambda invoke \
    --function-name iam-multi-user-rotation-demo \
    --payload '{"target_user": "demo-sns-service"}' \
    response.json \
    --region us-east-1

# Rotate keys for S3 service user
aws lambda invoke \
    --function-name iam-multi-user-rotation-demo \
    --payload '{"target_user": "demo-s3-service"}' \
    response.json \
    --region us-east-1
```

### **3. Test Bulk Rotation**
```bash
# Rotate keys for all users
aws lambda invoke \
    --function-name iam-multi-user-rotation-demo \
    --payload '{"target_user": "all"}' \
    response.json \
    --region us-east-1
```

### **4. Run Multi-User Demo**
```bash
cd demo-service
python3 multi-user-demo.py
```

## 🧪 **Testing Scenarios**

### **Scenario 1: Individual User Rotation**
```bash
./scripts/test-multi-user-rotation.sh
```

This tests:
- ✅ Rotation for `demo-sns-service` only
- ✅ Rotation for `demo-s3-service` only
- ✅ Permission validation for each user
- ✅ Config file updates

### **Scenario 2: Bulk Rotation**
```bash
aws lambda invoke \
    --function-name iam-multi-user-rotation-demo \
    --payload '{"target_user": "all"}' \
    response.json \
    --region us-east-1
```

This tests:
- ✅ Simultaneous rotation of both users
- ✅ Atomic operation (all succeed or all fail)
- ✅ Pipeline triggering after successful rotation
- ✅ Comprehensive state updates

### **Scenario 3: Permission Validation**
```bash
cd demo-service
python3 multi-user-demo.py
```

This tests:
- ✅ SNS permissions for `demo-sns-service`
- ✅ S3 permissions for `demo-s3-service`
- ✅ KMS decryption for both users
- ✅ Real API calls with rotated keys

## 🔍 **How Key Rotation Works**

### **1. Individual User Rotation**
```python
# Rotate specific user
result = rotate_user_keys(manager, "demo-sns-service")
```

**Process:**
1. Check current state for the user
2. Create new access key
3. Test new key with user-specific permissions
4. Deactivate old key
5. Update DynamoDB state
6. Update config file with new keys

### **2. Bulk Rotation**
```python
# Rotate all users
for user_name in [manager.demo_user_1, manager.demo_user_2]:
    result = rotate_user_keys(manager, user_name)
```

**Process:**
1. Rotate keys for all users
2. Validate all rotations succeeded
3. Update multi-user config file
4. Trigger deployment pipeline
5. Send success notification

### **3. Permission Validation**
```python
# Test SNS permissions
if 'sns' in user_name.lower():
    sns_client = session.client('sns')
    topics = sns_client.list_topics()

# Test S3 permissions  
elif 's3' in user_name.lower():
    s3_client = session.client('s3')
    buckets = s3_client.list_buckets()
```

## 🛡️ **Security Features**

### **1. Permission Isolation**
- Each user has only necessary permissions
- SNS user can't access S3
- S3 user can't access SNS
- KMS decryption permissions for both

### **2. Key Validation**
- Verify key belongs to correct user
- Test actual API permissions
- Retry mechanism for eventual consistency
- Rollback on validation failure

### **3. Secure Storage**
- All secret keys encrypted with KMS
- Separate encrypted values per user
- TTL cleanup in DynamoDB
- No plaintext secrets in logs

## 📊 **Monitoring & Troubleshooting**

### **Check Rotation State**
```bash
# Check DynamoDB state
aws dynamodb get-item \
    --table-name iam-rotation-multi-user-state \
    --key '{"UserId": {"S": "demo-sns-service"}}' \
    --output table
```

### **Check Current Keys**
```bash
# List current keys for each user
aws iam list-access-keys --user-name demo-sns-service
aws iam list-access-keys --user-name demo-s3-service
```

### **Check S3 Config**
```bash
# View current config
aws s3 cp s3://iam-rotation-multi-user-config-ACCOUNT/.env -
```

### **Lambda Logs**
```bash
# Check Lambda execution logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/iam-multi-user-rotation-demo"
```

##  **Real-World Use Cases**

### **1. Microservices Architecture**
```
Service A (User Management) → IAM User A (DynamoDB permissions)
Service B (File Processing) → IAM User B (S3 permissions)  
Service C (Notifications) → IAM User C (SNS permissions)
```

### **2. Multi-Tenant Applications**
```
Tenant 1 → IAM User 1 (Tenant-specific S3 bucket)
Tenant 2 → IAM User 2 (Tenant-specific S3 bucket)
Tenant 3 → IAM User 3 (Tenant-specific S3 bucket)
```

### **3. CI/CD Pipelines**
```
Build Stage → IAM User A (CodeBuild permissions)
Deploy Stage → IAM User B (ECS/EC2 permissions)
Notification Stage → IAM User C (SNS permissions)
```

## 🔧 **Customization**

### **Add More Users**
1. Update CloudFormation template
2. Add new IAM user with specific permissions
3. Update Lambda environment variables
4. Modify config file structure

### **Change Permissions**
1. Update IAM policies in CloudFormation
2. Modify permission validation logic
3. Update demo service tests

### **Add New Services**
1. Create new IAM user for the service
2. Add service-specific validation
3. Update multi-user demo service

## 🧹 **Cleanup**

```bash
# Delete the multi-user stack
aws cloudformation delete-stack --stack-name iam-rotation-multi-user-demo

# Wait for cleanup
aws cloudformation wait stack-delete-complete --stack-name iam-rotation-multi-user-demo
```

## 📚 **Key Takeaways**

1. **Multi-User Support**: Handle multiple IAM users with different permissions
2. **Permission Validation**: Test each user's specific permissions after rotation
3. **Atomic Operations**: Ensure all users rotate successfully or none do
4. **Secure Storage**: Encrypt all secret keys with KMS
5. **State Tracking**: Track rotation state per user in DynamoDB
6. **Pipeline Integration**: Trigger deployments after successful rotation

This multi-user approach ensures that each service has the minimum required permissions while maintaining secure key rotation across all users in your application.
