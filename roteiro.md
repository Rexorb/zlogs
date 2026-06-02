Z-Logs: Sistema de Processamento Paralelo de Logs com Haskell, Yesod e PostgreSQL
1. Introdução

O projeto Z-Logs foi desenvolvido com o objetivo de demonstrar a aplicação prática de conceitos de programação concorrente e processamento paralelo em um sistema web real.

A proposta consiste em receber grandes volumes de logs textuais, classificá-los automaticamente, armazená-los em banco de dados e disponibilizar informações estatísticas através de uma interface web.

O sistema foi implementado utilizando a linguagem Haskell, o framework Yesod para desenvolvimento web e PostgreSQL para persistência de dados.

Além da simples classificação de logs, o projeto também demonstra o impacto da execução paralela em comparação ao processamento sequencial, permitindo realizar benchmarks de desempenho.

2. Objetivos do Projeto

O sistema foi construído com os seguintes objetivos:

Processar logs textuais automaticamente.
Classificar mensagens em diferentes categorias.
Armazenar informações de forma persistente.
Utilizar concorrência e paralelismo para aumentar desempenho.
Demonstrar comparação entre execução sequencial e paralela.
Disponibilizar métricas estatísticas através de interface web.
3. Arquitetura Geral

O projeto foi dividido em três camadas principais:

Camada Web (Application.hs)

Responsável por:

Rotas da aplicação
Interface do usuário
Recebimento de formulários
Integração com banco de dados
Renderização das páginas

Principais rotas:

/ HomeR GET POST
/lotes BatchesR GET
/lotes/#LogBatchId BatchR GET
/lotes/#LogBatchId/excluir DeleteBatchR POST
/simulacao SimulateR GET POST
/benchmark BenchmarkR GET POST
/dashboard DashboardR GET

Essas rotas representam as funcionalidades disponíveis para o usuário.

Camada de Persistência (Model.hs)

Responsável por definir a estrutura dos dados armazenados.

Entidade LogBatch

Representa um lote de processamento.

LogBatch
    createdAt UTCTime
    lineCount Int
    processingTimeMs Int

Campos:

createdAt: data do processamento
lineCount: quantidade de linhas processadas
processingTimeMs: tempo gasto
Entidade LogEntry

Representa cada log individual.

LogEntry
    batchId LogBatchId
    level Text
    message Text
    rawLine Text
    createdAt UTCTime

Campos:

batchId: relacionamento com lote
level: categoria do log
message: conteúdo processado
rawLine: linha original
createdAt: data de criação
Camada de Processamento (Processing.hs)

Responsável pela lógica de negócio.

Funções:

classificação dos logs
benchmark
simulação de carga
processamento paralelo
processamento sequencial
4. Funcionamento do Sistema
Etapa 1: Upload

O usuário envia um conjunto de logs.

Exemplo:

INFO Sistema iniciado
WARNING Uso elevado de memória
ERROR Falha ao conectar no banco

A rota responsável é:

postHomeR
Etapa 2: Normalização

Os dados são tratados.

normalizeLogInput

Função:

normalizeLogInput =
    filter (not . T.null)
    . fmap T.strip
    . T.lines

Responsável por:

separar linhas
remover espaços
eliminar linhas vazias
Etapa 3: Classificação

Cada linha é analisada.

parseLogLine

A classificação utiliza:

classifyLogLevel

Trecho:

classifyLogLevel line
    | "ERROR" `T.isInfixOf` normalized = "ERROR"
    | "WARNING" `T.isInfixOf` normalized = "WARNING"
    | "WARN" `T.isInfixOf` normalized = "WARNING"
    | otherwise = "INFO"

Categorias suportadas:

INFO
WARNING
ERROR
5. Programação Concorrente

Uma das partes mais importantes do projeto é o uso de concorrência.

O processamento paralelo ocorre através da biblioteca Async.

Trecho principal:

processLogsParallel inputLines =
    timed $
        mapConcurrently
            (evaluate . force . parseLogLine)
            inputLines
O que é mapConcurrently?

A função:

mapConcurrently

executa várias tarefas simultaneamente.

Em vez de processar:

Log 1
Log 2
Log 3
Log 4

um após o outro, o sistema distribui as tarefas entre múltiplas threads.

Exemplo:

Thread 1 -> Log 1
Thread 2 -> Log 2
Thread 3 -> Log 3
Thread 4 -> Log 4

Isso reduz significativamente o tempo total de processamento.

6. Processamento Sequencial

Para comparação foi implementada uma versão sequencial.

processLogsSequential inputLines =
    timed $
        evaluate $
            force $
                fmap parseLogLine inputLines

Nesse caso:

Log 1
↓
Log 2
↓
Log 3
↓
Log 4

Tudo ocorre em uma única thread.

7. Benchmark

O sistema permite comparar os dois métodos.

Função:

benchmarkProcessing

Trecho:

(_, sequentialMs) <- processLogsSequential inputLines
(_, parallelMs) <- processLogsParallel inputLines

O resultado exibe:

quantidade de linhas
tempo sequencial
tempo paralelo
diferença de desempenho
8. Simulação de Carga

O sistema gera milhares de logs automaticamente.

Função:

generateSimulatedLogs

Trecho:

replicateConcurrently_ threadCount

Essa função cria várias threads simultaneamente.

Exemplo:

Thread 1 -> 1000 logs
Thread 2 -> 1000 logs
Thread 3 -> 1000 logs
Thread 4 -> 1000 logs

Total:

4000 logs

Essa funcionalidade foi criada para demonstrar concorrência em ambiente controlado.

9. Persistência em Banco de Dados

O projeto utiliza PostgreSQL.

Conexão:

withPostgresqlPool

Migração automática:

runMigration migrateAll

Sempre que o sistema inicia:

conecta ao banco
verifica tabelas
cria estruturas faltantes
10. Dashboard Estatístico

O Dashboard realiza consultas agregadas.

Exemplo:

totalBatches <- count []
totalEntries <- count []

Métricas exibidas:

Total de lotes
Total de logs
Quantidade de INFO
Quantidade de WARNING
Quantidade de ERROR
Tempo médio de processamento
11. CRUD

O sistema implementa operações básicas de persistência.

Create:

insert

Read:

selectList

Update:

Não utilizado neste projeto.

Delete:

deleteWhere
delete
12. Interface Web

O frontend foi desenvolvido utilizando:

Yesod Hamlet
Lucius
Bootstrap 5

A interface fornece:

Upload de logs
Dashboard
Histórico
Benchmark
Simulação

Tudo acessível via navegador.

13. Tecnologias Utilizadas

Linguagem:

Haskell

Framework Web:

Yesod

Banco de Dados:

PostgreSQL

Persistência:

Persistent

Concorrência:

Async
MVar
Threads

Frontend:

Hamlet
Lucius
Bootstrap
14. Conclusão

O projeto Z-Logs demonstra a aplicação prática dos conceitos de programação funcional, concorrência e persistência de dados.

A utilização de processamento paralelo através de múltiplas threads permite reduzir o tempo de análise de grandes volumes de logs, evidenciando as vantagens da programação concorrente em cenários de processamento intensivo.

Além disso, o sistema integra tecnologias modernas para construção de aplicações web, oferecendo uma solução completa composta por interface gráfica, processamento paralelo, persistência em banco de dados e geração de métricas estatísticas.

O resultado é uma aplicação capaz de demonstrar, de forma prática e mensurável, os benefícios do paralelismo em sistemas computacionais modernos.
