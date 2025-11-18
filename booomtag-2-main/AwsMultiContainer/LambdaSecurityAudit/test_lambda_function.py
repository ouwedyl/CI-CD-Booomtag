# test_lambda_function.py
import os
import json
import pytest
from unittest.mock import patch, MagicMock
from lambda_function import check_public_buckets, check_iam_policies, check_env_secrets, lambda_handler

os.environ["RESULT_BUCKET"] = "test-bucket"
os.environ["ACCOUNT_ID"] = "123456789012"

def test_check_env_secrets(monkeypatch):
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "dummy")
    monkeypatch.setenv("CUSTOM_KEY", "dummy")
    findings = check_env_secrets()
    assert any("AWS_SECRET_ACCESS_KEY" in f for f in findings)
    assert any("CUSTOM_KEY" in f for f in findings)

@patch("lambda_function.s3")
def test_check_public_buckets(mock_s3):
    # Mock S3 list_buckets en get_bucket_acl
    mock_s3.list_buckets.return_value = {"Buckets": [{"Name": "test-bucket"}]}
    mock_s3.get_bucket_acl.return_value = {"Grants": [{"Grantee": {"URI": "http://acs.amazonaws.com/groups/global/AllUsers"}}]}

    findings = check_public_buckets()
    assert any("PUBLIC" in f for f in findings)

@patch("lambda_function.iam")
def test_check_iam_policies(mock_iam):
    # Mock IAM list_roles, list_role_policies en get_role_policy
    mock_iam.list_roles.return_value = {"Roles": [{"RoleName": "TestRole"}]}
    mock_iam.list_role_policies.return_value = {"PolicyNames": ["TestPolicy"]}
    mock_iam.get_role_policy.return_value = {
        "PolicyDocument": {
            "Statement": [
                {"Effect": "Allow", "Action": "*", "Resource": "*"}
            ]
        }
    }

    findings = check_iam_policies()
    assert any("IAM role" in f for f in findings)

@patch("lambda_function.s3")
def test_lambda_handler(mock_s3):
    # Mock S3 and IAM functions
    mock_s3.list_buckets.return_value = {"Buckets": [{"Name": "test-bucket"}]}
    mock_s3.get_bucket_acl.return_value = {"Grants": [{"Grantee": {"URI": "http://acs.amazonaws.com/groups/global/AllUsers"}}]}
    
    with patch("lambda_function.iam") as mock_iam:
        mock_iam.list_roles.return_value = {"Roles": [{"RoleName": "TestRole"}]}
        mock_iam.list_role_policies.return_value = {"PolicyNames": ["TestPolicy"]}
        mock_iam.get_role_policy.return_value = {
            "PolicyDocument": {
                "Statement": [
                    {"Effect": "Allow", "Action": "*", "Resource": "*"}
                ]
            }
        }

        monkeypatch = pytest.MonkeyPatch()
        monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "dummy")
        monkeypatch.setenv("CUSTOM_KEY", "dummy")

        event = {}
        context = {}
        response = lambda_handler(event, context)
        body = json.loads(response["body"])

        assert any("PUBLIC" in f for f in body["public_buckets"])
        assert any("IAM role" in f for f in body["iam_issues"])
        assert any("AWS_SECRET_ACCESS_KEY" in f for f in body["env_secrets"])
        assert any("CUSTOM_KEY" in f for f in body["env_secrets"])
