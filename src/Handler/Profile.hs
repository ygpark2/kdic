{-# LANGUAGE OverloadedStrings #-}
module Handler.Profile
    ( getProfileR
    , getSettingsR
    ) where

import Import
import Handler.Common (serveFrontendPath)

getProfileR :: Handler TypedContent
getProfileR =
    serveFrontendPath ["profile"]

getSettingsR :: Handler Html
getSettingsR = redirect ProfileR
