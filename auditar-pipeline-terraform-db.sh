#!/usr/bin/env bash
set -uo pipefail

ROOT="${1:-.}"
WORKFLOW="${WORKFLOW:-.github/workflows/terraform.yml}"
TF_DIR="${TF_DIR:-infra}"
ORG="${ORG:-pos-fiap-michaelhion}"
REPO="${REPO:-tc_fiap_oficina360_database_infra}"
REPORT="${REPORT:-auditoria-pipeline-terraform-db.txt}"
RUN_AWS_TESTS="${RUN_AWS_TESTS:-true}"

PASS=0
WARN=0
FAIL=0

section() { printf '\n===== %s =====\n' "$*"; }
pass() { PASS=$((PASS + 1)); printf '[OK] %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '[AVISO] %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[ERRO] %s\n' "$*"; }

ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || {
  echo "[ERRO] Diretorio invalido: $ROOT" >&2
  exit 2
}
cd "$ROOT"

exec > >(tee "$REPORT") 2>&1

section "CONTEXTO"
echo "Repositorio: $ROOT"
echo "Workflow: $WORKFLOW"
echo "Modulo Terraform: $TF_DIR"
echo "Organizacao: $ORG"
echo "Repositorio GitHub: $REPO"

section "DEPENDENCIAS"
for command_name in bash git terraform aws gh jq python3; do
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "$command_name encontrado"
  else
    fail "$command_name nao encontrado"
  fi
done

section "ARQUIVOS"
[[ -f "$WORKFLOW" ]] && pass "Workflow encontrado" || fail "Workflow ausente: $WORKFLOW"
[[ -d "$TF_DIR" ]] && pass "Modulo Terraform encontrado" || fail "Modulo ausente: $TF_DIR"
[[ -f "$TF_DIR/variables.tf" ]] && pass "variables.tf encontrado" || fail "variables.tf ausente"

section "SINTAXE YAML"
if [[ -f "$WORKFLOW" ]]; then
  if python3 - "$WORKFLOW" <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("PyYAML nao instalado")
    raise SystemExit(3)
with open(sys.argv[1], encoding="utf-8") as stream:
    yaml.safe_load(stream)
print("YAML valido")
PY
  then
    pass "Workflow possui YAML valido"
  else
    fail "Workflow possui YAML invalido ou PyYAML esta ausente"
  fi
fi

section "ORDEM DOS STEPS"
if [[ -f "$WORKFLOW" ]]; then
  grep -nE '^      - name:' "$WORKFLOW" || true

  line_of() {
    grep -nF -- "- name: $1" "$WORKFLOW" | head -n 1 | cut -d: -f1
  }

  CRED_LINE="$(line_of 'Configure AWS credentials')"
  NET_LINE="$(line_of 'Configure Terraform network variables')"
  BACKEND_LINE="$(line_of 'Validate backend access')"
  INIT_LINE="$(line_of 'Terraform Init')"
  PLAN_LINE="$(line_of 'Terraform Plan')"
  APPLY_LINE="$(line_of 'Terraform Apply')"

  [[ -n "$CRED_LINE" && -n "$NET_LINE" && "$CRED_LINE" -lt "$NET_LINE" ]] \
    && pass "Credenciais AWS antes das variaveis de rede" \
    || fail "Configure AWS credentials deve ocorrer antes da configuracao de rede"

  [[ -n "$NET_LINE" && -n "$PLAN_LINE" && "$NET_LINE" -lt "$PLAN_LINE" ]] \
    && pass "Variaveis de rede antes do plan" \
    || fail "Variaveis de rede devem ser configuradas antes do Terraform Plan"

  [[ -n "$BACKEND_LINE" && -n "$INIT_LINE" && "$BACKEND_LINE" -lt "$INIT_LINE" ]] \
    && pass "Backend validado antes do init" \
    || fail "Validacao do backend deve ocorrer antes do Terraform Init"

  [[ -n "$PLAN_LINE" && -n "$APPLY_LINE" && "$PLAN_LINE" -lt "$APPLY_LINE" ]] \
    && pass "Plan antes do apply" \
    || fail "Terraform Plan deve ocorrer antes do Terraform Apply"
fi

section "REFERENCIAS PERIGOSAS NO WORKFLOW"
if [[ -f "$WORKFLOW" ]]; then
  if grep -n 'describe-security-groups' "$WORKFLOW"; then
    fail "Workflow chama ec2:DescribeSecurityGroups, bloqueado no Learner Lab atual"
  else
    pass "Workflow nao chama DescribeSecurityGroups"
  fi

  if grep -n 'list-buckets' "$WORKFLOW"; then
    fail "Workflow chama s3:ListAllMyBuckets, bloqueado no Learner Lab"
  else
    pass "Workflow nao chama ListBuckets"
  fi

  if grep -nE 'TF_STATE_BUCKET:.*\$\{\{[[:space:]]*secrets\.' "$WORKFLOW"; then
    warn "TF_STATE_BUCKET esta como Secret; use Variable"
  else
    pass "TF_STATE_BUCKET nao esta configurado como Secret"
  fi

  if grep -n '\*\*\*' "$WORKFLOW"; then
    warn "Workflow contem asteriscos literais"
  else
    pass "Nenhum asterisco triplo literal no workflow"
  fi
fi

section "CONTRATO TERRAFORM"
EXPECTED_VARS=(vpc_id subnet_ids database_access_security_group_id)
LEGACY_VARS=(subnet_a_id default_security_group_id)

for name in "${EXPECTED_VARS[@]}"; do
  COUNT="$(grep -Rhs --include='*.tf' --exclude-dir=.terraform -E "^[[:space:]]*variable[[:space:]]+\"${name}\"" "$TF_DIR" | wc -l | tr -d ' ')"
  if [[ "$COUNT" == "1" ]]; then
    pass "variable $name declarada uma vez"
  elif [[ "$COUNT" == "0" ]]; then
    fail "variable $name nao declarada"
  else
    fail "variable $name declarada $COUNT vezes"
  fi
done

for name in "${LEGACY_VARS[@]}"; do
  DECLARED="$(grep -Rhs --include='*.tf' --exclude-dir=.terraform -E "^[[:space:]]*variable[[:space:]]+\"${name}\"" "$TF_DIR" | wc -l | tr -d ' ')"
  USED="$(grep -Rhs --include='*.tf' --exclude-dir=.terraform -E "var\.${name}\b" "$TF_DIR" | wc -l | tr -d ' ')"
  if [[ "$DECLARED" != "0" && "$USED" == "0" ]]; then
    warn "variable legada $name declarada mas nao usada"
  elif [[ "$USED" != "0" ]]; then
    warn "variable legada $name ainda usada"
  else
    pass "variable legada $name nao esta ativa"
  fi
done

if grep -Rni --include='*.tf' --exclude-dir=.terraform 'local\.subnet_ids' "$TF_DIR"; then
  fail "Ainda existe local.subnet_ids; use var.subnet_ids"
else
  pass "Nenhuma referencia local.subnet_ids"
fi

if grep -Rni --include='*.tf' --exclude-dir=.terraform -E 'data[[:space:]]+"aws_ssm_parameter"' "$TF_DIR"; then
  fail "Ainda existem data sources SSM"
else
  pass "Nenhum data source SSM"
fi

if grep -Rni --include='*.tf' --exclude-dir=.terraform -E 'default[[:space:]]*=[[:space:]]*"(vpc-|subnet-|sg-)' "$TF_DIR"; then
  fail "Existem IDs AWS hardcoded em defaults"
else
  pass "Nenhum ID AWS hardcoded em defaults"
fi

section "FORMATACAO E VALIDACAO TERRAFORM"
if command -v terraform >/dev/null 2>&1 && [[ -d "$TF_DIR" ]]; then
  terraform -chdir="$TF_DIR" fmt -check -recursive \
    && pass "terraform fmt -check passou" \
    || fail "terraform fmt -check falhou"

  if terraform -chdir="$TF_DIR" init -backend=false -input=false >/tmp/tf-db-init.log 2>&1; then
    pass "terraform init -backend=false passou"
  else
    fail "terraform init -backend=false falhou"
    tail -n 40 /tmp/tf-db-init.log || true
  fi

  if terraform -chdir="$TF_DIR" validate -no-color >/tmp/tf-db-validate.log 2>&1; then
    pass "terraform validate passou"
  else
    fail "terraform validate falhou"
    cat /tmp/tf-db-validate.log || true
  fi
fi

section "GITHUB VARIABLES"
GH_AVAILABLE=false
BUCKET_VALUE=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_AVAILABLE=true
  ORG_VARS="$(gh variable list --org "$ORG" --json name,value 2>/dev/null || printf '[]')"
  REPO_VARS="$(gh variable list --repo "$ORG/$REPO" --json name,value 2>/dev/null || printf '[]')"

  get_gh_var() {
    local name="$1"
    local value
    value="$(jq -r --arg n "$name" '.[] | select(.name == $n) | .value' <<< "$REPO_VARS" | head -n 1)"
    if [[ -z "$value" ]]; then
      value="$(jq -r --arg n "$name" '.[] | select(.name == $n) | .value' <<< "$ORG_VARS" | head -n 1)"
    fi
    printf '%s' "$value"
  }

  VPC_ID_VALUE="$(get_gh_var VPC_ID)"
  SUBNET_IDS_VALUE="$(get_gh_var SUBNET_IDS)"
  [[ -n "$SUBNET_IDS_VALUE" ]] || SUBNET_IDS_VALUE="$(get_gh_var LAMBDA_SUBNET_IDS)"
  ACCESS_SG_VALUE="$(get_gh_var LAMBDA_SECURITY_GROUP_ID)"
  DEFAULT_SG_VALUE="$(get_gh_var DEFAULT_SECURITY_GROUP_ID)"
  BUCKET_VALUE="$(get_gh_var TF_STATE_BUCKET)"
  KEY_VALUE="$(get_gh_var TF_STATE_KEY)"

  for item in \
    "VPC_ID=$VPC_ID_VALUE" \
    "SUBNET_IDS=$SUBNET_IDS_VALUE" \
    "LAMBDA_SECURITY_GROUP_ID=$ACCESS_SG_VALUE" \
    "DEFAULT_SECURITY_GROUP_ID=$DEFAULT_SG_VALUE" \
    "TF_STATE_BUCKET=$BUCKET_VALUE" \
    "TF_STATE_KEY=$KEY_VALUE"; do
    name="${item%%=*}"
    value="${item#*=}"
    [[ -n "$value" ]] && echo "$name=$value" || echo "$name=<ausente>"
  done

  [[ "$VPC_ID_VALUE" =~ ^vpc-[0-9a-f]+$ ]] && pass "VPC_ID valida" || fail "VPC_ID ausente ou invalida"
  [[ "$SUBNET_IDS_VALUE" =~ ^subnet-[0-9a-f]+(,subnet-[0-9a-f]+)+$ ]] && pass "Lista de subnets valida" || fail "Subnets ausentes ou invalidas"
  [[ "$ACCESS_SG_VALUE" =~ ^sg-[0-9a-f]+$ ]] && pass "LAMBDA_SECURITY_GROUP_ID valida" || fail "LAMBDA_SECURITY_GROUP_ID ausente ou invalida"
  if [[ -n "$DEFAULT_SG_VALUE" ]]; then
    if [[ "$DEFAULT_SG_VALUE" =~ ^sg-[0-9a-f]+$ ]]; then
      pass "DEFAULT_SECURITY_GROUP_ID valida, embora seja opcional"
    else
      warn "DEFAULT_SECURITY_GROUP_ID definida com formato invalido"
    fi
  else
    pass "DEFAULT_SECURITY_GROUP_ID nao e necessaria no contrato atual"
  fi
  [[ -n "$BUCKET_VALUE" ]] && pass "TF_STATE_BUCKET definida" || warn "TF_STATE_BUCKET ausente"
  [[ -n "$KEY_VALUE" ]] && pass "TF_STATE_KEY definida" || warn "TF_STATE_KEY ausente"
else
  warn "GitHub CLI nao autenticado"
fi

section "AWS E PERMISSOES"
if [[ "$RUN_AWS_TESTS" == "true" ]] && command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
  echo "Account=$ACCOUNT_ID"
  echo "Caller=$CALLER_ARN"
  pass "Credenciais AWS validas"

  test_permission() {
    local description="$1"
    shift
    local output status
    output="$("$@" 2>&1)"
    status=$?
    if [[ "$status" -eq 0 ]]; then
      pass "$description"
    elif grep -qiE 'explicit deny|UnauthorizedOperation|AccessDenied|Forbidden' <<< "$output"; then
      warn "$description bloqueada pela politica do laboratorio"
      printf '%s\n' "$output" | tail -n 4
    else
      fail "$description falhou"
      printf '%s\n' "$output" | tail -n 4
    fi
  }

  test_permission "ec2:DescribeSecurityGroups" aws ec2 describe-security-groups --max-items 1
  test_permission "ec2:DescribeSubnets" aws ec2 describe-subnets --max-items 1

  BACKEND_BUCKET="$BUCKET_VALUE"
  [[ -n "$BACKEND_BUCKET" ]] || BACKEND_BUCKET="oficina360-tfstate-${ACCOUNT_ID}-us-east-1"
  test_permission "s3:HeadBucket em $BACKEND_BUCKET" aws s3api head-bucket --bucket "$BACKEND_BUCKET"
else
  warn "Testes AWS ignorados"
fi

section "SOLUCAO PROPOSTA"
echo "1. Remover describe-security-groups do workflow."
echo "2. Tornar DEFAULT_SECURITY_GROUP_ID obrigatoria."
echo "3. Usar VPC_ID, SUBNET_IDS, LAMBDA_SECURITY_GROUP_ID e DEFAULT_SECURITY_GROUP_ID como entradas."
echo "4. Remover variaveis legadas nao usadas."
echo "5. Manter subnet_ids = var.subnet_ids no DB subnet group."
echo "6. Executar validate sem backend."
echo "7. Executar deploy e destroy com backend S3 e plan salvo."
echo "8. Um explicit deny nao pode ser contornado pelo Terraform."

section "RESUMO"
echo "OK=$PASS"
echo "AVISOS=$WARN"
echo "ERROS=$FAIL"
echo "Relatorio=$REPORT"

[[ "$FAIL" -eq 0 ]]
