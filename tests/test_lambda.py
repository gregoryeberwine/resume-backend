import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest
from botocore.exceptions import ClientError

# Set required env var before module-level code in lambda_function runs
os.environ.setdefault("ALLOWED_ORIGIN", "https://test.example.com")

# Add backend directory to path and patch boto3.client at import time
# to prevent real AWS calls when lambda_function is loaded
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
with patch("boto3.client"):
    import lambda_function


@pytest.fixture
def mock_client():
    """Replaces the module-level DynamoDB client with a mock for each test."""
    client = MagicMock()
    client.get_item.return_value = {"Item": {"numberVisitors": {"N": "42"}}}
    client.put_item.return_value = {}
    original = lambda_function.client
    lambda_function.client = client
    yield client
    lambda_function.client = original


def test_returns_200(mock_client):
    result = lambda_function.lambda_handler({}, {})
    assert result["statusCode"] == 200


def test_cors_header_matches_env(mock_client):
    result = lambda_function.lambda_handler({}, {})
    assert result["headers"]["Access-Control-Allow-Origin"] == lambda_function.ALLOWED_ORIGIN


def test_increments_counter_by_one(mock_client):
    mock_client.get_item.return_value = {"Item": {"numberVisitors": {"N": "99"}}}
    result = lambda_function.lambda_handler({}, {})
    body = json.loads(result["body"])
    assert body["numberVisitors"] == 100


def test_response_body_contains_number_visitors(mock_client):
    result = lambda_function.lambda_handler({}, {})
    body = json.loads(result["body"])
    assert "numberVisitors" in body
    assert isinstance(body["numberVisitors"], int)


def test_reads_from_correct_table_and_key(mock_client):
    lambda_function.lambda_handler({}, {})
    mock_client.get_item.assert_called_once_with(
        TableName="websiteTable",
        Key={"counter": {"S": "visitors"}},
        ProjectionExpression="numberVisitors",
    )


def test_writes_incremented_value_to_dynamodb(mock_client):
    mock_client.get_item.return_value = {"Item": {"numberVisitors": {"N": "10"}}}
    lambda_function.lambda_handler({}, {})
    mock_client.put_item.assert_called_once_with(
        TableName="websiteTable",
        Item={
            "counter": {"S": "visitors"},
            "numberVisitors": {"N": "11"},
        },
    )


def test_empty_table_starts_at_one(mock_client):
    mock_client.get_item.return_value = {}  # simulates a fresh table with no item
    result = lambda_function.lambda_handler({}, {})
    body = json.loads(result["body"])
    assert body["numberVisitors"] == 1


def test_dynamodb_get_error_propagates(mock_client):
    mock_client.get_item.side_effect = ClientError(
        {"Error": {"Code": "ResourceNotFoundException", "Message": "Table not found"}},
        "GetItem",
    )
    with pytest.raises(ClientError):
        lambda_function.lambda_handler({}, {})


def test_dynamodb_put_error_propagates(mock_client):
    mock_client.put_item.side_effect = ClientError(
        {"Error": {"Code": "ProvisionedThroughputExceededException", "Message": "Throughput exceeded"}},
        "PutItem",
    )
    with pytest.raises(ClientError):
        lambda_function.lambda_handler({}, {})
