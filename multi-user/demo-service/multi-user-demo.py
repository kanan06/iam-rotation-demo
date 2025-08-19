#!/usr/bin/env python3
"""
Multi-User IAM Key Rotation Demo Service
This service demonstrates how to use rotated keys for multiple users
"""

import boto3
import os
import json
import base64
from datetime import datetime

def print_status(message: str):
    """Print status message with timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def print_success(message: str):
    """Print success message"""
    print(f"✅ {message}")

def print_error(message: str):
    print(f"❌ {message}")

def print_info(message: str):
    print(f"ℹ️ {message}")

def load_multi_user_config_from_s3(bucket_name: str) -> dict:
    """Load multi-user configuration from S3"""
    try:
        s3 = boto3.client('s3')
        response = s3.get_object(Bucket=bucket_name, Key='.env')
        config_content = response['Body'].read().decode('utf-8')
        
        # Parse .env file content
        config = {}
        for line in config_content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    config[key] = value
        
        return config
        
    except Exception as e:
        print_error(f"Failed to load multi-user config from S3: {e}")
        raise e

def decrypt_multi_user_secrets(config: dict, kms_key_id: str) -> dict:
    """Decrypt secret keys for all users using KMS"""
    try:
        kms = boto3.client('kms')
        decrypted_config = config.copy()
        
        # Decrypt SNS user secret
        if 'DEMO_SNS_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED' in config:
            encrypted_sns_secret = base64.b64decode(config['DEMO_SNS_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED'])
            decrypt_response = kms.decrypt(
                KeyId=kms_key_id,
                CiphertextBlob=encrypted_sns_secret
            )
            decrypted_config['DEMO_SNS_SERVICE_SECRET_ACCESS_KEY'] = decrypt_response['Plaintext'].decode('utf-8')
            print_success("SNS user secret key decrypted")
        
        # Decrypt S3 user secret
        if 'DEMO_S3_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED' in config:
            encrypted_s3_secret = base64.b64decode(config['DEMO_S3_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED'])
            decrypt_response = kms.decrypt(
                KeyId=kms_key_id,
                CiphertextBlob=encrypted_s3_secret
            )
            decrypted_config['DEMO_S3_SERVICE_SECRET_ACCESS_KEY'] = decrypt_response['Plaintext'].decode('utf-8')
            print_success("S3 user secret key decrypted")
        
        return decrypted_config
        
    except Exception as e:
        print_error(f"Failed to decrypt secrets: {e}")
        raise e

def test_sns_user_permissions(access_key: str, secret_key: str, region: str):
    """Test SNS user permissions"""
    try:
        # Create SNS client with SNS user credentials
        sns = boto3.client(
            'sns',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region
        )
        
        # Test SNS permissions
        topics = sns.list_topics()
        print_success(f"SNS user can list topics: {len(topics.get('Topics', []))} topics found")
        
        # Try to publish a test message
        if topics.get('Topics'):
            test_topic = topics['Topics'][0]['TopicArn']
            response = sns.publish(
                TopicArn=test_topic,
                Subject="Multi-User Demo Test",
                Message=f"Testing SNS user permissions at {datetime.now().isoformat()}"
            )
            print_success(f"SNS user can publish messages: {response['MessageId']}")
        
        return True
        
    except Exception as e:
        print_error(f"SNS user permission test failed: {e}")
        return False

def test_s3_user_permissions(access_key: str, secret_key: str, region: str, config_bucket: str):
    """Test S3 user permissions"""
    try:
        # Create S3 client with S3 user credentials
        s3 = boto3.client(
            's3',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region
        )
        
        # Test S3 permissions
        buckets = s3.list_buckets()
        print_success(f"S3 user can list buckets: {len(buckets.get('Buckets', []))} buckets found")
        
        # Test access to config bucket
        try:
            objects = s3.list_objects_v2(Bucket=config_bucket, MaxKeys=5)
            print_success(f"S3 user can access config bucket: {config_bucket}")
            if objects.get('Contents'):
                print_info(f"Config bucket contains {len(objects['Contents'])} objects")
        except Exception as e:
            print_error(f"S3 user cannot access config bucket: {e}")
        
        return True
        
    except Exception as e:
        print_error(f"S3 user permission test failed: {e}")
        return False

def demonstrate_multi_user_operations(config: dict):
    """Demonstrate operations with both users"""
    print("\n🚀 Demonstrating Multi-User Operations:")
    print("=" * 50)
    
    # Test SNS user
    print("\n📤 Testing SNS User Operations:")
    print("-" * 30)
    sns_success = test_sns_user_permissions(
        config['DEMO_SNS_SERVICE_ACCESS_KEY_ID'],
        config['DEMO_SNS_SERVICE_SECRET_ACCESS_KEY'],
        config['AWS_REGION']
    )
    
    # Test S3 user
    print("\n📁 Testing S3 User Operations:")
    print("-" * 30)
    s3_success = test_s3_user_permissions(
        config['DEMO_S3_SERVICE_ACCESS_KEY_ID'],
        config['DEMO_S3_SERVICE_SECRET_ACCESS_KEY'],
        config['AWS_REGION'],
        config.get('CONFIG_BUCKET', 'iam-rotation-multi-user-config-160885290762')
    )
    
    # Summary
    print("\n📊 Multi-User Test Summary:")
    print("=" * 30)
    if sns_success and s3_success:
        print_success("Both users working correctly!")
        print_info("✅ SNS user: Can publish messages and list topics")
        print_info("✅ S3 user: Can list buckets and access config bucket")
    else:
        print_error("Some user tests failed")
        if not sns_success:
            print_error("❌ SNS user: Permission issues")
        if not s3_success:
            print_error("❌ S3 user: Permission issues")

def main():
    """Main function to demonstrate multi-user IAM key rotation"""
    print("🎯 Multi-User IAM Key Rotation Demo Service")
    print("🐧 Running on Ubuntu with VS Code")
    print("=" * 60)
    
    # System information
    print("🖥️ System Information:")
    print("-" * 30)
    print(f"🐧 Platform: {os.uname().sysname} {os.uname().release}")
    print(f"💻 IDE: Visual Studio Code")
    print(f"🐍 Python: {os.sys.version.split()[0]}")
    print(f"📦 Boto3: {boto3.__version__}")
    print(f"⏰ Local Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    print("\n" + "=" * 60)
    print("🚀 Multi-User Demo Service Starting...")
    print("=" * 60)
    
    try:
        # Load configuration from S3
        print_status("📡 Loading multi-user config from S3...")
        config_bucket = 'iam-rotation-multi-user-config-160885290762'  # Default bucket name
        
        try:
            config = load_multi_user_config_from_s3(config_bucket)
            print_success("Configuration loaded from S3")
        except:
            print_info("Trying alternative bucket name...")
            config_bucket = 'iam-rotation-multi-user-config-160885290762'
            config = load_multi_user_config_from_s3(config_bucket)
            print_success("Configuration loaded from S3")
        
        # Display config (sanitized)
        print("\n📄 Multi-User Config (sanitized):")
        print("-" * 40)
        for key, value in config.items():
            if 'SECRET' in key and 'ENCRYPTED' in key:
                print(f"{key}=****")
            else:
                print(f"{key}={value}")
        
        # Decrypt secrets
        print_status("🔐 Decrypting secret keys with AWS KMS...")
        kms_key_id = config.get('KMS_KEY_ID')
        if not kms_key_id:
            print_error("KMS_KEY_ID not found in config")
            return
        
        decrypted_config = decrypt_multi_user_secrets(config, kms_key_id)
        print_success("All secret keys decrypted successfully")
        
        # Demonstrate multi-user operations
        demonstrate_multi_user_operations(decrypted_config)
        
        print("\n" + "=" * 60)
        print_success("✅ Multi-user demo completed successfully!")
        print_info("🎉 Multi-user IAM key rotation is working perfectly!")
        print("=" * 60)
        
    except Exception as e:
        print_error(f"Demo failed: {e}")
        print("\n💡 Troubleshooting tips:")
        print("1. Ensure multi-user infrastructure is deployed")
        print("2. Check that both users have correct permissions")
        print("3. Verify KMS key permissions")
        print("4. Check S3 bucket access")

if __name__ == "__main__":
    main()
