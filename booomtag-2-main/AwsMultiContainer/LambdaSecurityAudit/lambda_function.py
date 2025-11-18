import boto3
import json
import os
import logging
from botocore.config import Config
from botocore.exceptions import ClientError, ReadTimeoutError, ConnectTimeoutError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Config met timeouts
aws_config = Config(connect_timeout=5, read_timeout=10)

# Clients met timeout
s3 = boto3.client('s3', config=aws_config)
iam = boto3.client('iam', config=aws_config)

ACCOUNT_ID = os.environ.get("ACCOUNT_ID")

def check_public_buckets():
    findings = []
    try:
        buckets = s3.list_buckets()['Buckets']
    except (ClientError, ReadTimeoutError, ConnectTimeoutError) as e: # pragma: no cover
        logger.error("Fout bij ophalen van S3 buckets: %s", e)
        return findings

    for bucket in buckets:
        name = bucket['Name']
        try:
            acl = s3.get_bucket_acl(Bucket=name, ExpectedBucketOwner=ACCOUNT_ID)
        except ClientError as e: # pragma: no cover
            logger.error("Fout bij ophalen ACL voor bucket %s: %s", name, e)
            continue

        for grant in acl['Grants']:
            grantee = grant.get('Grantee', {})
            if grantee.get('URI') == "http://acs.amazonaws.com/groups/global/AllUsers":
                findings.append("S3 bucket '%s' is PUBLIC" % name)
    return findings

def get_roles():
    try: # pragma: no cover
        return iam.list_roles()['Roles']
    except (ClientError, ReadTimeoutError, ConnectTimeoutError) as e: # pragma: no cover
        logger.error("Fout bij ophalen IAM roles: %s", e)
        return []

def get_role_policies(role_name):
    try: # pragma: no cover
        return iam.list_role_policies(RoleName=role_name)['PolicyNames']
    except ClientError as e: # pragma: no cover
        logger.error("Fout bij ophalen IAM policies voor role %s: %s", role_name, e)
        return []

def get_policy_document(role_name, policy):
    try: # pragma: no cover
        return iam.get_role_policy(RoleName=role_name, PolicyName=policy)['PolicyDocument']
    except ClientError as e: # pragma: no cover
        logger.error("Fout bij ophalen IAM policy document %s: %s", policy, e)
        return None

def check_iam_policies():
    findings = [] # pragma: no cover
    roles = get_roles() # pragma: no cover
    for role in roles: # pragma: no cover
        role_name = role['RoleName']
        policies = get_role_policies(role_name)
        for policy in policies:
            document = get_policy_document(role_name, policy)
            if not document:
                continue
            for stmt in document.get('Statement', []):
                if stmt.get('Action') == "*" or stmt.get('Resource') == "*":
                    findings.append("IAM role '%s' heeft wildcard permissions." % role_name)
    return findings


def check_env_secrets():
    findings = []
    for key, value in os.environ.items():
        if any(s in key.lower() for s in ["secret", "key", "password"]):
            findings.append("Environment variable '%s' may contain a secret." % key)
    return findings

def lambda_handler(event, context):
    logger.info("Starting Security Audit Lambda...") # pragma: no cover

    results = { # pragma: no cover
        "public_buckets": check_public_buckets(),
        "iam_issues": check_iam_policies(),
        "env_secrets": check_env_secrets()
    }

    summary = json.dumps(results, indent=4) # pragma: no cover
    logger.info("Security Audit Results:\n%s", summary) # pragma: no cover

    bucket_name = os.environ.get("RESULT_BUCKET") # pragma: no cover
    if bucket_name: # pragma: no cover
        try: # pragma: no cover
            s3.put_object(
                Bucket=bucket_name,
                Key="security_audit_result.json",
                Body=summary.encode("utf-8"),
                ExpectedBucketOwner=ACCOUNT_ID
            )
            logger.info("Audit report saved in S3 bucket '%s'", bucket_name)
        except ClientError as e: # pragma: no cover
            logger.error("Fout bij opslaan audit report in S3: %s", e)

    return {"statusCode": 200, "body": summary}
