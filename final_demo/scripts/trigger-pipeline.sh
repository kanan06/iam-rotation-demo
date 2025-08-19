#!/bin/bash

# Trigger GitHub Actions Pipeline
echo "🚀 Triggering GitHub Actions Pipeline via API"
echo "=============================================="

# GitHub repository details
GITHUB_REPO="kanan06/iam-rotation-demo"
WORKFLOW_FILE="iam-rotation-pipeline.yml"
BRANCH="clean-branch"

# Check if GitHub token is available
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN environment variable not set"
    echo "   Please set your GitHub personal access token:"
    echo "   export GITHUB_TOKEN=your_token_here"
    echo ""
    echo "🔗 Manual trigger instructions:"
    echo "   1. Visit: https://github.com/$GITHUB_REPO/actions/workflows/$WORKFLOW_FILE"
    echo "   2. Click 'Run workflow'"
    echo "   3. Select branch: $BRANCH"
    echo "   4. Click 'Run workflow'"
    exit 1
fi

# Trigger the workflow
echo "📡 Sending workflow dispatch request..."
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/workflows/$WORKFLOW_FILE/dispatches" \
  -d "{
    \"ref\": \"$BRANCH\",
    \"inputs\": {
      \"environment\": \"demo\"
    }
  }"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Workflow triggered successfully!"
    echo "🌐 Check status: https://github.com/$GITHUB_REPO/actions"
else
    echo ""
    echo "❌ Failed to trigger workflow"
    echo "🔗 Manual trigger: https://github.com/$GITHUB_REPO/actions/workflows/$WORKFLOW_FILE"
fi

