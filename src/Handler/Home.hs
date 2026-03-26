{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Home where

import Import
import qualified Data.Map as Map
import qualified Data.Text as T

getHomeR :: Handler Html
getHomeR = do
    latestComments <- runDB $ selectList [] [Desc WordCommentCreatedAt, LimitTo 10]
    
    -- Get words for these comments
    let wordIds = ordNub $ map (wordCommentWord . entityVal) latestComments
    words <- runDB $ selectList [WordId <-. wordIds] []
    let wordMap = Map.fromList $ map (\(Entity wid w) -> (wid, w)) words
    
    -- Get authors for these comments
    let authorIds = ordNub $ map (wordCommentAuthor . entityVal) latestComments
    authors <- runDB $ selectList [UserId <-. authorIds] []
    let authorMap = Map.fromList $ map (\(Entity uid u) -> (uid, u)) authors

    defaultLayout $ do
        setTitle "Dictionary SNS - Connect through words"
        $(widgetFile "homepage")
