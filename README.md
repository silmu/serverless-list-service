# Serverless List Service

Simple API service. API key is required for access.

## Endpoints

### `/head`

Returns the first item in the list of strings.

### `/tail`

Returns the last item in the list of strings.

## Deployment Instructions

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured with credentials
- Python 3.8+ installed

### 1. Install Python Dependencies

```sh
pip install -r requirements.txt
```

### 2. Package Lambda Functions

```sh
# From the project root
mkdir -p build/head build/tail

pip install boto3 -t build/head
cp src/head.py build/head/
cd build/head && zip -r ../../deployment/head.zip . && cd ../..

pip install boto3 -t build/tail
cp src/tail.py build/tail/
cd build/tail && zip -r ../../deployment/tail.zip . && cd ../..
```

### 3. Deploy Infrastructure with Terraform

```sh
cd deployment
terraform init
terraform apply
```

- Review the plan and type `yes` to confirm.

### 4. Get API Endpoint and API Key

After deployment, Terraform will output:

- `api_url` — your API Gateway endpoint
- `api_key_value` — your API key (use in the `x-api-key` header)

Note: If the `api_key_value` is hidden run:

```sh
terraform output api_key_value
```

### 5. Test the API

1. **Set Environment Variables**

   In your terminal, set the following environment variables with your actual values:

   ```sh
   export API_URL="https://your-api-id.execute-api.<region>.amazonaws.com/prod"
   export API_KEY="your_api_key_value"
   ```

2. **Run the Test Script**

   Execute the test script:

   ```sh
   python test_api.py
   ```

3. **Expected Output**

   If both endpoints are working, you should see:

   ```
   Head endpoint test passed.
   Tail endpoint test passed.
   ```
