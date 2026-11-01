#!/usr/bin/env bash
set -euo pipefail

ORG="${ORG:-pos-fiap-michaelhion}"
REPO="${REPO:-tc_fiap_oficina360_database_infra}"
AWS_REGION="${AWS_REGION:-us-east-1}"

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

for command in aws gh; do
  command -v "$command" >/dev/null 2>&1 ||
    fail "$command nao encontrado."
done

gh auth status >/dev/null 2>&1 ||
  fail "GitHub CLI nao autenticado."

ACCOUNT_ID="$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)"

IDENTITY_ARN="$(
  aws sts get-caller-identity \
    --query Arn \
    --output text
)"

ORG_BUCKET="$(
  gh variable get TF_STATE_BUCKET \
    --org "$ORG" \
    2>/dev/null ||
  true
)"

REPO_BUCKET="$(
  gh variable get TF_STATE_BUCKET \
    --repo "$ORG/$REPO" \
    2>/dev/null ||
  true
)"

ORG_KEY="$(
  gh variable get TF_STATE_KEY \
    --org "$ORG" \
    2>/dev/null ||
  true
)"

REPO_KEY="$(
  gh variable get TF_STATE_KEY \
    --repo "$ORG/$REPO" \
    2>/dev/null ||
  true
)"

echo "===== IDENTIDADE ====="
echo "Account: $ACCOUNT_ID"
echo "Identity: $IDENTITY_ARN"

echo
echo "===== CONFIGURACAO GITHUB ====="
echo "Organization TF_STATE_BUCKET: ${ORG_BUCKET:-ausente}"
echo "Repository TF_STATE_BUCKET:   ${REPO_BUCKET:-ausente}"
echo "Organization TF_STATE_KEY:    ${ORG_KEY:-ausente}"
echo "Repository TF_STATE_KEY:      ${REPO_KEY:-ausente}"

if [[ -n "$REPO_BUCKET" ]]; then
  BUCKET="$REPO_BUCKET"
  echo "Bucket efetivo: $BUCKET (Repository Variable)"
else
  BUCKET="$ORG_BUCKET"
  echo "Bucket efetivo: $BUCKET (Organization Variable)"
fi

if [[ -n "$REPO_KEY" ]]; then
  STATE_KEY="$REPO_KEY"
else
  STATE_KEY="$ORG_KEY"
fi

: "${BUCKET:?TF_STATE_BUCKET nao definida}"
: "${STATE_KEY:?TF_STATE_KEY nao definida}"

echo "State key efetiva: $STATE_KEY"

echo
echo "===== BUCKETS VISIVEIS ====="

aws s3api list-buckets \
  --query \
    'Buckets[?contains(Name, `oficina360`) || contains(Name, `tfstate`)].{Name:Name,Created:CreationDate}' \
  --output table ||
true

echo
echo "===== HEAD BUCKET ====="

if aws s3api head-bucket \
  --bucket "$BUCKET" \
  2>/tmp/head-bucket.err; then

  echo "[OK] Bucket existe e esta acessivel."
else
  cat /tmp/head-bucket.err >&2

  echo
  echo "[ERRO] Bucket inexistente ou inacessivel."
  echo "Bucket: $BUCKET"

  echo
  echo "Possiveis causas:"
  echo "- bucket de outra conta;"
  echo "- Repository Variable antiga sobrescrevendo Organization Variable;"
  echo "- permissao s3:ListBucket ausente;"
  echo "- bucket nao existe mais."

  exit 1
fi

echo
echo "===== REGIAO ====="

BUCKET_LOCATION="$(
  aws s3api get-bucket-location \
    --bucket "$BUCKET" \
    --query LocationConstraint \
    --output text
)"

if [[ "$BUCKET_LOCATION" == "None" ]]; then
  BUCKET_LOCATION="us-east-1"
fi

echo "Regiao do bucket: $BUCKET_LOCATION"
echo "Regiao esperada:   $AWS_REGION"

[[ "$BUCKET_LOCATION" == "$AWS_REGION" ]] ||
  fail "Bucket esta em outra regiao."

echo
echo "===== VERSIONAMENTO ====="

aws s3api get-bucket-versioning \
  --bucket "$BUCKET" \
  --output json ||
true

echo
echo "===== ENCRIPTACAO ====="

aws s3api get-bucket-encryption \
  --bucket "$BUCKET" \
  --output json ||
true

echo
echo "===== TESTE DO PREFIXO ====="

PREFIX="${STATE_KEY%/*}"

aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "$PREFIX/" \
  --max-items 10 \
  --query 'Contents[].{Key:Key,Size:Size,Modified:LastModified}' \
  --output table ||
fail "Sem permissao para listar o prefixo do state."

echo
echo "[OK] Backend S3 acessivel."
