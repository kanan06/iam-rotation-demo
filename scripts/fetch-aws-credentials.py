#!/usr/bin/env python3
"""
Fetch AWS Credentials from S3
Retrieves and decrypts AWS credentials from encrypted .env files stored in S3
"""

import json
import boto3
import sys
import os
from botocore.exceptions import ClientError

def get_stack_outputs(stack_name):
    """Get CloudFormation stack outputs"""
    try:
        cloudformation = boto3.client('cloudformation')
        response = cloudformation.describe_stacks(StackName=stack_name)
        
        outputs = {}
        for output in response['Stacks'][0]['Outputs']:
            outputs[output['OutputKey']] = output['OutputValue']
        
        return outputs
    except Exception as e:
        print(f"❌ Error getting stack outputs: {e}")
        sys.exit(1)

def fetch_credentials_from_s3(config_file='env1.env'):
    """Fetch credentials from encrypted S3 config file"""
    try:
        # Get stack outputs
        outputs = get_stack_outputs('iam-rotation-demo')
        config_bucket = outputs['ConfigBucket']
        kms_key_id = outputs['KmsKeyId']
        
        print(f"📁 Fetching credentials from {config_file}")
        print(f"🪣 Config bucket: {config_bucket}")
        print(f"🔑 KMS key: {kms_key_id}")
        
        # Initialize AWS clients
        s3_client = boto3.client('s3')
        kms_client = boto3.client('kms')
        
        # Download encrypted file and metadata
        encrypted_file = f"{config_file}.encrypted"
        metadata_file = f"{config_file}.metadata"
        
        print(f"⬇️ Downloading {encrypted_file}...")
        s3_client.download_file(config_bucket, encrypted_file, f"/tmp/{encrypted_file}")
        
        print(f"⬇️ Downloading {metadata_file}...")
        s3_client.download_file(config_bucket, metadata_file, f"/tmp/{metadata_file}")
        
        # Read metadata
        with open(f"/tmp/{metadata_file}", 'r') as f:
            metadata = json.load(f)
        
        print(f"📊 Metadata: {metadata}")
        
        # Decrypt the file
        with open(f"/tmp/{encrypted_file}", 'rb') as f:
            encrypted_data = f.read()
        
        print("🔓 Decrypting file...")
        response = kms_client.decrypt(
            CiphertextBlob=encrypted_data,
            KeyId=kms_key_id
        )
        
        decrypted_content = response['Plaintext'].decode('utf-8')
        
        # Parse .env content
        env_vars = {}
        for line in decrypted_content.split('\n'):
            if '=' in line and not line.startswith('#'):
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
        
        print(f"📝 Found {len(env_vars)} environment variables")
        
        # Extract AWS credentials (handle user-specific credentials)
        credentials = {}
        user_credentials = {}
        
        for key, value in env_vars.items():
            if key.startswith('AWS_'):
                credentials[key] = value
                # Check for user-specific credentials
                if 'USER1' in key:
                    user_credentials['USER1'] = user_credentials.get('USER1', {})
                    if 'ACCESS_KEY_ID' in key:
                        user_credentials['USER1']['AWS_ACCESS_KEY_ID'] = value
                    elif 'SECRET_ACCESS_KEY' in key:
                        user_credentials['USER1']['AWS_SECRET_ACCESS_KEY'] = value
                elif 'USER2' in key:
                    user_credentials['USER2'] = user_credentials.get('USER2', {})
                    if 'ACCESS_KEY_ID' in key:
                        user_credentials['USER2']['AWS_ACCESS_KEY_ID'] = value
                    elif 'SECRET_ACCESS_KEY' in key:
                        user_credentials['USER2']['AWS_SECRET_ACCESS_KEY'] = value
        
        if not credentials:
            print("⚠️ No AWS credentials found in the config file")
            return None
        
        print(f"🔑 Found {len(credentials)} AWS credential variables")
        
        # Use USER1 credentials as default (or first available user)
        aws_access_key_id = None
        aws_secret_access_key = None
        aws_region = credentials.get('AWS_REGION', 'us-east-1')
        
        # Try to get USER1 credentials first
        if 'USER1' in user_credentials:
            user1_creds = user_credentials['USER1']
            if 'AWS_ACCESS_KEY_ID' in user1_creds and 'AWS_SECRET_ACCESS_KEY' in user1_creds:
                aws_access_key_id = user1_creds['AWS_ACCESS_KEY_ID']
                aws_secret_access_key = user1_creds['AWS_SECRET_ACCESS_KEY']
                print("✅ Using USER1 credentials")
        # Fallback to USER2 if USER1 not available
        elif 'USER2' in user_credentials:
            user2_creds = user_credentials['USER2']
            if 'AWS_ACCESS_KEY_ID' in user2_creds and 'AWS_SECRET_ACCESS_KEY' in user2_creds:
                aws_access_key_id = user2_creds['AWS_ACCESS_KEY_ID']
                aws_secret_access_key = user2_creds['AWS_SECRET_ACCESS_KEY']
                print("✅ Using USER2 credentials")
        
        if aws_access_key_id and aws_secret_access_key:
            print("✅ Successfully extracted AWS credentials")
            print(f"🔑 Access Key ID: {aws_access_key_id[:10]}...")
            print(f"🔐 Secret Access Key: {aws_secret_access_key[:10]}...")
            print(f"🌍 Region: {aws_region}")
            
            # Set GitHub Actions outputs (new syntax)
            with open(os.environ.get('GITHUB_OUTPUT', '/dev/null'), 'a') as f:
                f.write(f"aws-access-key-id={aws_access_key_id}\n")
                f.write(f"aws-secret-access-key={aws_secret_access_key}\n")
                f.write(f"aws-region={aws_region}\n")
            
            return {
                'AWS_ACCESS_KEY_ID': aws_access_key_id,
                'AWS_SECRET_ACCESS_KEY': aws_secret_access_key,
                'AWS_REGION': aws_region
            }
        else:
            print("❌ Missing required AWS credentials")
            print(f"Available users: {list(user_credentials.keys())}")
            return None
            
    except Exception as e:
        print(f"❌ Error fetching credentials: {e}")
        return None

def main():
    """Main function"""
    # Get config file from command line argument or use default
    config_file = sys.argv[1] if len(sys.argv) > 1 else 'env1.env'
    
    print("🚀 Starting AWS Credentials Fetch")
    print(f"📁 Config file: {config_file}")
    
    credentials = fetch_credentials_from_s3(config_file)
    
    if credentials:
        print("✅ Credentials fetched successfully")
        sys.exit(0)
    else:
        print("❌ Failed to fetch credentials")
        sys.exit(1)

if __name__ == "__main__":
    main()
