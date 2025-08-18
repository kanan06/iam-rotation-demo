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
        
        # Extract AWS credentials
        credentials = {}
        for key, value in env_vars.items():
            if key.startswith('AWS_'):
                credentials[key] = value
        
        if not credentials:
            print("⚠️ No AWS credentials found in the config file")
            return None
        
        print(f"🔑 Found {len(credentials)} AWS credential variables")
        
        # Set GitHub Actions outputs
        aws_access_key_id = credentials.get('AWS_ACCESS_KEY_ID')
        aws_secret_access_key = credentials.get('AWS_SECRET_ACCESS_KEY')
        aws_region = credentials.get('AWS_REGION', 'us-east-1')
        
        if aws_access_key_id and aws_secret_access_key:
            print("✅ Successfully extracted AWS credentials")
            print(f"🔑 Access Key ID: {aws_access_key_id[:10]}...")
            print(f"🔐 Secret Access Key: {aws_secret_access_key[:10]}...")
            print(f"🌍 Region: {aws_region}")
            
            # Set GitHub Actions outputs
            print(f"::set-output name=aws-access-key-id::{aws_access_key_id}")
            print(f"::set-output name=aws-secret-access-key::{aws_secret_access_key}")
            print(f"::set-output name=aws-region::{aws_region}")
            
            return {
                'AWS_ACCESS_KEY_ID': aws_access_key_id,
                'AWS_SECRET_ACCESS_KEY': aws_secret_access_key,
                'AWS_REGION': aws_region
            }
        else:
            print("❌ Missing required AWS credentials")
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
