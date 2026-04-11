# Cloud Resume Challenge — Backend

Serverless visitor counter API for my [Cloud Resume Challenge](https://cloudresumechallenge.dev/) project. Built on AWS with infrastructure managed entirely as code, deployed through a CI/CD pipeline with no stored credentials.

**Live site:** [gregoryeberwine.com](https://gregoryeberwine.com)  
**Frontend repo:** [resume-frontend](https://github.com/gregoryeberwine/resume-frontend)

---

## Architecture

When the resume page loads, JavaScript calls the API Gateway endpoint. A Lambda function reads the current visitor count from DynamoDB, increments it, persists the new value, and returns it to the page.

```
Browser → API Gateway → Lambda (Python) → DynamoDB
```

CORS is enforced at both the API Gateway (OPTIONS preflight) and Lambda (response header) levels. The allowed origin is stored in SSM Parameter Store and injected into Lambda at deploy time, keeping it decoupled from the source code.

---

## Stack

| Layer | Technology |
|---|---|
| API | AWS API Gateway (REST) |
| Compute | AWS Lambda — Python 3.14 |
| Database | AWS DynamoDB (on-demand) |
| Observability | AWS CloudWatch Alarms + SNS email notifications |
| Infrastructure | Terraform (S3 remote state) |
| CI/CD | GitHub Actions (OIDC — no stored AWS credentials) |

---

## CI/CD Pipeline

Triggered on push to `main` or `dev`. Each branch targets a separate AWS environment and Terraform state bucket.

```
push → [test] → [build]
```

1. **Test** — Runs the pytest suite against the Lambda function with a mocked DynamoDB client
2. **Build** — Authenticates to AWS via OIDC, then runs `terraform apply`

---

## Test Suite

Nine unit tests covering the Lambda function's core behavior:

| Test | What it verifies |
|---|---|
| `test_returns_200` | Handler always returns HTTP 200 |
| `test_cors_header_matches_env` | CORS header matches the `ALLOWED_ORIGIN` env var |
| `test_increments_counter_by_one` | Counter value increases by exactly 1 per call |
| `test_response_body_contains_number_visitors` | Response body contains `numberVisitors` as an integer |
| `test_reads_from_correct_table_and_key` | DynamoDB `GetItem` targets the correct table and partition key |
| `test_writes_incremented_value_to_dynamodb` | DynamoDB `PutItem` writes the correct incremented value |
| `test_empty_table_starts_at_one` | Counter initializes to 1 when no item exists in the table |
| `test_dynamodb_get_error_propagates` | `ClientError` on `GetItem` surfaces to the caller |
| `test_dynamodb_put_error_propagates` | `ClientError` on `PutItem` surfaces to the caller |

---

## Observability

Three CloudWatch alarms publish to an SNS topic configured with email notification:

- **Lambda Errors** — triggers if any invocation fails within a 5-minute window
- **Invocation Volume** — triggers if invocations exceed 50 in a 5-minute window
- **API Latency** — triggers if average API Gateway latency exceeds 3 seconds

---

## Repo Structure

```
├── .github/workflows/   # GitHub Actions CI/CD (test → deploy)
├── org-formation/       # AWS Organization bootstrapping (OrgFormation)
├── terraform/           # All AWS infrastructure as code
├── tests/               # pytest unit test suite
└── lambda_function.py   # Visitor counter Lambda handler
```

---

## What I Learned

Getting CORS working was a bit difficult; figuring out that it needed to go both in the Lambda function's return header and in the integration response took some digging to figure out. After that though, when I had split the project into both a dev and prod deployment, I needed a way to pass the default Cloudfront distribution URL to both since it would keep changing. Passing that through an SSM parameter from the frontend where the distribution is made worked out nicely! I also experimented with mocking in the tests so the function could be tested without need to call AWS. Took a bit to figure out but seems intuitive in hindsight!