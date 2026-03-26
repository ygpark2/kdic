{-# LANGUAGE OverloadedStrings #-}
module Handler.Upload (postUploadR, getFileR) where

import Import
import Storage (StorageBackendType(..), storagePut, storageOpen, storageUrl)
import Data.Time (getCurrentTime)

uploadForm :: Html -> MForm Handler (FormResult FileInfo, Widget)
uploadForm = renderDivs $ fileAFormReq $ FieldSettings
    { fsLabel = "file"
    , fsTooltip = Nothing
    , fsId = Nothing
    , fsName = Nothing
    , fsAttrs = []
    }

postUploadR :: Handler Value
postUploadR = do
    uid <- requireAuthId
    storage <- getsYesod appStorage
    now <- liftIO getCurrentTime
    ((res, _), _) <- runFormPost uploadForm
    case res of
        FormSuccess fi -> do
            let prefix = "users/" <> toPathPiece uid
            key <- storagePut storage fi prefix
            _ <- runDB $ insert $ Upload
                { uploadOwnerId = uid
                , uploadStorageKey = key
                , uploadOriginalName = fileName fi
                , uploadContentType = Just (fileContentType fi)
                , uploadSizeBytes = Nothing
                , uploadCreatedAt = now
                }
            url <- storageUrl storage key
            returnJson $ object ["url" .= url]
        _ -> sendResponseStatus status400 (object ["error" .= ("upload_failed" :: Text)])

getFileR :: Text -> Handler TypedContent
getFileR key = do
    storage <- getsYesod appStorage
    backend <- getsYesod appStorageBackendType
    case backend of
        StorageBackendLocal -> do
            m <- storageOpen storage key
            case m of
                Nothing -> notFound
                Just (ct, path) -> sendFile ct path
        StorageBackendS3 -> do
            url <- storageUrl storage key
            redirect url
