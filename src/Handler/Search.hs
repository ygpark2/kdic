{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Search where

import Import

getSearchR :: Handler Html
getSearchR = do
    mQuery <- lookupGetParam "q"
    redirect $ maybe
        (FrontendAppPathR ["search"], [] :: [(Text, Text)])
        (\queryText -> (FrontendAppPathR ["search"], [("q", queryText)]))
        mQuery
