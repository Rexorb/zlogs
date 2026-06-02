{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module ZLogs.Processing
    ( BenchmarkResult (..)
    , ParsedLog (..)
    , allowedLogLevels
    , benchmarkProcessing
    , generateSampleLogs
    , generateSimulatedLogs
    , normalizeLogInput
    , parseLogLine
    , processLogsParallel
    , processLogsSequential
    ) where

import Control.Concurrent (ThreadId, myThreadId)
import Control.Concurrent.Async (mapConcurrently, replicateConcurrently_)
import Control.Concurrent.MVar (modifyMVar_, newMVar, readMVar)
import Control.DeepSeq (NFData, force)
import Control.Exception (evaluate)
import Data.Char (isAlpha)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import GHC.Generics (Generic)

data ParsedLog = ParsedLog
    { parsedLogLevel :: Text
    , parsedLogMessage :: Text
    , parsedLogRawLine :: Text
    }
    deriving (Eq, Generic, Show)

instance NFData ParsedLog

data BenchmarkResult = BenchmarkResult
    { benchmarkLineCount :: Int
    , benchmarkSequentialMs :: Int
    , benchmarkParallelMs :: Int
    }
    deriving (Eq, Show)

allowedLogLevels :: [Text]
allowedLogLevels = ["INFO", "WARNING", "ERROR"]

normalizeLogInput :: Text -> [Text]
normalizeLogInput =
    filter (not . T.null) . fmap T.strip . T.lines

parseLogLine :: Text -> ParsedLog
parseLogLine rawLine =
    let trimmed = T.strip rawLine
        level = classifyLogLevel trimmed
    in ParsedLog
        { parsedLogLevel = level
        , parsedLogMessage = extractMessage level trimmed
        , parsedLogRawLine = rawLine
        }

processLogsSequential :: [Text] -> IO ([ParsedLog], Int)
processLogsSequential inputLines =
    timed $ evaluate $ force $ fmap parseLogLine inputLines

processLogsParallel :: [Text] -> IO ([ParsedLog], Int)
processLogsParallel inputLines =
    timed $ mapConcurrently (evaluate . force . parseLogLine) inputLines

benchmarkProcessing :: [Text] -> IO BenchmarkResult
benchmarkProcessing inputLines = do
    (_, sequentialMs) <- processLogsSequential inputLines
    (_, parallelMs) <- processLogsParallel inputLines
    pure BenchmarkResult
        { benchmarkLineCount = length inputLines
        , benchmarkSequentialMs = sequentialMs
        , benchmarkParallelMs = parallelMs
        }

generateSampleLogs :: Int -> [Text]
generateSampleLogs amount =
    fmap buildLine [1 .. amount]
  where
    buildLine index =
        sampleLevel index
            <> " Evento academico de benchmark #"
            <> T.pack (show index)
            <> " processado pelo Z-Logs"

    sampleLevel index =
        case index `mod` 6 of
            0 -> "ERROR"
            1 -> "WARNING"
            _ -> "INFO"

generateSimulatedLogs :: Int -> Int -> IO [Text]
generateSimulatedLogs threadCount logsPerThread = do
    chunksVar <- newMVar []
    replicateConcurrently_ threadCount $ do
        threadId <- myThreadId
        let chunk = buildThreadLogs threadId logsPerThread
        forcedChunk <- evaluate $ force chunk
        modifyMVar_ chunksVar $ \chunks -> pure (forcedChunk : chunks)
    chunks <- readMVar chunksVar
    pure $ concat $ reverse chunks

buildThreadLogs :: ThreadId -> Int -> [Text]
buildThreadLogs threadId logsPerThread =
    fmap buildLine [1 .. logsPerThread]
  where
    threadLabel = T.pack $ show threadId

    buildLine index =
        sampleLevel index
            <> " thread="
            <> threadLabel
            <> " linha="
            <> T.pack (show index)
            <> " carga concorrente simulada"

    sampleLevel index =
        case index `mod` 5 of
            0 -> "ERROR"
            1 -> "WARNING"
            _ -> "INFO"

classifyLogLevel :: Text -> Text
classifyLogLevel line
    | "ERROR" `T.isInfixOf` normalized = "ERROR"
    | "WARNING" `T.isInfixOf` normalized = "WARNING"
    | "WARN" `T.isInfixOf` normalized = "WARNING"
    | otherwise = "INFO"
  where
    normalized = T.toUpper line

extractMessage :: Text -> Text -> Text
extractMessage level line =
    case T.words line of
        [] -> ""
        token : rest
            | tokenMatchesLevel level token -> T.unwords rest
        _ -> line

tokenMatchesLevel :: Text -> Text -> Bool
tokenMatchesLevel level token =
    normalizedToken == level
        || (level == "WARNING" && normalizedToken == "WARN")
  where
    normalizedToken = T.filter isAlpha $ T.toUpper token

timed :: IO a -> IO (a, Int)
timed action = do
    startedAt <- getCurrentTime
    result <- action
    finishedAt <- getCurrentTime
    pure (result, millisecondsBetween startedAt finishedAt)

millisecondsBetween :: UTCTime -> UTCTime -> Int
millisecondsBetween startedAt finishedAt =
    max 0 $ floor elapsedMilliseconds
  where
    elapsedSeconds = realToFrac $ diffUTCTime finishedAt startedAt :: Double
    elapsedMilliseconds = elapsedSeconds * 1000
