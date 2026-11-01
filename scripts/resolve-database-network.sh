#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-oficina360}"
ENVIRONMENT="${ENVIRONMENT:-lab}"
GITHUB_ENV_FILE="${GITHUB_ENV:-}"
GITHUB_OUTPUT_FILE="${GITHUB_OUTPUT:-}"

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

mask() {
  if [[ -n "${1:-}" ]]; then
    printf '::add-mask::%s\n' "$1"
  fi
}

for command_name in aws jq; do
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "$command_name nao encontrado"
done

aws sts get-caller-identity --output json >/dev/null 2>&1 ||
  fail "Credenciais AWS invalidas ou expiradas"

VPCS_JSON="$(
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters \
      "Name=state,Values=available" \
      "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
      "Name=tag:Project,Values=${PROJECT_NAME}" \
      "Name=tag:Environment,Values=${ENVIRONMENT}" \
    --output json
)"

VPC_COUNT="$(jq '.Vpcs | length' <<< "$VPCS_JSON")"

if [[ "$VPC_COUNT" -ne 1 ]]; then
  fail "Era esperada exatamente uma VPC atual; encontradas: $VPC_COUNT"
fi

VPC_ID="$(jq -r '.Vpcs[0].VpcId' <<< "$VPCS_JSON")"
[[ "$VPC_ID" =~ ^vpc-[0-9a-f]+$ ]] || fail "VPC descoberta possui formato invalido"
mask "$VPC_ID"

SUBNETS_JSON="$(
  aws ec2 describe-subnets \
    --region "$AWS_REGION" \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=state,Values=available" \
      "Name=tag:kubernetes.io/role/elb,Values=1" \
    --output json
)"

SUBNET_COUNT="$(jq '.Subnets | length' <<< "$SUBNETS_JSON")"
AZ_COUNT="$(jq '[.Subnets[].AvailabilityZone] | unique | length' <<< "$SUBNETS_JSON")"

if [[ "$SUBNET_COUNT" -lt 2 ]]; then
  fail "A VPC atual possui menos de duas subnets validas para o RDS"
fi

if [[ "$AZ_COUNT" -lt 2 ]]; then
  fail "As subnets do RDS precisam estar em pelo menos duas Availability Zones"
fi

SUBNET_IDS_JSON="$(
  jq -c '[.Subnets | sort_by(.AvailabilityZone, .SubnetId) | .[].SubnetId]' \
    <<< "$SUBNETS_JSON"
)"

while IFS= read -r subnet_id; do
  [[ "$subnet_id" =~ ^subnet-[0-9a-f]+$ ]] || fail "Subnet descoberta possui formato invalido"
  mask "$subnet_id"
done < <(jq -r '.[]' <<< "$SUBNET_IDS_JSON")

SGS_JSON="$(
  aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=group-name,Values=${PROJECT_NAME}-database-access" \
    --output json
)"

SG_COUNT="$(jq '.SecurityGroups | length' <<< "$SGS_JSON")"

if [[ "$SG_COUNT" -ne 1 ]]; then
  fail "Era esperado exatamente um Security Group de acesso ao banco; encontrados: $SG_COUNT"
fi

DATABASE_ACCESS_SECURITY_GROUP_ID="$(
  jq -r '.SecurityGroups[0].GroupId' <<< "$SGS_JSON"
)"

[[ "$DATABASE_ACCESS_SECURITY_GROUP_ID" =~ ^sg-[0-9a-f]+$ ]] ||
  fail "Security Group descoberto possui formato invalido"

mask "$DATABASE_ACCESS_SECURITY_GROUP_ID"

if [[ -n "$GITHUB_ENV_FILE" ]]; then
  {
    printf 'TF_VAR_vpc_id=%s\n' "$VPC_ID"
    printf 'TF_VAR_subnet_ids=%s\n' "$SUBNET_IDS_JSON"
    printf 'TF_VAR_database_access_security_group_id=%s\n' "$DATABASE_ACCESS_SECURITY_GROUP_ID"
  } >> "$GITHUB_ENV_FILE"
fi

if [[ -n "$GITHUB_OUTPUT_FILE" ]]; then
  {
    printf 'subnet_count=%s\n' "$SUBNET_COUNT"
    printf 'availability_zone_count=%s\n' "$AZ_COUNT"
  } >> "$GITHUB_OUTPUT_FILE"
fi

printf 'Rede atual descoberta e validada.\n'
printf 'Subnets selecionadas: %s\n' "$SUBNET_COUNT"
printf 'Availability Zones: %s\n' "$AZ_COUNT"
