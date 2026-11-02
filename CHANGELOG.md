# Changelog

Todas as alterações relevantes deste projeto serão documentadas neste arquivo.

O formato segue o padrão **Keep a Changelog** e o projeto utiliza **Versionamento Semântico** no formato `MAJOR.MINOR.PATCH`.

## [Unreleased]

### Added

- Espaço reservado para novas funcionalidades ainda não publicadas.

### Changed

- Espaço reservado para alterações ainda não publicadas.

### Fixed

- Espaço reservado para correções ainda não publicadas.

### Security

- Espaço reservado para melhorias de segurança ainda não publicadas.

## [1.0.0] - 2026-11-02

Primeira versão estável da infraestrutura de banco de dados da Oficina360 para a Fase 3 do Tech Challenge.

### Added

- Provisionamento do PostgreSQL gerenciado no Amazon RDS.
- Configuração do DB Subnet Group para implantação do banco na rede da plataforma.
- Integração do RDS com a VPC e as subnets configuradas para o ambiente.
- Configuração de parâmetros do banco por Terraform.
- Configuração do provider AWS e das versões mínimas utilizadas pelo Terraform.
- Configuração do backend remoto do Terraform.
- Definição de variáveis, valores locais e outputs da infraestrutura.
- Script `scripts/bootstrap-state.sh` para preparação do backend remoto.
- Script `scripts/resolve-database-network.sh` para resolução dos recursos de rede utilizados pelo banco.
- Ambiente PostgreSQL local com Docker Compose.
- Documentação para execução local em `docs/rodar-local.md`.
- Pipeline principal de Terraform em `.github/workflows/terraform.yml`.
- Pipeline auxiliar de testes e validações em `.github/workflows/teste.yml`.
- README com propósito, tecnologias, arquitetura específica, execução, deploy e links para Swagger e Postman da aplicação.
- Diagrama Mermaid da arquitetura específica do repositório.
- Instruções de validação, diagnóstico e destruição da infraestrutura.

### Changed

- Padronização da documentação do repositório conforme os requisitos da entrega acadêmica.
- Separação explícita entre infraestrutura de banco, aplicação principal, Lambda e infraestrutura Kubernetes.
- Organização dos arquivos Terraform por responsabilidade: backend, provider, versões, variáveis, parâmetros, subnet group, RDS e outputs.
- Documentação do fluxo local com Docker separada do fluxo de deploy no Amazon RDS.

### Fixed

- Correção e complementação das instruções de execução e deploy.
- Correção da documentação sobre arquivos que não devem ser versionados, incluindo `.terraform/`, `.idea/` e arquivos `.env`.
- Orientação para manter `.terraform.lock.hcl` versionado.
- Inclusão de orientações para evitar exposição de credenciais e dados sensíveis.

### Security

- Uso de GitHub Secrets para credenciais AWS e credenciais do banco.
- Orientação para restringir o Security Group do RDS às origens autorizadas.
- Orientação para evitar exposição pública desnecessária do banco.
- Proteção da branch `main` contra commits diretos.
- Uso de Pull Requests e checks automatizados antes da integração.
- Exclusão de arquivos locais e sensíveis por meio do `.gitignore`.
- Orientação para não publicar senha, string de conexão ou outputs sensíveis.

## Política de versionamento

O projeto utiliza o formato:

```text
vMAJOR.MINOR.PATCH
```

- **MAJOR:** alteração incompatível ou mudança estrutural relevante na arquitetura do banco.
- **MINOR:** nova capacidade compatível, como backups adicionais, réplica de leitura ou novos parâmetros.
- **PATCH:** correção compatível em Terraform, pipeline, scripts ou documentação.

Exemplos:

```text
v1.0.0    primeira versão estável
v1.1.0    nova funcionalidade compatível
v1.1.1    correção de configuração ou documentação
v2.0.0    alteração incompatível na arquitetura
```

## Processo de release

1. Registrar as mudanças novas na seção `Unreleased`.
2. Abrir um Pull Request da branch de release para a branch `main`.
3. Aguardar a execução dos checks obrigatórios.
4. Atualizar a seção `Unreleased` para a nova versão e incluir a data.
5. Fazer o merge do Pull Request.
6. Criar uma tag anotada no commit da versão.
7. Publicar uma GitHub Release com o resumo das mudanças.
8. Recriar a seção `Unreleased` para o próximo ciclo.

### Criar a primeira tag

Após integrar a versão final na branch `main`:

```bash
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Oficina360 Database Infrastructure v1.0.0"
git push origin v1.0.0
```

### Consultar versões

```bash
git tag --list --sort=-version:refname
git show v1.0.0
```

### Comparar versões

```bash
git diff v1.0.0..HEAD
```

## Categorias utilizadas

- `Added`: novas funcionalidades ou recursos.
- `Changed`: alterações em funcionalidades existentes.
- `Deprecated`: funcionalidades que serão removidas futuramente.
- `Removed`: funcionalidades removidas.
- `Fixed`: correções de problemas.
- `Security`: correções ou melhorias de segurança.
