#!/bin/bash

# Function to get input from the user
get_input() {
  read -p "$1: " input
  echo "$input"
}

# Collect inputs from the user
AWS_REGION=$(get_input "Enter the AWS region (e.g., us-east-2)")
ACCOUNT_ID=$(get_input "Enter the AWS Account ID")
LAMBDA_FUNCTION_NAME=$(get_input "Enter the Lambda function name")
ECR_REPO_NAME=$(get_input "Enter the ECR repo name")
IMAGE_TAG=$(get_input "Enter the Docker image tag (e.g., latest)")
DOCKERFILE_PATH=$(get_input "Enter the path to your Dockerfile (default: .)")
LAMBDA_ROLE_NAME=$(get_input "Enter the Lambda execution role name (e.g., lambda-role)")

# Construct the Lambda Role ARN using the account ID and role name
LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

# Default values if not provided
DOCKERFILE_PATH=${DOCKERFILE_PATH:-"."}

# Step 1: Authenticate Docker with ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Step 2: Build the Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} $DOCKERFILE_PATH

# Step 3: Tag the Docker image
echo "Tagging Docker image..."
docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}

# Step 4: Push the Docker image to ECR
echo "Pushing Docker image to ECR..."
aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} || aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}
docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}

# Step 5: Create or update the Lambda function
echo "Creating or updating Lambda function..."
aws lambda create-function --function-name ${LAMBDA_FUNCTION_NAME} \
  --package-type Image \
  --code ImageUri=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} \
  --role ${LAMBDA_ROLE_ARN} \
  --region ${AWS_REGION} || aws lambda update-function-code --function-name ${LAMBDA_FUNCTION_NAME} \
  --image-uri ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} \
  --region ${AWS_REGION}

# Step 6: Create Lambda function URL (if not already created)
echo "Creating Lambda function URL..."
aws lambda create-function-url-config --function-name ${LAMBDA_FUNCTION_NAME} --auth-type NONE --region ${AWS_REGION}

# Step 7: Whitelist the Function URL for public access
echo "Whitelisting the Function URL for public access..."
aws lambda add-permission --function-name ${LAMBDA_FUNCTION_NAME} \
  --action lambda:InvokeFunctionUrl \
  --principal "*" \
  --statement-id FunctionUrlAllowPublicAccess \
  --function-url-auth-type NONE \
  --region ${AWS_REGION}

# Step 8: Retrieve and display the Function URL
echo "Retrieving Function URL..."
FUNCTION_URL=$(aws lambda get-function-url-config --function-name ${LAMBDA_FUNCTION_NAME} --query "FunctionUrl" --output text --region ${AWS_REGION})
echo "Your Lambda Function URL is: ${FUNCTION_URL}"

# Step 9: Option to trigger the function locally via curl
read -p "Do you want to trigger the function locally? (y/n): " TRIGGER_LOCAL
if [[ $TRIGGER_LOCAL == "y" ]]; then
  echo "Triggering the Lambda function via curl..."
  curl -X POST ${FUNCTION_URL}
fi

echo "Deployment completed!"
