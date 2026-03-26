{-# LANGUAGE OverloadedStrings #-}
module Storage
  ( StorageBackendType(..)
  , Storage(..)
  , mkStorage
  ) where

import ClassyPrelude.Yesod
import qualified Data.Text as T
import System.Directory (createDirectoryIfMissing, doesFileExist, getTemporaryDirectory, removeFile)
import System.FilePath ((</>), takeDirectory, takeExtension)
import Data.UUID.V4 (nextRandom)
import Data.UUID (toText)
import System.Environment (getEnvironment)
import System.Process (CreateProcess(..), proc, readCreateProcessWithExitCode)
import System.Exit (ExitCode (..))
import qualified System.IO as IO

import Settings (AppSettings(..))


data StorageBackendType = StorageBackendLocal | StorageBackendS3
  deriving (Eq, Show)

data Storage site = Storage
  { storageBackendType :: StorageBackendType
  , storagePut  :: FileInfo -> Text -> HandlerFor site Text
  , storageOpen :: Text -> HandlerFor site (Maybe (ContentType, FilePath))
  , storageUrl  :: Text -> HandlerFor site Text
  }

mkStorage :: AppSettings -> IO (Storage site)
mkStorage settings =
  case appStorageBackend settings of
    "s3" -> mkS3Storage settings
    _    -> mkLocalStorage settings

mkLocalStorage :: AppSettings -> IO (Storage site)
mkLocalStorage settings = do
  let root = appStorageLocalRootDir settings
      base = appStorageLocalPublicBase settings
  pure Storage
    { storageBackendType = StorageBackendLocal
    , storagePut = \fi prefix -> do
        key <- liftIO $ randomKeyWithExt fi
        let fullKey = prefix <> "/" <> key
            path = root </> T.unpack fullKey
        liftIO $ createDirectoryIfMissing True (takeDirectory path)
        liftIO $ fileMove fi path
        pure fullKey
    , storageOpen = \key -> do
        let path = root </> T.unpack key
        exists <- liftIO $ doesFileExist path
        if not exists
          then pure Nothing
          else pure $ Just ("application/octet-stream", path)
    , storageUrl = \key -> pure (base <> "/" <> key)
    }

mkS3Storage :: AppSettings -> IO (Storage site)
mkS3Storage settings = do
  let bucketText = fromMaybe "" (appStorageS3Bucket settings)
      regionText = fromMaybe "ap-northeast-2" (appStorageS3Region settings)
      endpoint = appStorageS3Endpoint settings
      forcePathStyle = appStorageS3ForcePathStyle settings
      pubBase = appStorageS3PublicBase settings
  pure Storage
    { storageBackendType = StorageBackendS3
    , storagePut = \fi prefix -> do
        key <- liftIO $ randomKeyWithExt fi
        let fullKey = prefix <> "/" <> key
        tmpDir <- liftIO getTemporaryDirectory
        (tmp, h) <- liftIO $ IO.openTempFile tmpDir "upload"
        liftIO $ IO.hClose h
        liftIO $ fileMove fi tmp
        let baseArgs = ["s3api", "put-object", "--bucket", unpack bucketText, "--key", unpack fullKey, "--body", tmp]
            args = case endpoint of
              Just ep | ep /= "" -> baseArgs <> ["--endpoint-url", unpack ep]
              _ -> baseArgs
        baseEnv <- liftIO getEnvironment
        let envVars =
              if forcePathStyle
                then Just (("AWS_S3_FORCE_PATH_STYLE", "true") : baseEnv)
                else Nothing
        (code, _out, err) <- liftIO $ readCreateProcessWithExitCode (proc "aws" args) { env = envVars } ""
        liftIO $ removeFile tmp `catchAny` \_ -> pure ()
        case code of
          ExitSuccess -> pure fullKey
          ExitFailure _ -> throwString ("S3 upload failed: " <> err)
    , storageOpen = \_ -> pure Nothing
    , storageUrl = \key ->
        case pubBase of
          Just b | b /= "" -> pure (b <> "/" <> key)
          _ ->
            case endpoint of
              Just ep | ep /= "" -> pure (ep <> "/" <> bucketText <> "/" <> key)
              _ -> pure ("https://" <> bucketText <> ".s3." <> regionText <> ".amazonaws.com/" <> key)
    }

randomKeyWithExt :: FileInfo -> IO Text
randomKeyWithExt fi = do
  u <- nextRandom
  let ext = takeExtension (unpack (fileName fi))
  pure (toText u <> T.pack ext)
