-- | Common handler functions.
{-# LANGUAGE TemplateHaskell #-}
module Handler.Common where

import Import
import qualified Data.ByteString.Char8 as BS
import Data.FileEmbed (embedFile)

-- These handlers embed files in the executable at compile time to avoid a
-- runtime dependency, and for efficiency.

getFaviconR :: Handler TypedContent
getFaviconR = return $ TypedContent (BS.pack "image/x-icon")
                     $ toContent $(embedFile "config/favicon.ico")

getRobotsR :: Handler TypedContent
getRobotsR = return $ TypedContent typePlain
                    $ toContent $(embedFile "config/robots.txt")
