{-# LANGUAGE ViewPatterns #-}

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module ZLogs.Application
    ( App (..)
    , runApp
    ) where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runStderrLoggingT)
import qualified Data.ByteString.Char8 as BS8
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Read as TextRead
import Data.Time (getCurrentTime)
import Database.Persist
import Database.Persist.Postgresql (withPostgresqlPool)
import Database.Persist.Sql
    ( ConnectionPool
    , SqlBackend
    , fromSqlKey
    , runMigration
    , runSqlPool
    )
import System.Environment (lookupEnv)
import Text.Blaze.Html (Html, toHtml)
import Text.Read (readMaybe)
import Yesod

import ZLogs.Model
import ZLogs.Processing

data App = App
    { appConnPool :: ConnectionPool
    }

mkYesod
    "App"
    [parseRoutes|
/ HomeR GET POST
/lotes BatchesR GET
/lotes/#LogBatchId BatchR GET
/lotes/#LogBatchId/excluir DeleteBatchR POST
/simulacao SimulateR GET POST
/benchmark BenchmarkR GET POST
/dashboard DashboardR GET
|]

instance Yesod App

instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend

    runDB action = do
        App pool <- getYesod
        runSqlPool action pool

runApp :: IO ()
runApp = do
    databaseUrl <- fromMaybe defaultConnectionString <$> lookupEnv "DATABASE_URL"
    port <- readEnvInt "PORT" 3000
    runStderrLoggingT $
        withPostgresqlPool (BS8.pack databaseUrl) 10 $ \pool ->
            liftIO $ do
                runSqlPool (runMigration migrateAll) pool
                warp port (App pool)

getHomeR :: Handler Html
getHomeR =
    page "Z-Logs - Upload" $ do
        [whamlet|
            <h1>Z-Logs
            <h2>Upload de Logs
            <form method=post action=@{HomeR}>
                <label for=logs>Logs textuais
                <br>
                <textarea id=logs name=logs rows=18 cols=100 placeholder="INFO Servico iniciado&#10;WARNING Latencia elevada&#10;ERROR Falha ao persistir registro"></textarea>
                <br>
                <button type=submit>Processar em paralelo
        |]

postHomeR :: Handler Html
postHomeR = do
    rawLogs <- fromMaybe "" <$> lookupPostParam "logs"
    (parsedLogs, processingMs) <- liftIO $ processLogsParallel $ normalizeLogInput rawLogs
    batchId <- saveProcessedBatch parsedLogs processingMs
    redirect $ BatchR batchId

getBatchesR :: Handler Html
getBatchesR = do
    batches <- runDB $ selectList ([] :: [Filter LogBatch]) [Desc LogBatchCreatedAt]
    page "Historico de Lotes" $ do
        [whamlet|
            <h1>Historico de Lotes
            $if null batches
                <p>Nenhum lote processado ainda.
            $else
                <table>
                    <thead>
                        <tr>
                            <th>ID
                            <th>Data
                            <th>Linhas
                            <th>Tempo de processamento
                            <th>Acoes
                    <tbody>
                        $forall Entity batchId batch <- batches
                            <tr>
                                <td>#{show (fromSqlKey batchId)}
                                <td>#{show (logBatchCreatedAt batch)}
                                <td>#{logBatchLineCount batch}
                                <td>#{logBatchProcessingTimeMs batch} ms
                                <td>
                                    <a href=@{BatchR batchId}>Detalhes
        |]

getBatchR :: LogBatchId -> Handler Html
getBatchR batchId = do
    batch <- runDB $ get404 batchId
    selectedLevel <- normalizeLevelFilter <$> lookupGetParam "tipo"
    let filters =
            [LogEntryBatchId ==. batchId]
                <> maybe [] (\level -> [LogEntryLevel ==. level]) selectedLevel
    entries <- runDB $ selectList filters [Asc LogEntryId]
    page "Detalhes do Lote" $ do
        [whamlet|
            <h1>Detalhes do Lote #{show (fromSqlKey batchId)}
            <p>Data: #{show (logBatchCreatedAt batch)}
            <p>Linhas: #{logBatchLineCount batch}
            <p>Tempo de processamento: #{logBatchProcessingTimeMs batch} ms

            <h2>Filtros
            <form method=get action=@{BatchR batchId}>
                <button type=submit>Todos
                $forall level <- allowedLogLevels
                    <button type=submit name=tipo value=#{level}>#{level}
            <p>Filtro atual: #{fromMaybe "Todos" selectedLevel}

            <h2>Logs processados
            $if null entries
                <p>Nenhum log encontrado para este filtro.
            $else
                <table>
                    <thead>
                        <tr>
                            <th>ID
                            <th>Tipo
                            <th>Mensagem
                            <th>Linha original
                    <tbody>
                        $forall Entity entryId entry <- entries
                            <tr>
                                <td>#{show (fromSqlKey entryId)}
                                <td>#{logEntryLevel entry}
                                <td>#{logEntryMessage entry}
                                <td>#{logEntryRawLine entry}

            <h2>CRUD
            <form method=post action=@{DeleteBatchR batchId}>
                <button type=submit>Excluir lote
        |]

postDeleteBatchR :: LogBatchId -> Handler Html
postDeleteBatchR batchId = do
    runDB $ do
        deleteWhere [LogEntryBatchId ==. batchId]
        delete batchId
    redirect BatchesR

getSimulateR :: Handler Html
getSimulateR =
    page "Simulacao de Carga" simulateForm

postSimulateR :: Handler Html
postSimulateR = do
    threadCount <- readBoundedPostInt "threads" 4 64
    logsPerThread <- readBoundedPostInt "logsPerThread" 500 100000
    generatedLogs <- liftIO $ generateSimulatedLogs threadCount logsPerThread
    (parsedLogs, processingMs) <- liftIO $ processLogsParallel generatedLogs
    batchId <- saveProcessedBatch parsedLogs processingMs
    page "Simulacao de Carga" $ do
        [whamlet|
            <h1>Simulacao de Carga
            <p>Threads executadas: #{threadCount}
            <p>Logs por thread: #{logsPerThread}
            <p>Total gerado: #{length generatedLogs}
            <p>Tempo de processamento paralelo: #{processingMs} ms
            <p>Lote gravado com ID #{show (fromSqlKey batchId)}.
            <p>
                <a href=@{BatchR batchId}>Abrir detalhes do lote
        |]

getBenchmarkR :: Handler Html
getBenchmarkR =
    page "Benchmark de Processamento" benchmarkForm

postBenchmarkR :: Handler Html
postBenchmarkR = do
    rawLogs <- fromMaybe "" <$> lookupPostParam "logs"
    sampleSize <- readBoundedPostInt "sampleSize" 10000 200000
    let providedLines = normalizeLogInput rawLogs
        inputLines =
            if null providedLines
                then generateSampleLogs sampleSize
                else providedLines
    result <- liftIO $ benchmarkProcessing inputLines
    page "Benchmark de Processamento" $ do
        [whamlet|
            <h1>Benchmark de Processamento
            <table>
                <tbody>
                    <tr>
                        <th>Linhas analisadas
                        <td>#{benchmarkLineCount result}
                    <tr>
                        <th>Processamento sequencial
                        <td>#{benchmarkSequentialMs result} ms
                    <tr>
                        <th>Processamento paralelo
                        <td>#{benchmarkParallelMs result} ms
                    <tr>
                        <th>Diferenca
                        <td>#{benchmarkSequentialMs result - benchmarkParallelMs result} ms
            <h2>Executar novamente
            ^{benchmarkForm}
        |]

getDashboardR :: Handler Html
getDashboardR = do
    ( totalBatches
        , totalEntries
        , infoCount
        , warningCount
        , errorCount
        , batches
        , latestBatch
        ) <-
        runDB $ do
            totalBatches <- count ([] :: [Filter LogBatch])
            totalEntries <- count ([] :: [Filter LogEntry])
            infoCount <- count [LogEntryLevel ==. "INFO"]
            warningCount <- count [LogEntryLevel ==. "WARNING"]
            errorCount <- count [LogEntryLevel ==. "ERROR"]
            batches <- selectList ([] :: [Filter LogBatch]) []
            latestBatch <- selectFirst ([] :: [Filter LogBatch]) [Desc LogBatchCreatedAt]
            pure
                ( totalBatches
                , totalEntries
                , infoCount
                , warningCount
                , errorCount
                , batches
                , latestBatch
                )
    let totalProcessingMs =
            sum [logBatchProcessingTimeMs batch | Entity _ batch <- batches]
        averageProcessingMs =
            if totalBatches == 0
                then 0
                else totalProcessingMs `div` totalBatches
    page "Dashboard Estatistico" $ do
        [whamlet|
            <h1>Dashboard Estatistico
            <h2>Metricas gerais
            <table>
                <tbody>
                    <tr>
                        <th>Total de lotes
                        <td>#{totalBatches}
                    <tr>
                        <th>Total de logs
                        <td>#{totalEntries}
                    <tr>
                        <th>Tempo medio por lote
                        <td>#{averageProcessingMs} ms
                    <tr>
                        <th>Ultimo lote
                        <td>
                            $maybe Entity latestId latest <- latestBatch
                                <a href=@{BatchR latestId}>#{show (fromSqlKey latestId)} - #{show (logBatchCreatedAt latest)}
                            $nothing
                                Nenhum lote

            <h2>Agrupamento por categoria
            <table>
                <thead>
                    <tr>
                        <th>Categoria
                        <th>Quantidade
                <tbody>
                    <tr>
                        <td>INFO
                        <td>#{infoCount}
                    <tr>
                        <td>WARNING
                        <td>#{warningCount}
                    <tr>
                        <td>ERROR
                        <td>#{errorCount}
        |]

page :: Text -> WidgetFor App () -> Handler Html
page title body =
    defaultLayout $ do
        setTitle (toHtml title)

        toWidgetHead
            [hamlet|
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

                <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

                <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

                <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js">
            |]

        toWidget
            [lucius|
                body {
                    background: #F7F4EC;
                    color: #1E2236;
                    font-family: 'Space Grotesk', sans-serif;
                }

                .sidebar {
                    min-height: 100vh;
                    background: linear-gradient(180deg,#2A3150,#1B223C);
                    color: white;
                }

                .nav-link {
                    color: white !important;
                }

                .content-area {
                    padding: 40px;
                }
            |]

        toWidget
            [whamlet|
                <div .container-fluid>
                    <div .row>

                        <aside .col-md-2.sidebar.text-white.p-4>
                            <h3 .mb-4>Z-Logs

                            <hr>

                            <div .nav.flex-column>
                                <a .nav-link href=@{DashboardR}>
                                    Dashboard

                                <a .nav-link href=@{HomeR}>
                                    Upload

                                <a .nav-link href=@{BatchesR}>
                                    Histórico

                                <a .nav-link href=@{BenchmarkR}>
                                    Benchmark

                                <a .nav-link href=@{SimulateR}>
                                    Simulação

                        <main .col-md-10.content-area>
                            ^{body}
            |]
simulateForm :: WidgetFor App ()
simulateForm =
    [whamlet|
        <h1>Simulacao de Carga
        <form method=post action=@{SimulateR}>
            <label for=threads>Threads simultaneas
            <br>
            <input id=threads type=number name=threads min=1 max=64 value=4>
            <br>
            <label for=logsPerThread>Logs por thread
            <br>
            <input id=logsPerThread type=number name=logsPerThread min=1 max=100000 value=500>
            <br>
            <button type=submit>Gerar carga concorrente
    |]

benchmarkForm :: WidgetFor App ()
benchmarkForm =
    [whamlet|
        <h1>Benchmark de Processamento
        <form method=post action=@{BenchmarkR}>
            <label for=logs>Logs para benchmark
            <br>
            <textarea id=logs name=logs rows=12 cols=100 placeholder="Opcional. Se ficar vazio, o sistema gera uma amostra automatica."></textarea>
            <br>
            <label for=sampleSize>Tamanho da amostra automatica
            <br>
            <input id=sampleSize type=number name=sampleSize min=1 max=200000 value=10000>
            <br>
            <button type=submit>Comparar sequencial vs paralelo
    |]

saveProcessedBatch :: [ParsedLog] -> Int -> Handler LogBatchId
saveProcessedBatch parsedLogs processingMs = do
    now <- liftIO getCurrentTime
    runDB $ do
        batchId <-
            insert $
                LogBatch
                    { logBatchCreatedAt = now
                    , logBatchLineCount = length parsedLogs
                    , logBatchProcessingTimeMs = processingMs
                    }
        insertMany_
            [ LogEntry
                { logEntryBatchId = batchId
                , logEntryLevel = parsedLogLevel parsedLog
                , logEntryMessage = parsedLogMessage parsedLog
                , logEntryRawLine = parsedLogRawLine parsedLog
                , logEntryCreatedAt = now
                }
            | parsedLog <- parsedLogs
            ]
        pure batchId

normalizeLevelFilter :: Maybe Text -> Maybe Text
normalizeLevelFilter maybeLevel = do
    level <- T.toUpper . T.strip <$> maybeLevel
    if level `elem` allowedLogLevels
        then Just level
        else Nothing

readBoundedPostInt :: Text -> Int -> Int -> Handler Int
readBoundedPostInt field fallback maximumValue = do
    maybeValue <- lookupPostParam field
    pure $ clamp 1 maximumValue $ fromMaybe fallback $ maybeValue >>= parsePositiveInt

parsePositiveInt :: Text -> Maybe Int
parsePositiveInt value =
    case TextRead.decimal $ T.strip value of
        Right (number, rest)
            | T.null rest && number > 0 -> Just number
        _ -> Nothing

clamp :: Int -> Int -> Int -> Int
clamp minimumValue maximumValue =
    max minimumValue . min maximumValue

readEnvInt :: String -> Int -> IO Int
readEnvInt name fallback = do
    maybeValue <- lookupEnv name
    pure $ fromMaybe fallback $ maybeValue >>= readMaybe

defaultConnectionString :: String
defaultConnectionString =
    "host=localhost port=5432 user=zlogs password=zlogs dbname=zlogs"
