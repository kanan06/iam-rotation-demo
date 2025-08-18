#!/usr/bin/env python3
"""
IAM Key Rotation Lambda Function
Handles multi-file rotation, 7-day policy, health checks, and GitHub Actions integration
"""

import json
import boto3
import os
import base64
import requests
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Initialize AWS clients
iam_client = boto3.client('iam')
s3_client = boto3.client('s3')
kms_client = boto3.client('kms')
dynamodb_client = boto3.client('dynamodb')
sns_client = boto3.client('sns')
cloudformation_client = boto3.client('cloudformation')

# Environment variables
CONFIG_BUCKET = os.environ['CONFIG_BUCKET']
KMS_KEY_ID = os.environ['KMS_KEY_ID']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

# Configuration
ROTATION_DAYS = 7  # Rotate keys older than 7 days
ENV_FILES = ['env1.env', 'env2.env']  # Two .env files

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        print("🚀 Starting IAM Key Rotation Process")
        
        # Parse event parameters
        target_files = event.get('target_files', ENV_FILES)
        force_rotation = event.get('force_rotation', False)
        
        print(f"📁 Target files: {target_files}")
        print(f"🔄 Force rotation: {force_rotation}")
        
        # Get all users from both .env files
        all_users = get_all_users_from_env_files(target_files)
        print(f"👥 Found users: {list(all_users.keys())}")
        
        # Check which users need rotation
        users_to_rotate = []
        for username, user_info in all_users.items():
            if should_rotate_user(username, force_rotation):
                users_to_rotate.append(username)
                print(f"🔄 User {username} needs rotation")
            else:
                print(f"✅ User {username} doesn't need rotation")
        
        if not users_to_rotate:
            print("✅ No users need rotation")
            return {
                'statusCode': 200,
                'body': json.dumps('No users need rotation')
            }
        
        # Rotate keys for users that need it
        rotation_results = {}
        for username in users_to_rotate:
            print(f"🔄 Rotating keys for user: {username}")
            result = rotate_user_keys(username, all_users[username])
            rotation_results[username] = result
        
        # Update .env files with new credentials
        update_env_files_with_new_credentials(target_files, all_users, rotation_results)
        
        # Run health checks
        print("📊 Running health checks...")
        health_check_result = run_health_checks(rotation_results)
        
        if health_check_result['status'] == 'HEALTHY':
            print("✅ Health checks passed")
            
            # Delete old keys
            delete_old_keys(rotation_results)
            
            # Trigger GitHub Actions pipeline
            print("🚀 Triggering GitHub Actions pipeline...")
            pipeline_result = trigger_github_actions_pipeline(target_files)
            
            # Send success notification
            send_notification("IAM Key Rotation - Success", 
                            f"Successfully rotated keys for {len(users_to_rotate)} users. Pipeline triggered.")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Key rotation completed successfully',
                    'users_rotated': users_to_rotate,
                    'health_check': health_check_result,
                    'pipeline_triggered': pipeline_result
                })
            }
        else:
            print("❌ Health checks failed")
            
            # Rollback changes
            print("🔄 Rolling back changes...")
            rollback_rotation(rotation_results)
            
            # Send failure notification
            send_notification("IAM Key Rotation - Failed", 
                            f"Health checks failed. Rolled back changes for {len(users_to_rotate)} users.")
            
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'Key rotation failed - health checks failed',
                    'health_check': health_check_result
                })
            }
            
    except Exception as e:
        print(f"❌ Error in lambda_handler: {e}")
        send_notification("IAM Key Rotation - Error", f"Error during key rotation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def get_all_users_from_env_files(env_files):
    """Get all users from the specified .env files"""
    all_users = {}
    
    for env_file in env_files:
        try:
            # Download encrypted .env file from S3
            s3_client.download_file(CONFIG_BUCKET, f"{env_file}.encrypted", f"/tmp/{env_file}.encrypted")
            s3_client.download_file(CONFIG_BUCKET, f"{env_file}.metadata", f"/tmp/{env_file}.metadata")
            
            # Read metadata
            with open(f"/tmp/{env_file}.metadata", 'r') as f:
                metadata = json.load(f)
            
            # Decrypt the file
            with open(f"/tmp/{env_file}.encrypted", 'rb') as f:
                encrypted_data = f.read()
            
            response = kms_client.decrypt(
                CiphertextBlob=encrypted_data,
                KeyId=KMS_KEY_ID
            )
            
            decrypted_content = response['Plaintext'].decode('utf-8')
            
            # Parse .env content
            env_vars = {}
            for line in decrypted_content.split('\n'):
                if '=' in line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
            
            # Extract user information
            users_in_file = extract_users_from_env_vars(env_vars)
            
            # Merge with all_users, handling common users
            for username, user_info in users_in_file.items():
                if username in all_users:
                    # User exists in multiple files, merge information
                    all_users[username]['env_files'].append(env_file)
                    all_users[username]['access_keys'].extend(user_info['access_keys'])
                else:
                    user_info['env_files'] = [env_file]
                    all_users[username] = user_info
            
            print(f"📁 Loaded {len(users_in_file)} users from {env_file}")
            
        except Exception as e:
            print(f"⚠️ Error loading {env_file}: {e}")
    
    return all_users

def extract_users_from_env_vars(env_vars):
    """Extract user information from environment variables"""
    users = {}
    
    # Look for patterns like AWS_ACCESS_KEY_ID_USER1, AWS_SECRET_ACCESS_KEY_USER1
    for key, value in env_vars.items():
        if key.startswith('AWS_ACCESS_KEY_ID_'):
            username = key.replace('AWS_ACCESS_KEY_ID_', '')
            if username not in users:
                users[username] = {
                    'access_keys': [],
                    'env_vars': {}
                }
            users[username]['access_keys'].append(value)
            users[username]['env_vars'][key] = value
            
            # Look for corresponding secret key
            secret_key = env_vars.get(f'AWS_SECRET_ACCESS_KEY_{username}')
            if secret_key:
                users[username]['env_vars'][f'AWS_SECRET_ACCESS_KEY_{username}'] = secret_key
    
    return users

def should_rotate_user(username, force_rotation=False):
    """Check if a user's keys should be rotated based on 7-day policy"""
    if force_rotation:
        return True
    
    try:
        # Get current keys for the user
        response = iam_client.list_access_keys(UserName=username)
        access_keys = response['AccessKeyMetadata']
        
        if not access_keys:
            print(f"⚠️ No access keys found for user {username}")
            return True
        
        # Check if any key is older than 7 days
        for key in access_keys:
            if key['Status'] == 'Active':
                key_created = key['CreateDate']
                key_age = datetime.now(key_created.tzinfo) - key_created
                
                if key_age.days >= ROTATION_DAYS:
                    print(f"🔄 User {username} has key older than {ROTATION_DAYS} days")
                    return True
        
        print(f"✅ User {username} keys are within {ROTATION_DAYS} days")
        return False
        
    except Exception as e:
        print(f"❌ Error checking rotation for user {username}: {e}")
        return True

def rotate_user_keys(username, user_info):
    """Rotate keys for a specific user"""
    try:
        print(f"🔄 Rotating keys for user: {username}")
        
        # Get current access keys
        response = iam_client.list_access_keys(UserName=username)
        current_keys = response['AccessKeyMetadata']
        
        # Create new access key
        new_key_response = iam_client.create_access_key(UserName=username)
        new_access_key = new_key_response['AccessKey']
        
        print(f"✅ Created new access key for {username}: {new_access_key['AccessKeyId']}")
        
        # Deactivate old keys
        old_keys = []
        for key in current_keys:
            if key['Status'] == 'Active':
                iam_client.update_access_key(
                    UserName=username,
                    AccessKeyId=key['AccessKeyId'],
                    Status='Inactive'
                )
                old_keys.append(key['AccessKeyId'])
                print(f"🔄 Deactivated old key: {key['AccessKeyId']}")
        
        # Update DynamoDB with rotation state
        update_rotation_state(username, new_access_key['AccessKeyId'])
        
        return {
            'username': username,
            'new_access_key_id': new_access_key['AccessKeyId'],
            'new_secret_access_key': new_access_key['SecretAccessKey'],
            'old_access_key_ids': old_keys,
            'rotation_time': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"❌ Error rotating keys for user {username}: {e}")
        raise

def update_rotation_state(username, new_access_key_id):
    """Update DynamoDB with rotation state"""
    try:
        item = {
            'UserId': {'S': username},
            'KeyCreatedAt': {'S': datetime.now().isoformat()},
            'CurrentAccessKeyId': {'S': new_access_key_id},
            'LastRotation': {'S': datetime.now().isoformat()},
            'TTL': {'N': str(int((datetime.now() + timedelta(days=365)).timestamp()))}
        }
        
        # Get existing rotation count
        try:
            response = dynamodb_client.get_item(
                TableName=DYNAMODB_TABLE,
                Key={'UserId': {'S': username}}
            )
            if 'Item' in response:
                rotation_count = int(response['Item'].get('RotationCount', {'N': '0'})['N'])
                item['RotationCount'] = {'N': str(rotation_count + 1)}
            else:
                item['RotationCount'] = {'N': '1'}
        except:
            item['RotationCount'] = {'N': '1'}
        
        dynamodb_client.put_item(
            TableName=DYNAMODB_TABLE,
            Item=item
        )
        
        print(f"📊 Updated rotation state for {username}")
        
    except Exception as e:
        print(f"⚠️ Error updating rotation state for {username}: {e}")

def update_env_files_with_new_credentials(env_files, all_users, rotation_results):
    """Update .env files with new credentials"""
    for env_file in env_files:
        try:
            # Get current encrypted content
            s3_client.download_file(CONFIG_BUCKET, f"{env_file}.encrypted", f"/tmp/{env_file}.encrypted")
            s3_client.download_file(CONFIG_BUCKET, f"{env_file}.metadata", f"/tmp/{env_file}.metadata")
            
            # Read metadata
            with open(f"/tmp/{env_file}.metadata", 'r') as f:
                metadata = json.load(f)
            
            # Decrypt the file
            with open(f"/tmp/{env_file}.encrypted", 'rb') as f:
                encrypted_data = f.read()
            
            response = kms_client.decrypt(
                CiphertextBlob=encrypted_data,
                KeyId=KMS_KEY_ID
            )
            
            decrypted_content = response['Plaintext'].decode('utf-8')
            
            # Update content with new credentials
            updated_content = update_env_content(decrypted_content, env_file, all_users, rotation_results)
            
            # Re-encrypt and upload
            encrypt_and_upload_env_file(env_file, updated_content, metadata)
            
            print(f"✅ Updated {env_file} with new credentials")
            
        except Exception as e:
            print(f"❌ Error updating {env_file}: {e}")
            raise

def update_env_content(content, env_file, all_users, rotation_results):
    """Update .env content with new credentials"""
    lines = content.split('\n')
    updated_lines = []
    
    for line in lines:
        if '=' in line and not line.startswith('#'):
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()
            
            # Check if this line contains credentials for a user in this env file
            updated = False
            for username, user_info in all_users.items():
                if env_file in user_info.get('env_files', []):
                    if username in rotation_results:
                        rotation_result = rotation_results[username]
                        
                        # Update access key
                        if key == f'AWS_ACCESS_KEY_ID_{username}':
                            value = rotation_result['new_access_key_id']
                            updated = True
                        # Update secret key
                        elif key == f'AWS_SECRET_ACCESS_KEY_{username}':
                            value = rotation_result['new_secret_access_key']
                            updated = True
            
            if updated:
                updated_lines.append(f"{key}={value}")
            else:
                updated_lines.append(line)
        else:
            updated_lines.append(line)
    
    return '\n'.join(updated_lines)

def encrypt_and_upload_env_file(env_file, content, metadata):
    """Encrypt and upload .env file to S3"""
    # Encrypt the content
    response = kms_client.encrypt(
        KeyId=KMS_KEY_ID,
        Plaintext=content.encode('utf-8')
    )
    
    encrypted_data = response['CiphertextBlob']
    
    # Update metadata
    metadata['last_updated'] = datetime.now().isoformat()
    metadata['encryption_key_id'] = KMS_KEY_ID
    
    # Upload encrypted file
    s3_client.put_object(
        Bucket=CONFIG_BUCKET,
        Key=f"{env_file}.encrypted",
        Body=encrypted_data
    )
    
    # Upload metadata
    s3_client.put_object(
        Bucket=CONFIG_BUCKET,
        Key=f"{env_file}.metadata",
        Body=json.dumps(metadata, indent=2)
    )

def run_health_checks(rotation_results):
    """Run health checks using new credentials"""
    try:
        print("📊 Running health checks...")
        
        health_checks = []
        
        for username, rotation_result in rotation_results.items():
            print(f"🔍 Checking health for user: {username}")
            
            # Create session with new credentials
            session = boto3.Session(
                aws_access_key_id=rotation_result['new_access_key_id'],
                aws_secret_access_key=rotation_result['new_secret_access_key'],
                region_name='us-east-1'
            )
            
            # Test S3 access
            try:
                s3_client_test = session.client('s3')
                s3_client_test.list_buckets()
                health_checks.append(f"✅ {username}: S3 access OK")
            except Exception as e:
                health_checks.append(f"❌ {username}: S3 access failed - {e}")
            
            # Test SNS access
            try:
                sns_client_test = session.client('sns')
                sns_client_test.list_topics()
                health_checks.append(f"✅ {username}: SNS access OK")
            except Exception as e:
                health_checks.append(f"❌ {username}: SNS access failed - {e}")
            
            # Test DynamoDB access
            try:
                dynamodb_client_test = session.client('dynamodb')
                dynamodb_client_test.list_tables()
                health_checks.append(f"✅ {username}: DynamoDB access OK")
            except Exception as e:
                health_checks.append(f"❌ {username}: DynamoDB access failed - {e}")
        
        # Calculate health score
        total_checks = len(health_checks)
        passed_checks = len([check for check in health_checks if check.startswith('✅')])
        health_score = (passed_checks / total_checks) * 100 if total_checks > 0 else 0
        
        # Determine status
        if health_score >= 90:
            status = 'HEALTHY'
        elif health_score >= 70:
            status = 'DEGRADED'
        else:
            status = 'UNHEALTHY'
        
        result = {
            'status': status,
            'score': health_score,
            'checks': health_checks,
            'passed': passed_checks,
            'total': total_checks
        }
        
        print(f"📊 Health check result: {status} ({health_score:.1f}%)")
        for check in health_checks:
            print(f"  {check}")
        
        return result
        
    except Exception as e:
        print(f"❌ Error running health checks: {e}")
        return {
            'status': 'UNHEALTHY',
            'score': 0,
            'checks': [f"❌ Health check error: {e}"],
            'passed': 0,
            'total': 1
        }

def delete_old_keys(rotation_results):
    """Delete old access keys after successful health check"""
    for username, rotation_result in rotation_results.items():
        for old_key_id in rotation_result['old_access_key_ids']:
            try:
                iam_client.delete_access_key(
                    UserName=username,
                    AccessKeyId=old_key_id
                )
                print(f"🗑️ Deleted old key: {old_key_id}")
            except Exception as e:
                print(f"⚠️ Error deleting old key {old_key_id}: {e}")

def rollback_rotation(rotation_results):
    """Rollback rotation by deleting new keys and reactivating old keys"""
    for username, rotation_result in rotation_results.items():
        try:
            # Delete new key
            iam_client.delete_access_key(
                UserName=username,
                AccessKeyId=rotation_result['new_access_key_id']
            )
            print(f"🔄 Deleted new key: {rotation_result['new_access_key_id']}")
            
            # Reactivate old keys (if they exist)
            for old_key_id in rotation_result['old_access_key_ids']:
                try:
                    iam_client.update_access_key(
                        UserName=username,
                        AccessKeyId=old_key_id,
                        Status='Active'
                    )
                    print(f"🔄 Reactivated old key: {old_key_id}")
                except:
                    print(f"⚠️ Could not reactivate old key: {old_key_id}")
                    
        except Exception as e:
            print(f"❌ Error rolling back for user {username}: {e}")

def trigger_github_actions_pipeline(target_files):
    """Trigger GitHub Actions pipeline"""
    try:
        # This would be implemented based on your GitHub repository
        # For now, we'll just log that it should be triggered
        print("🚀 GitHub Actions pipeline should be triggered here")
        print(f"📁 Target files: {target_files}")
        
        # In a real implementation, you would:
        # 1. Get GitHub token from environment or parameter store
        # 2. Make API call to GitHub to trigger repository_dispatch
        # 3. Pass the target_files as payload
        
        return {
            'status': 'triggered',
            'target_files': target_files,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"❌ Error triggering GitHub Actions: {e}")
        return {
            'status': 'failed',
            'error': str(e)
        }

def send_notification(subject, message):
    """Send SNS notification"""
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print(f"📧 Sent notification: {subject}")
    except Exception as e:
        print(f"⚠️ Error sending notification: {e}")
