#!/usr/bin/env bash

set -Eeuo pipefail

AWS_REGION="us-east-1"
BUCKET_NAME="${1:-}"

if [[ -z "${BUCKET_NAME}" ]]; then
  echo "Uso:"
  echo "  ./scripts/bootstrap-state.sh <bucket-name>"
  exit 1
fi

echo "Criando bucket: ${BUCKET_NAME}"

aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${AWS_REGION}"

echo "Habilitando versionamento..."

aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "Bloqueando acesso público..."

aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Habilitando criptografia padrão..."

aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

echo
echo "Bucket criado:"
echo "  ${BUCKET_NAME}"
echo
echo "Backend:"
echo "  key = database/terraform.tfstate"