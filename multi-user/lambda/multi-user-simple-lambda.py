#!/usr/bin/env python3
"""
Multi-User IAM Key Rotation Lambda Function (Simple Approach)
Works with existing infrastructure - rotates all users simultaneously
"""

import boto3
import os
import json
import base64
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """Multi-user IAM key rotation handler - rotates all users simultaneously"""
    try:
        # Initialize AWS clients
        iam = boto3.client('iam')
        s3 = boto3.client('s3')
        sns = boto3.client('sns')
        kms = boto3.client('kms')
        dynamodb = boto3.resource('dynamodb')
        
        # Get configuration from environment variables
        table_name = os.environ.get('DYNAMODB_TABLE', 'iam-rotation-state')
        config_bucket = os.environ.get('CONFIG_BUCKET', 'iam-rotation-demo-config-160885290762')
        notification_topic = os.environ.get('NOTIFICATION_TOPIC_ARN', 'arn:aws:sns:us-east-1:160885290762:iam-rotation-notifications')
        kms_key_id = os.environ.get('KMS_KEY_ID', '7e5418a3-908e-4249-bb8c-a0f9b3b18b95')
        
        # Define users to rotate
        users_to_rotate = ['demo-sns-service', 'demo-s3-service']
        
        # Get DynamoDB table
        table = dynamodb.Table(table_name)
        
        print(f"Starting multi-user rotation for users: {users_to_rotate}")
        
        # Rotate keys for all users simultaneously
        rotation_results = []
        all_successful = True
        
        for user_name in users_to_rotate:
            try:
                print(f"Rotating keys for user: {user_name}")
                
                # Check current keys
                current_keys = iam.list_access_keys(UserName=user_name)
                total_keys = len(current_keys['AccessKeyMetadata'])
                active_keys = [key for key in current_keys['AccessKeyMetadata'] if key['Status'] == 'Active']
                
                if total_keys >= 2:
                    print(f"User {user_name} has {total_keys} keys, deactivating oldest inactive key...")
                    # Find oldest inactive key to delete
                    inactive_keys = [key for key in current_keys['AccessKeyMetadata'] if key['Status'] == 'Inactive']
                    if inactive_keys:
                        oldest_inactive_key = min(inactive_keys, key=lambda x: x['CreateDate'])
                        iam.delete_access_key(
                            UserName=user_name,
                            AccessKeyId=oldest_inactive_key['AccessKeyId']
                        )
                        print(f"Deleted old inactive key: {oldest_inactive_key['AccessKeyId']}")
                    else:
                        print(f"No inactive keys to delete for {user_name}")
                
                # Create new access key
                response = iam.create_access_key(UserName=user_name)
                new_key = response['AccessKey']
                
                # Store in DynamoDB
                ttl_time = int((datetime.now() + timedelta(days=30)).timestamp())
                table.put_item(Item={
                    'UserId': user_name,
                    'current_key_id': new_key['AccessKeyId'],
                    'current_secret_key': new_key['SecretAccessKey'],
                    'Status': 'ACTIVE',
                    'ActivatedAt': datetime.now().isoformat(),
                    'TTL': ttl_time
                })
                
                rotation_results.append({
                    'user': user_name,
                    'status': 'success',
                    'newKeyId': new_key['AccessKeyId']
                })
                
                print(f"Successfully rotated keys for {user_name}: {new_key['AccessKeyId']}")
                
            except Exception as e:
                print(f"Error rotating keys for {user_name}: {str(e)}")
                rotation_results.append({
                    'user': user_name,
                    'status': 'failed',
                    'error': str(e)
                })
                all_successful = False
        
        # Update multi-user configuration file if all rotations succeeded
        if all_successful:
            print("All rotations successful, updating multi-user config...")
            update_multi_user_config(s3, kms, kms_key_id, table, users_to_rotate, config_bucket)
            
            # Send success notification
            sns.publish(
                TopicArn=notification_topic,
                Subject="Multi-User Rotation Success",
                Message=f"All users rotated successfully: {json.dumps(rotation_results, indent=2)}"
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Multi-user rotation completed successfully',
                    'results': rotation_results,
                    'timestamp': datetime.now().isoformat()
                })
            }
        else:
            # Send failure notification
            sns.publish(
                TopicArn=notification_topic,
                Subject="Multi-User Rotation Failed",
                Message=f"Some rotations failed: {json.dumps(rotation_results, indent=2)}"
            )
            
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'Some rotations failed',
                    'results': rotation_results,
                    'timestamp': datetime.now().isoformat()
                })
            }
            
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        # Send error notification
        try:
            sns.publish(
                TopicArn=notification_topic,
                Subject="Multi-User Rotation Error",
                Message=f"Unexpected error: {str(e)}"
            )
        except:
            pass
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }

def update_multi_user_config(s3, kms, kms_key_id, table, users, bucket):
    """Update multi-user configuration file with encrypted keys"""
    try:
        # Get current keys from DynamoDB
        keys = {}
        for user_name in users:
            response = table.get_item(Key={'UserId': user_name})
            if response.get('Item'):
                keys[user_name] = response['Item']
        
        # Encrypt secret keys using KMS
        encrypted_config = {}
        for user_name, key_data in keys.items():
            if 'current_secret_key' in key_data:
                encrypt_response = kms.encrypt(
                    KeyId=kms_key_id,
                    Plaintext=key_data['current_secret_key'].encode('utf-8')
                )
                ciphertext_b64 = base64.b64encode(encrypt_response['CiphertextBlob']).decode('utf-8')
                
                encrypted_config[user_name] = {
                    'access_key_id': key_data['current_key_id'],
                    'secret_key_encrypted': ciphertext_b64
                }
        
        # Create multi-user configuration content
        config_content = f"""# Multi-User Demo Service Environment Configuration
# Generated: {datetime.now().isoformat()}
# Rotation System: Automated Multi-User IAM Key Rotation

# User 1: demo-sns-service (SNS Permissions)
DEMO_SNS_SERVICE_ACCESS_KEY_ID={encrypted_config.get('demo-sns-service', {}).get('access_key_id', '')}
DEMO_SNS_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED={encrypted_config.get('demo-sns-service', {}).get('secret_key_encrypted', '')}

# User 2: demo-s3-service (S3 Permissions)
DEMO_S3_SERVICE_ACCESS_KEY_ID={encrypted_config.get('demo-s3-service', {}).get('access_key_id', '')}
DEMO_S3_SERVICE_SECRET_ACCESS_KEY_ENCRYPTED={encrypted_config.get('demo-s3-service', {}).get('secret_key_encrypted', '')}

# KMS Configuration
KMS_KEY_ID={kms_key_id}
AWS_REGION=us-east-1

# Service Configuration
SERVICE_NAME=multi-user-demo-service
SERVICE_VERSION=2.0.0
ENVIRONMENT=demo
"""
        
        # Upload to S3
        s3.put_object(
            Bucket=bucket,
            Key='.env',
            Body=config_content.encode('utf-8'),
            ContentType='text/plain'
        )
        
        print(f"Multi-user configuration updated in S3: s3://{bucket}/.env")
        
    except Exception as e:
        print(f"Error updating multi-user config: {str(e)}")
        raise e
