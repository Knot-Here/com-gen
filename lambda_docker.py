def get_input(prompt):
    """Helper function to get user input."""
    return input(prompt)

# Collect inputs from the user
aws_region = get_input("Enter the AWS region (e.g., us-east-2): ")
account_id = get_input("Enter the AWS Account ID: ")
lambda_function_name = get_input("Enter the Lambda function name: ")
ecr_repo_name = get_input("Enter the ECR repo name: ")
image_tag = get_input("Enter the Docker image tag (e.g., latest): ")
dockerfile_path = get_input("Enter the path to your Dockerfile (default: .): ")
lambda_role_name = get_input("Enter the Lambda execution role name (e.g., lambda-role): ")

# Default values if not provided
dockerfile_path = dockerfile_path or "."

# Construct the Lambda Role ARN using the account ID and role name
lambda_role_arn = f"arn:aws:iam::{account_id}:role/{lambda_role_name}"

print("\n# Generated Commands\n")

# Step 1: Authenticate Docker with ECR
auth_cmd = f"aws ecr get-login-password --region {aws_region} | docker login --username AWS --password-stdin {account_id}.dkr.ecr.{aws_region}.amazonaws.com"
print(f"Authenticate Docker with ECR:\n{auth_cmd}\n")

# Step 2: Build the Docker image
build_cmd = f"docker build -t {ecr_repo_name}:{image_tag} {dockerfile_path}"
print(f"Build the Docker image:\n{build_cmd}\n")

# Step 3: Tag the Docker image
tag_cmd = f"docker tag {ecr_repo_name}:{image_tag} {account_id}.dkr.ecr.{aws_region}.amazonaws.com/{ecr_repo_name}:{image_tag}"
print(f"Tag the Docker image:\n{tag_cmd}\n")

# Step 4: Push the Docker image to ECR
push_cmd = f"aws ecr describe-repositories --repository-names {ecr_repo_name} --region {aws_region} || aws ecr create-repository --repository-name {ecr_repo_name} --region {aws_region}\n"
push_cmd += f"docker push {account_id}.dkr.ecr.{aws_region}.amazonaws.com/{ecr_repo_name}:{image_tag}"
print(f"Push the Docker image to ECR:\n{push_cmd}\n")

# Step 5: Create or update the Lambda function
create_lambda_cmd = f"aws lambda create-function --function-name {lambda_function_name} \\\n"
create_lambda_cmd += f"  --package-type Image \\\n"
create_lambda_cmd += f"  --code ImageUri={account_id}.dkr.ecr.{aws_region}.amazonaws.com/{ecr_repo_name}:{image_tag} \\\n"
create_lambda_cmd += f"  --role {lambda_role_arn} --region {aws_region} || \\\n"
create_lambda_cmd += f"aws lambda update-function-code --function-name {lambda_function_name} \\\n"
create_lambda_cmd += f"  --image-uri {account_id}.dkr.ecr.{aws_region}.amazonaws.com/{ecr_repo_name}:{image_tag} --region {aws_region}"
print(f"Create or update the Lambda function:\n{create_lambda_cmd}\n")

# Step 6: Create Lambda function URL
url_cmd = f"aws lambda create-function-url-config --function-name {lambda_function_name} --auth-type NONE --region {aws_region}"
print(f"Create Lambda Function URL:\n{url_cmd}\n")

# Step 7: Whitelist the Function URL for public access
whitelist_cmd = f"aws lambda add-permission --function-name {lambda_function_name} \\\n"
whitelist_cmd += f"  --action lambda:InvokeFunctionUrl \\\n"
whitelist_cmd += f"  --principal '*' \\\n"
whitelist_cmd += f"  --statement-id FunctionUrlAllowPublicAccess \\\n"
whitelist_cmd += f"  --function-url-auth-type NONE --region {aws_region}"
print(f"Whitelist the Function URL for public access:\n{whitelist_cmd}\n")

# Step 8: Retrieve and display the Function URL
get_url_cmd = f"aws lambda get-function-url-config --function-name {lambda_function_name} --query 'FunctionUrl' --output text --region {aws_region}"
print(f"Retrieve the Function URL:\n{get_url_cmd}\n")

# Additional tip: Use curl to invoke the Lambda function
invoke_tip = f"To trigger the Lambda function locally, use:\n  curl -X POST $(aws lambda get-function-url-config --function-name {lambda_function_name} --query 'FunctionUrl' --output text --region {aws_region})"
print(invoke_tip)

