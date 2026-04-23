-- | Common handler functions.
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Handler.Common where

import Import
import qualified Data.ByteString.Char8 as BS
import Data.FileEmbed (embedFile)
import System.Directory (doesFileExist)
import System.FilePath (takeExtension)
import qualified System.FilePath as FP

-- These handlers embed files in the executable at compile time to avoid a
-- runtime dependency, and for efficiency.

getFaviconR :: Handler TypedContent
getFaviconR = return $ TypedContent (BS.pack "image/x-icon")
                     $ toContent $(embedFile "config/favicon.ico")

getRobotsR :: Handler TypedContent
getRobotsR = return $ TypedContent typePlain
                     $ toContent $(embedFile "config/robots.txt")

getFrontendAssetR :: [Text] -> Handler TypedContent
getFrontendAssetR pieces =
    serveFrontendPath ("_app" : pieces)

getFrontendNewWordR :: Handler TypedContent
getFrontendNewWordR =
    serveFrontendPath ["new-word"]

getFrontendLoginR :: Handler TypedContent
getFrontendLoginR =
    serveFrontendPath ["login"]

getFrontendWordDetailR :: WordId -> Handler TypedContent
getFrontendWordDetailR wordId =
    serveFrontendPath ["words", toPathPiece wordId]

serveFrontendPath :: [Text] -> Handler TypedContent
serveFrontendPath pieces = do
    app <- getYesod
    let staticRoot = appStaticDir $ appSettings app
        frontendRoot = staticRoot FP.</> "app"
        relativePath = FP.joinPath $ map unpack pieces
        requestedPath =
            if null pieces
                then frontendRoot FP.</> "index.html"
                else frontendRoot FP.</> relativePath
        fallbackPath = frontendRoot FP.</> "index.html"
    fallbackExists <- liftIO $ doesFileExist fallbackPath
    unless fallbackExists notFound
    requestedExists <- liftIO $ doesFileExist requestedPath
    let targetPath = if requestedExists then requestedPath else fallbackPath
        contentType = frontendContentType targetPath
    sendFile contentType targetPath

frontendContentType :: FilePath -> ContentType
frontendContentType path =
    case takeExtension path of
        ".html" -> "text/html; charset=utf-8"
        ".js" -> "application/javascript; charset=utf-8"
        ".css" -> "text/css; charset=utf-8"
        ".json" -> "application/json"
        ".svg" -> "image/svg+xml"
        ".png" -> "image/png"
        ".jpg" -> "image/jpeg"
        ".jpeg" -> "image/jpeg"
        ".webp" -> "image/webp"
        ".woff" -> "font/woff"
        ".woff2" -> "font/woff2"
        _ -> "application/octet-stream"
