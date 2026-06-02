# Z-Logs

Sistema de processamento concorrente de logs desenvolvido em Haskell utilizando o framework Yesod e banco de dados PostgreSQL.

## Sobre o Projeto

O Z-Logs foi desenvolvido com o objetivo de demonstrar conceitos de concorrência, processamento paralelo, persistência de dados e desenvolvimento web funcional utilizando Haskell.

O sistema permite:

- Upload de logs textuais.
- Processamento paralelo utilizando múltiplas threads.
- Classificação automática de logs.
- Armazenamento em banco de dados PostgreSQL.
- Consulta histórica de lotes processados.
- Benchmark comparando execução sequencial e paralela.
- Simulação de carga concorrente.
- Dashboard estatístico.

O projeto foi desenvolvido como atividade acadêmica para demonstrar conceitos relacionados a:

- Arquitetura de Software.
- Programação Funcional.
- Concorrência.
- Persistência de Dados.
- Sistemas Web.

---

## Tecnologias Utilizadas

### Backend

- Haskell
- Yesod Framework
- Persistent
- PostgreSQL

### Concorrência

- Control.Concurrent
- Async
- MVar

### Banco de Dados

- PostgreSQL 15

### Containerização

- Docker
- Docker Compose

---

## Estrutura do Projeto

```text
ZLogs/
│
├── app/
│   └── Main.hs
│
├── src/
│   └── ZLogs/
│       ├── Application.hs
│       ├── Model.hs
│       └── Processing.hs
│
├── Dockerfile
├── docker-compose.yml
├── zlogs.cabal
├── cabal.project
└── README.md
```

---

## Funcionalidades

### Upload de Logs

Permite que o usuário envie múltiplas linhas contendo registros de log.

Exemplo:

```text
INFO Serviço iniciado
WARNING Latência elevada
ERROR Falha ao persistir registro
```

---

### Processamento Paralelo

Os logs são processados utilizando múltiplas threads.

Trecho responsável:

```haskell
processLogsParallel :: [Text] -> IO ([ParsedLog], Int)
processLogsParallel inputLines =
    timed $ mapConcurrently
        (evaluate . force . parseLogLine)
        inputLines
```

Cada linha é processada simultaneamente, reduzindo o tempo total de execução.

---

### Classificação Automática

O sistema identifica automaticamente:

- INFO
- WARNING
- ERROR

Trecho responsável:

```haskell
classifyLogLevel :: Text -> Text
classifyLogLevel line
    | "ERROR" `T.isInfixOf` normalized = "ERROR"
    | "WARNING" `T.isInfixOf` normalized = "WARNING"
    | "WARN" `T.isInfixOf` normalized = "WARNING"
    | otherwise = "INFO"
```

---

### Persistência

Após o processamento, os logs são gravados no PostgreSQL.

Entidades:

```haskell
LogBatch
    createdAt UTCTime
    lineCount Int
    processingTimeMs Int

LogEntry
    batchId LogBatchId
    level Text
    message Text
    rawLine Text
```

---

### Dashboard

Apresenta indicadores como:

- Total de lotes processados.
- Total de logs armazenados.
- Quantidade de INFO.
- Quantidade de WARNING.
- Quantidade de ERROR.
- Tempo médio de processamento.

---

### Benchmark

Permite comparar:

- Processamento Sequencial
- Processamento Paralelo

Objetivo:

Demonstrar o ganho de desempenho obtido através do uso de concorrência.

---

### Simulação de Carga

Gera milhares de logs automaticamente para testes de estresse.

O usuário informa:

- Quantidade de Threads
- Quantidade de Logs por Thread

---

## Como Executar Localmente

### Pré-requisitos

Instalar:

- GHC
- Cabal
- PostgreSQL

Verificar versões:

```bash
ghc --version
cabal --version
psql --version
```

---

### Criar Banco de Dados

Entrar no PostgreSQL:

```sql
CREATE DATABASE zlogs;

CREATE USER zlogs WITH PASSWORD 'zlogs';

GRANT ALL PRIVILEGES ON DATABASE zlogs TO zlogs;
```

---

### Compilar Projeto

```bash
cabal update
cabal build
```

---

### Executar

```bash
cabal run
```

A aplicação ficará disponível em:

```text
http://localhost:3000
```

---

## Executando com Docker

### Construir Containers

```bash
docker compose build
```

---

### Subir Ambiente

```bash
docker compose up -d
```

---

### Verificar Containers

```bash
docker ps
```

Deverão existir:

```text
zlogs-app
zlogs-db
```

---

### Acessar Aplicação

```text
http://localhost:3000
```

---

### Parar Ambiente

```bash
docker compose down
```

---

## Arquitetura

```text
Usuário
   │
   ▼
Yesod Web Server
   │
   ▼
Processamento Paralelo
   │
   ▼
Persistência
(PostgreSQL)
   │
   ▼
Dashboard / Histórico
```

---

## Objetivos Acadêmicos Demonstrados

- Programação Funcional.
- Desenvolvimento Web com Haskell.
- Persistência de Dados.
- Banco PostgreSQL.
- Concorrência.
- Processamento Paralelo.
- Benchmark de Performance.
- Containerização com Docker.
- Arquitetura em Camadas.

---

## Integrantes

- Integrante 1
- Integrante 2
- Roberto Henrique dos Santos

---

## Licença

Projeto desenvolvido exclusivamente para fins acadêmicos.
