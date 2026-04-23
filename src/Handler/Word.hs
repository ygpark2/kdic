{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Word where

import Import

getWordR :: WordId -> Handler Html
getWordR wordId =
    redirect $ FrontendWordDetailR wordId

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
