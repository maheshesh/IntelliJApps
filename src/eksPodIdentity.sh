#!/bin/bash

# EKS Pod Identity setup for Velero
# This script sets up the required IAM role and Pod Identity association

# Variables - UPDATE THESE
CLUSTER_NAME="your-eks-cluster"
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="123456789012"  # Your AWS account ID
BUCKET_NAME="backupbucket"
ROLE_NAME="VeleroRole"
NAMESPACE="velero"
SERVICE_ACCOUNT_NAME="velero"

echo "=== Setting up EKS Pod Identity for Velero ==="

# 1. Create IAM Trust Policy for EKS Pod Identity
cat > velero-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF

# 2. Create IAM Policy for Velero (S3 only - no EBS snapshots for ST1)
cat > velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketVersioning",
                "s3:PutBucketVersioning",
                "s3:GetBucketLocation",
                "s3:ListBucketVersions",
                "s3:GetBucketNotification",
                "s3:PutBucketNotification"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}"
            ]
        }
    ]
}
EOF

echo "1. Creating IAM role..."
# Create IAM role
aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://velero-trust-policy.json \
    --region ${AWS_REGION}

echo "2. Creating and attaching IAM policy..."
# Create and attach policy
aws iam create-policy \
    --policy-name VeleroPolicy \
    --policy-document file://velero-policy.json \
    --region ${AWS_REGION}

aws iam attach-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/VeleroPolicy \
    --region ${AWS_REGION}

echo "3. Creating EKS Pod Identity association..."
# Create Pod Identity association
aws eks create-pod-identity-association \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${NAMESPACE} \
    --service-account ${SERVICE_ACCOUNT_NAME} \
    --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME} \
    --region ${AWS_REGION}

echo "4. Verifying Pod Identity association..."
aws eks list-pod-identity-associations \
    --cluster-name ${CLUSTER_NAME} \
    --region ${AWS_REGION}

# Clean up temporary files
rm -f velero-trust-policy.json velero-policy.json

echo ""
echo "=== EKS Pod Identity Setup Complete ==="
echo ""
echo "Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "Add this to your Helm values:"
echo "serviceAccount:"
echo "  server:"
echo "    annotations:"
echo "      eks.amazonaws.com/role-arn: \"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}\""
echo ""
echo "Note: It may take a few minutes for the Pod Identity association to be active."
