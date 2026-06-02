{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DataKinds #-}

{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module ZLogs.Model where

import Data.Text (Text)
import Data.Time (UTCTime)
import Database.Persist.TH

share
    [mkPersist sqlSettings, mkMigrate "migrateAll"]
    [persistLowerCase|
LogBatch
    createdAt UTCTime
    lineCount Int
    processingTimeMs Int
    deriving Show

LogEntry
    batchId LogBatchId
    level Text
    message Text
    rawLine Text
    createdAt UTCTime
    deriving Show
|]
