{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Home where

import Import
import Handler.Common (serveFrontendPath)

getHomeR :: Handler TypedContent
getHomeR =
    serveFrontendPath []
