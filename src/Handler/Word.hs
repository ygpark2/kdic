{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Word where

import Import
import Data.Time (getCurrentTime)
import qualified Data.Map as Map
import qualified Data.Text as T

getWordR :: WordId -> Handler Html
getWordR wordId = do
    word <- runDB $ get404 wordId
    meanings <- runDB $ selectList [MeaningWord ==. wordId] []
    let meaningIds = map entityKey meanings
    examples <- runDB $ selectList [ExampleMeaning <-. meaningIds] []
    comments <- runDB $ selectList [WordCommentWord ==. wordId] [Desc WordCommentCreatedAt]
    
    let meaningsWithExamples = map (\(Entity mid m) -> (Entity mid m, filter (\(Entity _ ex) -> exampleMeaning ex == mid) examples)) meanings

    -- Get author information for comments
    let authorIds = ordNub $ map (wordCommentAuthor . entityVal) comments
    authors <- runDB $ selectList [UserId <-. authorIds] []
    let authorMap = Map.fromList $ map (\(Entity uid u) -> (uid, u)) authors
    
    mUserId <- maybeAuthId
    isLiked <- case mUserId of
        Nothing -> return False
        Just uid -> runDB $ exists [WordLikeUser ==. uid, WordLikeWord ==. wordId]
        
    isBookmarked <- case mUserId of
        Nothing -> return False
        Just uid -> runDB $ exists [WordBookmarkUser ==. uid, WordBookmarkWord ==. wordId]

    let likeClass = if isLiked 
                        then "bg-red-50 text-red-600 border border-red-200" :: Text 
                        else "bg-white text-slate-400 border border-slate-200 hover:text-slate-600"
    let bookmarkClass = if isBookmarked 
                            then "bg-amber-50 text-amber-600 border border-amber-200" :: Text 
                            else "bg-white text-slate-400 border border-slate-200 hover:text-slate-600"

    defaultLayout $ do
        setTitle $ toHtml $ wordText word
        $(widgetFile "word")

postWordCommentR :: WordId -> Handler Html
postWordCommentR wordId = do
    uid <- requireAuthId
    content <- runInputPost $ ireq textField "content"
    mParentId <- runInputPost $ iopt textField "parentId"
    let parentId = mParentId >>= fromPathPiece
    now <- liftIO getCurrentTime
    _ <- runDB $ insert $ WordComment wordId uid content parentId now now
    setMessage "Comment posted!"
    redirect $ WordR wordId

postWordLikeR :: WordId -> Handler Html
postWordLikeR wordId = do
    uid <- requireAuthId
    mLike <- runDB $ getBy $ UniqueWordLike uid wordId
    case mLike of
        Just (Entity lid _) -> runDB $ delete lid
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordLike uid wordId now
            return ()
    redirect $ WordR wordId

postWordBookmarkR :: WordId -> Handler Html
postWordBookmarkR wordId = do
    uid <- requireAuthId
    mBookmark <- runDB $ getBy $ UniqueWordBookmark uid wordId
    case mBookmark of
        Just (Entity bid _) -> runDB $ delete bid
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordBookmark uid wordId now
            return ()
    redirect $ WordR wordId

postWordCommentDeleteR :: WordCommentId -> Handler Html
postWordCommentDeleteR commentId = do
    uid <- requireAuthId
    comment <- runDB $ get404 commentId
    if wordCommentAuthor comment == uid
        then do
            runDB $ delete commentId
            setMessage "Comment deleted."
        else
            setMessage "You can only delete your own comments."
    redirect $ WordR (wordCommentWord comment)
