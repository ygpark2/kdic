{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Search where

import Import
import qualified Data.Text as T

getSearchR :: Handler Html
getSearchR = do
    mQuery <- lookupGetParam "q"
    words <- case mQuery of
        Nothing -> return []
        Just q -> runDB $ selectList [WordText ==. q] [Asc WordText, LimitTo 50]
    
    defaultLayout $ do
        setTitle "Search Results"
        $(widgetFile "search")
