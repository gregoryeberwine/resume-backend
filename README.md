# Cloud Resume Challenge — Backend

The backend API for my [Cloud Resume Challenge](https://cloudresumechallenge.dev/) project. A serverless visitor counter built on AWS, deployed and managed with Terraform and GitHub Actions.

**Live site:** [gregoryeberwine.com](https://gregoryeberwine.com)
**Frontend repo:** [resume-frontend](https://github.com/gregoryeberwine/resume-frontend)

## How It Works

The resume site includes a visitor counter. When the page loads, JavaScript calls the API Gateway endpoint, which triggers a Lambda function. The function increments a counter in DynamoDB and returns the updated value to display on the page.

## Stack

- **API Gateway** — REST API with CORS configuration
- **Lambda** — Python function to read/increment/return the visitor count
- **DynamoDB** — Single-table storage for the counter value
- **CloudWatch** — Alarms monitoring API latency, Lambda invocations, and errors (via SNS)
- **Terraform** — Infrastructure as code for all AWS resources
- **GitHub Actions** — CI/CD pipeline (OIDC auth, Terraform apply)

## CI/CD Pipeline

On push to `main`, the GitHub Actions workflow:

1. Authenticates to AWS via OIDC (no stored credentials)
2. Runs `terraform apply` to deploy Lambda, API Gateway, DynamoDB, and CloudWatch resources

## Repo Structure

```
├── .github/workflows/   # GitHub Actions CI/CD
├── org-formation/        # AWS Organization setup (OrgFormation)
├── terraform/            # Infrastructure as code
└── lambda_function.py    # Python Lambda function
```
