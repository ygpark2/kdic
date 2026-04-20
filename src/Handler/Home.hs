{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude, QuasiQuotes #-}
module Handler.Home where

import Import
import qualified Data.Map as Map
import qualified Data.Text as T

getHomeR :: Handler Html
getHomeR = do
    mViewerId <- maybeAuthId
    latestComments <- runDB $ selectList [] [Desc WordCommentCreatedAt, LimitTo 10]
    totalWords <- runDB $ count ([] :: [Filter Word])
    totalStories <- runDB $ count ([] :: [Filter WordComment])
    totalMembers <- runDB $ count ([] :: [Filter User])
    
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
        toWidgetHead [hamlet|
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap" rel="stylesheet">
        |]
        $(widgetFile "homepage")
