{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Search where

import Import
import Handler.Common (serveFrontendPath)

getSearchR :: Handler TypedContent
getSearchR =
    serveFrontendPath ["search"]
