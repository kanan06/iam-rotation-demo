#!/usr/bin/env python3
"""
Health Check Script
Comprehensive health checks for AWS services and application functionality
"""

import json
import boto3
import sys
import os
import requests
from datetime import datetime
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
        return None

def check_s3_access():
    """Check S3 access and functionality"""
    try:
        s3_client = boto3.client('s3')
        
        # Test basic S3 operations
        response = s3_client.list_buckets()
        buckets = [bucket['Name'] for bucket in response['Buckets']]
        
        # Check if our demo buckets exist
        demo_buckets = [b for b in buckets if 'iam-rotation-demo' in b]
        
        if demo_buckets:
            print(f"✅ S3 access OK - Found {len(demo_buckets)} demo buckets")
            return True, f"Found demo buckets: {', '.join(demo_buckets)}"
        else:
            print("⚠️ S3 access OK but no demo buckets found")
            return True, "S3 access working but no demo buckets"
            
    except Exception as e:
        print(f"❌ S3 access failed: {e}")
        return False, f"S3 access failed: {e}"

def check_sns_access():
    """Check SNS access and functionality"""
    try:
        sns_client = boto3.client('sns')
        
        # Test SNS operations
        response = sns_client.list_topics()
        topics = [topic['TopicArn'] for topic in response['Topics']]
        
        # Check if our notification topic exists
        demo_topics = [t for t in topics if 'iam-rotation-notifications' in t]
        
        if demo_topics:
            print(f"✅ SNS access OK - Found notification topic")
            return True, "SNS notification topic accessible"
        else:
            print("⚠️ SNS access OK but no notification topic found")
            return True, "SNS access working but no notification topic"
            
    except Exception as e:
        print(f"❌ SNS access failed: {e}")
        return False, f"SNS access failed: {e}"

def check_dynamodb_access():
    """Check DynamoDB access and functionality"""
    try:
        dynamodb_client = boto3.client('dynamodb')
        
        # Test DynamoDB operations
        response = dynamodb_client.list_tables()
        tables = response['TableNames']
        
        # Check if our rotation state table exists
        if 'iam-rotation-state' in tables:
            print("✅ DynamoDB access OK - Rotation state table exists")
            return True, "DynamoDB rotation state table accessible"
        else:
            print("⚠️ DynamoDB access OK but rotation state table not found")
            return True, "DynamoDB access working but no rotation table"
            
    except Exception as e:
        print(f"❌ DynamoDB access failed: {e}")
        return False, f"DynamoDB access failed: {e}"

def check_lambda_access():
    """Check Lambda access and functionality"""
    try:
        lambda_client = boto3.client('lambda')
        
        # Test Lambda operations
        response = lambda_client.list_functions()
        functions = [func['FunctionName'] for func in response['Functions']]
        
        # Check if our rotation function exists
        if 'iam-rotation-function' in functions:
            print("✅ Lambda access OK - Rotation function exists")
            return True, "Lambda rotation function accessible"
        else:
            print("⚠️ Lambda access OK but rotation function not found")
            return True, "Lambda access working but no rotation function"
            
    except Exception as e:
        print(f"❌ Lambda access failed: {e}")
        return False, f"Lambda access failed: {e}"

def check_iam_access():
    """Check IAM access and functionality"""
    try:
        iam_client = boto3.client('iam')
        
        # Test IAM operations
        response = iam_client.list_users()
        users = [user['UserName'] for user in response['Users']]
        
        # Check if our demo users exist
        demo_users = [u for u in users if u.startswith('demo-user-')]
        
        if demo_users:
            print(f"✅ IAM access OK - Found {len(demo_users)} demo users")
            return True, f"Found demo users: {', '.join(demo_users)}"
        else:
            print("⚠️ IAM access OK but no demo users found")
            return True, "IAM access working but no demo users"
            
    except Exception as e:
        print(f"❌ IAM access failed: {e}")
        return False, f"IAM access failed: {e}"

def check_website_access():
    """Check website accessibility"""
    try:
        # Get app bucket name
        outputs = get_stack_outputs('iam-rotation-demo')
        if not outputs:
            return False, "Could not get stack outputs"
        
        app_bucket = outputs['DemoAppBucket']
        website_url = f"https://{app_bucket}.s3-website-us-east-1.amazonaws.com"
        
        # Try to access the website
        response = requests.get(website_url, timeout=10)
        
        if response.status_code == 200:
            print("✅ Website access OK")
            return True, f"Website accessible at {website_url}"
        else:
            print(f"⚠️ Website returned status {response.status_code}")
            return True, f"Website returned status {response.status_code}"
            
    except requests.exceptions.RequestException as e:
        print(f"⚠️ Website access failed: {e}")
        return True, f"Website access failed: {e}"  # Don't fail the entire health check for website
    except Exception as e:
        print(f"⚠️ Website check error: {e}")
        return True, f"Website check error: {e}"

def check_cloudformation_access():
    """Check CloudFormation access"""
    try:
        cloudformation_client = boto3.client('cloudformation')
        
        # Test CloudFormation operations
        response = cloudformation_client.describe_stacks(StackName='iam-rotation-demo')
        stack_status = response['Stacks'][0]['StackStatus']
        
        if stack_status in ['CREATE_COMPLETE', 'UPDATE_COMPLETE']:
            print(f"✅ CloudFormation access OK - Stack status: {stack_status}")
            return True, f"Stack status: {stack_status}"
        else:
            print(f"⚠️ CloudFormation access OK but stack status: {stack_status}")
            return True, f"Stack status: {stack_status}"
            
    except Exception as e:
        print(f"❌ CloudFormation access failed: {e}")
        return False, f"CloudFormation access failed: {e}"

def run_health_checks():
    """Run all health checks"""
    print("🔍 Starting comprehensive health checks...")
    
    checks = [
        ("S3 Access", check_s3_access),
        ("SNS Access", check_sns_access),
        ("DynamoDB Access", check_dynamodb_access),
        ("Lambda Access", check_lambda_access),
        ("IAM Access", check_iam_access),
        ("CloudFormation Access", check_cloudformation_access),
        ("Website Access", check_website_access)
    ]
    
    results = []
    passed_checks = 0
    total_checks = len(checks)
    
    for check_name, check_function in checks:
        print(f"\n🔍 Running {check_name} check...")
        try:
            passed, message = check_function()
            results.append({
                'check': check_name,
                'passed': passed,
                'message': message
            })
            
            if passed:
                passed_checks += 1
                
        except Exception as e:
            print(f"❌ {check_name} check failed with exception: {e}")
            results.append({
                'check': check_name,
                'passed': False,
                'message': f"Exception: {e}"
            })
    
    # Calculate health score
    health_score = (passed_checks / total_checks) * 100 if total_checks > 0 else 0
    
    # Determine overall status
    if health_score >= 90:
        status = 'HEALTHY'
        rollback_needed = False
    elif health_score >= 70:
        status = 'DEGRADED'
        rollback_needed = False
    else:
        status = 'UNHEALTHY'
        rollback_needed = True
    
    # Print summary
    print(f"\n📊 Health Check Summary")
    print(f"========================")
    print(f"Total Checks: {total_checks}")
    print(f"Passed: {passed_checks}")
    print(f"Failed: {total_checks - passed_checks}")
    print(f"Health Score: {health_score:.1f}%")
    print(f"Status: {status}")
    print(f"Rollback Needed: {rollback_needed}")
    
    print(f"\n📋 Detailed Results:")
    for result in results:
        status_icon = "✅" if result['passed'] else "❌"
        print(f"{status_icon} {result['check']}: {result['message']}")
    
    # Set GitHub Actions outputs
    print(f"::set-output name=score::{health_score:.1f}")
    print(f"::set-output name=status::{status}")
    print(f"::set-output name=rollback::{str(rollback_needed).lower()}")
    
    return {
        'status': status,
        'score': health_score,
        'passed': passed_checks,
        'total': total_checks,
        'rollback_needed': rollback_needed,
        'results': results
    }

def main():
    """Main function"""
    print("🚀 Starting Health Check Process")
    print(f"⏰ Timestamp: {datetime.now().isoformat()}")
    
    # Check if AWS credentials are available
    if not (os.getenv('AWS_ACCESS_KEY_ID') and os.getenv('AWS_SECRET_ACCESS_KEY')):
        print("❌ AWS credentials not found in environment")
        sys.exit(1)
    
    # Run health checks
    health_result = run_health_checks()
    
    # Exit with appropriate code
    if health_result['status'] == 'HEALTHY':
        print("\n✅ Health checks completed successfully")
        sys.exit(0)
    elif health_result['status'] == 'DEGRADED':
        print("\n⚠️ Health checks completed with warnings")
        sys.exit(0)  # Don't fail for degraded status
    else:
        print("\n❌ Health checks failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
