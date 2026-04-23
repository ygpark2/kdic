{-# LANGUAGE OverloadedStrings #-}
module Handler.Register where

import Import
import Handler.Common (serveFrontendPath)

getRegisterR :: Handler TypedContent
getRegisterR =
    serveFrontendPath ["register"]
