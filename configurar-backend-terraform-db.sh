#!/usr/bin/env bash
set -euo pipefail

ORG="${ORG:-pos-fiap-michaelhion}"
REPO="${REPO:-tc_fiap_oficina360_database_infra}"
AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_KEY="${TF_STATE_KEY:-oficina360/database/lab.tfstate}"
APPLY="${APPLY:-false}"

log() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
fail() { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

for cmd in aws gh jq; do
  command -v "$cmd" >/dev/null 2>&1 || fail "$cmd nao encontrado"
done

aws sts get-caller-identity >/dev/null 2>&1 || fail "AWS CLI nao autenticada"
gh auth status >/dev/null 2>&1 || fail "GitHub CLI nao autenticada"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
EXPECTED_BUCKET="oficina360-tfstate-${ACCOUNT_ID}-${AWS_REGION}"

echo "===== IDENTIDADE ====="
echo "AWS account: $ACCOUNT_ID"
echo "AWS region: $AWS_REGION"
echo "Bucket esperado: $EXPECTED_BUCKET"
echo "State key: $TF_STATE_KEY"

echo
echo "===== BUCKETS CANDIDATOS ====="
BUCKETS_JSON="$(aws s3api list-buckets --output json)"
jq -r '.Buckets[].Name | select(contains("oficina360") and contains("tfstate"))' <<< "$BUCKETS_JSON" || true

ACCESSIBLE_BUCKET=""
while IFS= read -r bucket; do
  [[ -n "$bucket" ]] || continue
  if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
    location="$(aws s3api get-bucket-location --bucket "$bucket" --query LocationConstraint --output text 2>/dev/null || true)"
    [[ "$location" == "None" ]] && location="us-east-1"
    echo "[OK] $bucket regiao=$location"
    if [[ "$bucket" == "$EXPECTED_BUCKET" && "$location" == "$AWS_REGION" ]]; then
      ACCESSIBLE_BUCKET="$bucket"
    elif [[ -z "$ACCESSIBLE_BUCKET" && "$location" == "$AWS_REGION" ]]; then
      ACCESSIBLE_BUCKET="$bucket"
    fi
  else
    echo "[SEM ACESSO] $bucket"
  fi
done < <(jq -r '.Buckets[].Name | select(contains("oficina360") and contains("tfstate"))' <<< "$BUCKETS_JSON")

if [[ -z "$ACCESSIBLE_BUCKET" ]]; then
  fail "Nenhum bucket tfstate acessivel em $AWS_REGION. Nao crie outro antes de verificar as permissoes do Learner Lab."
fi

echo
echo "Bucket selecionado: $ACCESSIBLE_BUCKET"

# Verifica acesso ao prefixo usado pelo backend.
PREFIX="${TF_STATE_KEY%/*}/"
aws s3api list-objects-v2 \
  --bucket "$ACCESSIBLE_BUCKET" \
  --prefix "$PREFIX" \
  --max-items 5 \
  --query 'Contents[].Key' \
  --output text >/dev/null || fail "Sem acesso ao prefixo $PREFIX"

if [[ "$APPLY" != "true" ]]; then
  echo
  log "Dry-run. Nenhuma GitHub Variable foi alterada."
  echo "Para publicar: APPLY=true bash $0"
  exit 0
fi

gh variable set TF_STATE_BUCKET \
  --org "$ORG" \
  --repos "$REPO" \
  --body "$ACCESSIBLE_BUCKET"

gh variable set TF_STATE_KEY \
  --org "$ORG" \
  --repos "$REPO" \
  --body "$TF_STATE_KEY"

# Remove copias locais que poderiam sobrescrever as variables organizacionais.
gh variable delete TF_STATE_BUCKET --repo "$ORG/$REPO" 2>/dev/null || true
gh variable delete TF_STATE_KEY --repo "$ORG/$REPO" 2>/dev/null || true

echo
echo "===== CONFIRMACAO ====="
gh variable list --org "$ORG" | grep -E '^(TF_STATE_BUCKET|TF_STATE_KEY)[[:space:]]'

ok "Backend do banco publicado como Organization Variables."
echo "Inicie uma nova execucao do workflow."
