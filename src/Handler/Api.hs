{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api where

import Import
import Database.Persist.Sql (fromSqlKey)
import Data.Time (getCurrentTime)
import Handler.Api.Shared
import Network.HTTP.Types.Status (status400, status403)
import Yesod.Auth (Creds (..), clearCreds, setCreds)
import Yesod.Auth.HashDB (setPassword, validatePass)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

getApiHomeR :: Handler Value
getApiHomeR = do
    mViewer <- maybeAuth
    latestComments <- runDB $ selectList [] [Desc WordCommentCreatedAt, LimitTo 12]
    totalWords <- runDB $ count ([] :: [Filter Word])
    totalStories <- runDB $ count ([] :: [Filter WordComment])
    totalMembers <- runDB $ count ([] :: [Filter User])
    popularWords <- runDB $ selectList [] [Asc WordText, LimitTo 5]
    mDailyWord <- runDB $ selectFirst [] [Asc WordText]
    authorMap <- loadUserMap $ map (wordCommentAuthor . entityVal) latestComments
    wordMap <- loadWordMap $ map (wordCommentWord . entityVal) latestComments
    returnJson $ object
        [ "items" .= map (homeCommentValue authorMap wordMap) latestComments
        , "stats" .= object
            [ "totalWords" .= totalWords
            , "totalStories" .= totalStories
            , "totalMembers" .= totalMembers
            ]
        , "popularWords" .= map wordValue popularWords
        , "dailyWord" .= maybe Null wordValue mDailyWord
        , "viewer" .= fmap (userValue . entityVal) mViewer
        ]

getApiSearchR :: Handler Value
getApiSearchR = do
    mQuery <- cleanOptionalText <$> lookupGetParam "q"
    mViewer <- maybeAuth
    let mViewerId = entityKey <$> mViewer
    words <-
        case mQuery of
            Nothing -> pure []
            Just queryText -> do
                allWords <- runDB $ selectList [] [Asc WordText, LimitTo 200]
                pure $ take 50 $ filter (matchesQuery queryText . entityVal) allWords
    submissions <-
        case mQuery of
            Nothing -> pure []
            Just queryText -> do
                allSubmissions <- runDB $ selectList [WordSubmissionStatus ==. pendingStatus] [Asc WordSubmissionText, LimitTo 200]
                pure $ take 50 $ filter (matchesSubmissionQuery queryText . entityVal) allSubmissions
    creatorMap <- loadUserMap $ map (wordSubmissionCreator . entityVal) submissions
    voteCountMap <- loadSubmissionVoteCounts submissions
    votedSubmissionIds <- loadViewerSubmissionVotes mViewerId (map entityKey submissions)
    let items =
            map wordValue words
                ++ map (wordSubmissionValue mViewerId creatorMap voteCountMap votedSubmissionIds) submissions
    featuredWords <- runDB $ selectList [] [Asc WordText, LimitTo 4]
    returnJson $ object
        [ "items" .= items
        , "featuredWords" .= map wordValue featuredWords
        , "meta" .= object
            [ "query" .= mQuery
            , "total" .= length items
            , "officialTotal" .= length words
            , "submissionTotal" .= length submissions
            ]
        ]

postApiWordsR :: Handler Value
postApiWordsR = do
    (userId, _user) <- requireApiAuthPair
    rawText <- runInputPost $ fromMaybe "" <$> iopt textField "text"
    rawTranscription <- runInputPost $ iopt textField "transcription"
    let text = T.strip rawText
        transcription = cleanOptionalText rawTranscription
    when (text == "") $
        apiError status400 "Word text is required."
    when (length text > 120) $
        apiError status400 "Word text must be 120 characters or fewer."
    existingWord <- runDB $ getBy $ UniqueWord text
    when (isJust existingWord) $
        apiError status400 "That word already exists."
    existingSubmission <- runDB $ selectFirst [WordSubmissionText ==. text, WordSubmissionStatus <-. [pendingStatus, approvedStatus]] []
    when (isJust existingSubmission) $
        apiError status400 "That word is already in review."
    now <- liftIO getCurrentTime
    submissionId <- runDB $ insert $ WordSubmission text transcription Nothing userId pendingStatus now now Nothing Nothing Nothing
    submission <- runDB $ get404 submissionId
    creatorMap <- loadUserMap [userId]
    returnJson $ object
        [ "submission" .= wordSubmissionValue (Just userId) creatorMap Map.empty [] (Entity submissionId submission)
        , "message" .= ("Word submitted for review." :: Text)
        ]

getApiWordR :: WordId -> Handler Value
getApiWordR wordId = do
    word <- runDB $ get404 wordId
    let wordEntity = Entity wordId word
    meanings <- runDB $ selectList [MeaningWord ==. wordId] []
    let meaningIds = map entityKey meanings
    examples <- runDB $ selectList [ExampleMeaning <-. meaningIds] []
    comments <- runDB $ selectList [WordCommentWord ==. wordId] [Desc WordCommentCreatedAt]
    mViewer <- maybeAuth
    let mViewerId = entityKey <$> mViewer
        groupedMeanings =
            map
                (\meaningEntity@(Entity meaningId _) ->
                    (meaningEntity, filter (\(Entity _ example) -> exampleMeaning example == meaningId) examples)
                )
                meanings
    authorMap <- loadUserMap $ map (wordCommentAuthor . entityVal) comments
    relatedWords <- runDB $ selectList [WordId !=. wordId] [Asc WordText, LimitTo 4]
    likeCount <- runDB $ count [WordLikeWord ==. wordId]
    bookmarkCount <- runDB $ count [WordBookmarkWord ==. wordId]
    isLiked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> runDB $ exists [WordLikeUser ==. viewerId, WordLikeWord ==. wordId]
    isBookmarked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> runDB $ exists [WordBookmarkUser ==. viewerId, WordBookmarkWord ==. wordId]
    returnJson $ object
        [ "item" .= object
            [ "word" .= wordValue wordEntity
            , "meanings" .= map (uncurry meaningValue) groupedMeanings
            , "comments" .= map (commentValue mViewerId authorMap) comments
            , "viewer" .= fmap (userValue . entityVal) mViewer
            , "meta" .= object
                [ "likeCount" .= likeCount
                , "bookmarkCount" .= bookmarkCount
                , "commentCount" .= length comments
                , "meaningCount" .= length meanings
                , "exampleCount" .= length examples
                , "liked" .= isLiked
                , "bookmarked" .= isBookmarked
                ]
            ]
        , "relatedWords" .= map wordValue relatedWords
        , "quote" .= object
            [ "title" .= ("Daily word ritual" :: Text)
            , "body" .= ("Track definitions, examples, and the stories people attach to them." :: Text)
            ]
        ]

postApiWordCommentR :: WordId -> Handler Value
postApiWordCommentR wordId = do
    (userId, _user) <- requireApiAuthPair
    _ <- runDB $ get404 wordId
    rawContent <- runInputPost $ fromMaybe "" <$> iopt textField "content"
    rawParentId <- runInputPost $ iopt textField "parentId"
    let content = T.strip rawContent
        parentId = rawParentId >>= fromPathPiece
    when (content == "") $
        apiError status400 "Write a story before posting."
    when (length content > 3000) $
        apiError status400 "Stories must be 3000 characters or fewer."
    now <- liftIO getCurrentTime
    commentId <- runDB $ insert $ WordComment wordId userId content parentId now now
    comment <- runDB $ get404 commentId
    authorMap <- loadUserMap [userId]
    returnJson $ object
        [ "comment" .= commentValue (Just userId) authorMap (Entity commentId comment)
        , "message" .= ("Comment posted." :: Text)
        ]

postApiWordLikeR :: WordId -> Handler Value
postApiWordLikeR wordId = do
    (userId, _user) <- requireApiAuthPair
    existingLike <- runDB $ getBy $ UniqueWordLike userId wordId
    active <- case existingLike of
        Just (Entity likeId _) -> do
            runDB $ delete likeId
            pure False
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordLike userId wordId now
            pure True
    likeCount <- runDB $ count [WordLikeWord ==. wordId]
    returnJson $ object
        [ "active" .= active
        , "count" .= likeCount
        ]

postApiWordBookmarkR :: WordId -> Handler Value
postApiWordBookmarkR wordId = do
    (userId, _user) <- requireApiAuthPair
    existingBookmark <- runDB $ getBy $ UniqueWordBookmark userId wordId
    active <- case existingBookmark of
        Just (Entity bookmarkId _) -> do
            runDB $ delete bookmarkId
            pure False
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordBookmark userId wordId now
            pure True
    bookmarkCount <- runDB $ count [WordBookmarkWord ==. wordId]
    returnJson $ object
        [ "active" .= active
        , "count" .= bookmarkCount
        ]

postApiWordSubmissionVoteR :: WordSubmissionId -> Handler Value
postApiWordSubmissionVoteR submissionId = do
    (userId, _user) <- requireApiAuthPair
    submission <- runDB $ get404 submissionId
    when (wordSubmissionStatus submission /= pendingStatus) $
        apiError status400 "Voting is closed for this submission."
    existingVote <- runDB $ getBy $ UniqueWordSubmissionVote userId submissionId
    active <- case existingVote of
        Just (Entity voteId _) -> do
            runDB $ delete voteId
            pure False
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordSubmissionVote userId submissionId now
            pure True
    voteCount <- runDB $ count [WordSubmissionVoteSubmission ==. submissionId]
    returnJson $ object
        [ "active" .= active
        , "count" .= voteCount
        ]

postApiCommentDeleteR :: WordCommentId -> Handler Value
postApiCommentDeleteR commentId = do
    (userId, user) <- requireApiAuthPair
    comment <- runDB $ get404 commentId
    unless (wordCommentAuthor comment == userId || userRole user == ("admin" :: Text)) $
        apiError status403 "You can delete only your own stories."
    runDB $ delete commentId
    returnJson $ object
        [ "deletedCommentId" .= fromSqlKey commentId
        ]

getApiNotificationsR :: Handler Value
getApiNotificationsR = do
    (userId, _user) <- requireApiAuthPair
    notifications <- runDB $ selectList [NotificationUser ==. userId] [Desc NotificationCreatedAt, LimitTo 50]
    unreadCount <- runDB $ count [NotificationUser ==. userId, NotificationIsRead ==. False]
    actorMap <- loadUserMap $ mapMaybe (notificationActor . entityVal) notifications
    wordMap <- loadWordMap $ mapMaybe (notificationWord . entityVal) notifications
    popularWords <- runDB $ selectList [] [Asc WordText, LimitTo 4]
    returnJson $ object
        [ "items" .= map (notificationValue actorMap wordMap) notifications
        , "meta" .= object
            [ "unreadCount" .= unreadCount
            ]
        , "popularWords" .= map wordValue popularWords
        ]

postApiNotificationsReadAllR :: Handler Value
postApiNotificationsReadAllR = do
    (userId, _user) <- requireApiAuthPair
    runDB $ updateWhere [NotificationUser ==. userId, NotificationIsRead ==. False] [NotificationIsRead =. True]
    returnJson $ object
        [ "ok" .= True
        ]

postApiAuthLoginR :: Handler Value
postApiAuthLoginR = do
    identInput <- runInputPost $ fromMaybe "" <$> iopt textField "ident"
    usernameInput <- runInputPost $ fromMaybe "" <$> iopt textField "username"
    password <- runInputPost $ fromMaybe "" <$> iopt textField "password"
    let ident = T.strip $ if T.strip identInput /= "" then identInput else usernameInput
    when (ident == "") $
        apiError status400 "Username is required."
    when (T.strip password == "") $
        apiError status400 "Password is required."
    mUser <- runDB $ getBy $ UniqueUser ident
    case mUser of
        Just (Entity userId user) ->
            case validatePass user password of
                Just True -> do
                    setCreds False $ Creds "api" ident []
                    returnJson $ object
                        [ "authenticated" .= True
                        , "user" .= userValue user
                        , "userId" .= fromSqlKey userId
                        ]
                _ ->
                    apiError status400 "Invalid username or password."
        Nothing ->
            apiError status400 "Invalid username or password."

postApiAuthRegisterR :: Handler Value
postApiAuthRegisterR = do
    ident <- runInputPost $ ireq textField "ident"
    password <- runInputPost $ ireq textField "password"
    passwordConfirm <- runInputPost $ ireq textField "passwordConfirm"
    rawDisplayName <- runInputPost $ fromMaybe "" <$> iopt textField "displayName"
    rawDescription <- runInputPost $ fromMaybe "" <$> iopt textField "description"
    let trimmedIdent = T.strip ident
        trimmedDisplayName = T.strip rawDisplayName
        trimmedDescription = T.strip rawDescription
    when (trimmedIdent == "") $
        apiError status400 "Username is required."
    existingUser <- runDB $ getBy $ UniqueUser trimmedIdent
    when (isJust existingUser) $
        apiError status400 "That username is already taken."
    when (length password < 4) $
        apiError status400 "Password must be at least 4 characters."
    when (password /= passwordConfirm) $
        apiError status400 "Passwords do not match."
    let baseUser =
            User
                { userIdent = trimmedIdent
                , userPassword = Nothing
                , userRole = "user"
                , userName =
                    if trimmedDisplayName == ""
                        then Nothing
                        else Just trimmedDisplayName
                , userDescription =
                    if trimmedDescription == ""
                        then Nothing
                        else Just trimmedDescription
                }
    createdUser <- liftIO $ setPassword password baseUser
    userId <- runDB $ insert createdUser
    savedUser <- runDB $ get404 userId
    setCreds False $ Creds "api" trimmedIdent []
    returnJson $ object
        [ "authenticated" .= True
        , "user" .= userValue savedUser
        , "userId" .= fromSqlKey userId
        ]

postApiAuthLogoutR :: Handler Value
postApiAuthLogoutR = do
    clearCreds False
    returnJson $ object
        [ "authenticated" .= False
        ]

getApiSessionR :: Handler Value
getApiSessionR = do
    mViewer <- maybeAuth
    returnJson $ object
        [ "authenticated" .= isJust mViewer
        , "user" .= fmap (userValue . entityVal) mViewer
        ]

getApiMeR :: Handler Value
getApiMeR = do
    (userId, user) <- requireApiAuthPair
    storyCount <- runDB $ count [WordCommentAuthor ==. userId]
    bookmarkCount <- runDB $ count [WordBookmarkUser ==. userId]
    likeCount <- runDB $ count [WordLikeUser ==. userId]
    followerCount <- runDB $ count [FollowingFollowee ==. userId]
    followingCount <- runDB $ count [FollowingFollower ==. userId]
    mySubmissions <- runDB $ selectList [WordSubmissionCreator ==. userId] [Desc WordSubmissionSubmittedAt, LimitTo 20]
    let promotedWordIds = mapMaybe (wordSubmissionPromotedWord . entityVal) mySubmissions
    promotedWordMap <- loadWordMap promotedWordIds
    let promotedWords =
            mapMaybe
                (\wordId -> Entity wordId <$> Map.lookup wordId promotedWordMap)
                promotedWordIds
    submissionVoteCountMap <- loadSubmissionVoteCounts mySubmissions
    votedSubmissionIds <- loadViewerSubmissionVotes (Just userId) (map entityKey mySubmissions)
    bookmarks <- runDB $ selectList [WordBookmarkUser ==. userId] [Desc WordBookmarkCreatedAt, LimitTo 6]
    bookmarkWordMap <- loadWordMap $ map (wordBookmarkWord . entityVal) bookmarks
    creatorMap <- loadUserMap [userId]
    returnJson $ object
        [ "user" .= userValue user
        , "meta" .= object
            [ "storyCount" .= storyCount
            , "bookmarkCount" .= bookmarkCount
            , "likeCount" .= likeCount
            , "followerCount" .= followerCount
            , "followingCount" .= followingCount
            ]
        , "myWords" .= map wordValue promotedWords
        , "mySubmissions" .= map (wordSubmissionValue (Just userId) creatorMap submissionVoteCountMap votedSubmissionIds) mySubmissions
        , "bookmarks" .=
            mapMaybe
                (\bookmark ->
                    (\word -> wordValue $ Entity (wordBookmarkWord $ entityVal bookmark) word)
                        <$> Map.lookup (wordBookmarkWord $ entityVal bookmark) bookmarkWordMap
                )
                bookmarks
        ]

postApiMeUpdateR :: Handler Value
postApiMeUpdateR = do
    (userId, currentUser) <- requireApiAuthPair
    rawIdent <- runInputPost $ fromMaybe (userIdent currentUser) <$> iopt textField "ident"
    rawDisplayName <- runInputPost $ fromMaybe "" <$> iopt textField "displayName"
    rawDescription <- runInputPost $ fromMaybe "" <$> iopt textField "description"
    let ident = T.strip rawIdent
        displayName = T.strip rawDisplayName
        description = T.strip rawDescription
    when (ident == "") $
        apiError status400 "Username is required."
    existingUser <- runDB $ getBy $ UniqueUser ident
    case existingUser of
        Just (Entity existingUserId _)
            | existingUserId /= userId ->
                apiError status400 "That username is already taken."
        _ -> pure ()
    runDB $ update userId
        [ UserIdent =. ident
        , UserName =.
            (if displayName == "" then Nothing else Just displayName)
        , UserDescription =.
            (if description == "" then Nothing else Just description)
        ]
    updatedUser <- runDB $ get404 userId
    returnJson $ object
        [ "user" .= userValue updatedUser
        ]

homeCommentValue :: Map.Map UserId User -> Map.Map WordId Word -> Entity WordComment -> Value
homeCommentValue authorMap wordMap commentEntity@(Entity _ comment) =
    object
        [ "comment" .= commentValue Nothing authorMap commentEntity
        , "word" .= maybe Null (wordValue . Entity (wordCommentWord comment)) (Map.lookup (wordCommentWord comment) wordMap)
        ]

matchesQuery :: Text -> Word -> Bool
matchesQuery queryText word =
    let loweredQuery = T.toLower queryText
        loweredText = T.toLower $ wordText word
        loweredTranscription = maybe "" T.toLower (wordTranscription word)
    in loweredQuery `T.isInfixOf` loweredText || loweredQuery `T.isInfixOf` loweredTranscription

matchesSubmissionQuery :: Text -> WordSubmission -> Bool
matchesSubmissionQuery queryText submission =
    let loweredQuery = T.toLower queryText
        loweredText = T.toLower $ wordSubmissionText submission
        loweredTranscription = maybe "" T.toLower (wordSubmissionTranscription submission)
    in loweredQuery `T.isInfixOf` loweredText || loweredQuery `T.isInfixOf` loweredTranscription

loadSubmissionVoteCounts :: [Entity WordSubmission] -> Handler (Map.Map WordSubmissionId Int)
loadSubmissionVoteCounts submissions
    | null submissionIds = pure Map.empty
    | otherwise = do
        counts <- forM submissionIds $ \submissionId -> do
            voteCount <- runDB $ count [WordSubmissionVoteSubmission ==. submissionId]
            pure (submissionId, voteCount)
        pure $ Map.fromList counts
  where
    submissionIds = map entityKey submissions

loadViewerSubmissionVotes :: Maybe UserId -> [WordSubmissionId] -> Handler [WordSubmissionId]
loadViewerSubmissionVotes Nothing _ = pure []
loadViewerSubmissionVotes (Just _) [] = pure []
loadViewerSubmissionVotes (Just viewerId) submissionIds = do
    votes <- runDB $ selectList [WordSubmissionVoteUser ==. viewerId, WordSubmissionVoteSubmission <-. submissionIds] []
    pure $ map (wordSubmissionVoteSubmission . entityVal) votes

pendingStatus :: Text
pendingStatus = "pending"

approvedStatus :: Text
approvedStatus = "approved"
