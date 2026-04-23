{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api where

import Import
import Database.Persist.Sql (fromSqlKey)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Text.Encoding as TE
import Handler.Api.Shared
import Yesod.Auth.HashDB (setPassword, validatePass)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

getAdClickR :: AdId -> Handler Html
getAdClickR adId = do
    ad <- runDB $ get404 adId
    now <- liftIO getCurrentTime
    runDB $
        update adId
            [ AdClickCount +=. 1
            , AdLastClickedAt =. Just now
            ]
    case adLink ad of
        Just targetUrl -> redirect targetUrl
        Nothing -> redirect HomeR

postApiAdImpressionR :: AdId -> Handler Value
postApiAdImpressionR adId = do
    ad <- runDB $ get404 adId
    now <- liftIO getCurrentTime
    when (isAdServingAt now ad) $
        runDB $
            update adId
                [ AdImpressionCount +=. 1
                , AdLastImpressionAt =. Just now
                ]
    returnJson $
        object
            [ "tracked" .= isAdServingAt now ad
            ]

getApiHomeR :: Handler Value
getApiHomeR = do
    mViewer <- maybeAuth
    latestComments <- runDB $ selectList [] [Desc WordCommentCreatedAt, LimitTo 12]
    totalWords <- runDB $ count ([] :: [Filter Word])
    totalStories <- runDB $ count ([] :: [Filter WordComment])
    totalMembers <- runDB $ count ([] :: [Filter User])
    popularWords <- runDB $ selectList [] [Asc WordText, LimitTo 5]
    mDailyWord <- resolveDailyWordEntity
    adMap <- loadActiveAdsBySlots [homeRightRailAdSlot]
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
        , "ads" .= object
            [ "homeRightRail" .= maybe Null adValue (Map.lookup homeRightRailAdSlot adMap)
            ]
        ]

getApiSearchR :: Handler Value
getApiSearchR = do
    mQuery <- cleanOptionalText <$> lookupGetParam "q"
    mViewer <- maybeAuth
    let mViewerId = entityKey <$> mViewer
    matchingWords <-
        case mQuery of
            Nothing -> pure []
            Just queryText -> do
                allWords <- runDB $ selectList [] [Asc WordText, LimitTo 200]
                pure $ take 50 $ filter (matchesQuery queryText . entityVal) allWords
    submissions <-
        case mQuery of
            Nothing -> pure []
            Just queryText -> do
                allSubmissions <- runDB $ selectList [WordSubmissionStatus ==. pendingStatus] [Desc WordSubmissionPriorityScore, Asc WordSubmissionText, LimitTo 200]
                pure $ take 50 $ filter (matchesSubmissionQuery queryText . entityVal) allSubmissions
    creatorMap <- loadUserMap $ map (wordSubmissionCreator . entityVal) submissions
    voteCountMap <- loadSubmissionVoteCounts submissions
    votedSubmissionIds <- loadViewerSubmissionVotes mViewerId (map entityKey submissions)
    let items =
            map wordValue matchingWords
                ++ map (wordSubmissionValue mViewerId creatorMap voteCountMap votedSubmissionIds) submissions
    featuredWords <- runDB $ selectList [] [Asc WordText, LimitTo 4]
    returnJson $ object
        [ "items" .= items
        , "featuredWords" .= map wordValue featuredWords
        , "meta" .= object
            [ "query" .= mQuery
            , "total" .= length items
            , "officialTotal" .= length matchingWords
            , "submissionTotal" .= length submissions
            ]
        ]

postApiWordsR :: Handler Value
postApiWordsR = do
    (userId, user) <- requireApiAuthPair
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
    let priorityScore = submissionPriorityScoreForUser user
    submissionId <- runDB $
        insert $
            WordSubmission text transcription Nothing userId pendingStatus priorityScore now now Nothing Nothing Nothing
    submission <- runDB $ get404 submissionId
    creatorMap <- loadUserMap [userId]
    returnJson $ object
        [ "submission" .= wordSubmissionValue (Just userId) creatorMap Map.empty [] (Entity submissionId submission)
        , "message" .= ("Word submitted for review." :: Text)
        ]

getApiWordR :: WordId -> Handler Value
getApiWordR wordId = do
    word <- runDB $ get404 wordId
    app <- getYesod
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
    adMap <- loadActiveAdsBySlots [wordRightRailAdSlot]
    likeCount <- runDB $ count [WordLikeWord ==. wordId]
    bookmarkCount <- runDB $ count [WordBookmarkWord ==. wordId]
    isLiked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> runDB $ exists [WordLikeUser ==. viewerId, WordLikeWord ==. wordId]
    isBookmarked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> runDB $ exists [WordBookmarkUser ==. viewerId, WordBookmarkWord ==. wordId]
    collectionPayloads <- case mViewerId of
        Nothing -> pure []
        Just viewerId -> loadCollectionPayloads viewerId
    collectionWordMap <- loadWordMap $ concatMap (map (wordCollectionItemWord . entityVal) . snd) collectionPayloads
    let viewerCollections = map (collectionPickerValue wordId collectionWordMap) collectionPayloads
        premiumInfo =
            case mViewer of
                Nothing -> Null
                Just (Entity _ viewer) ->
                    object
                        [ "available" .= True
                        , "isPremium" .= userPremium viewer
                        , "adsEnabled" .= not (userPremium viewer)
                        , "voteWeight" .= voteWeightForUser viewer
                        , "bookmarkLimit" .= bookmarkLimitValue viewer
                        , "collectionLimit" .= collectionLimitValue viewer
                        , "collections" .= viewerCollections
                        ]
        seoValue =
            object
                [ "title" .= wordSeoTitle word
                , "description" .= wordSeoDescription word meanings
                , "canonicalUrl" .= (canonicalRootUrl app <> "/words/" <> toPathPiece wordId)
                , "imageUrl" .= (canonicalRootUrl app <> "/og/word/" <> toPathPiece wordId <> "/card.svg" :: Text)
                ]
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
        , "premium" .= premiumInfo
        , "ads" .= object
            [ "wordRightRail" .= maybe Null adValue (Map.lookup wordRightRailAdSlot adMap)
            ]
        , "seo" .= seoValue
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
    (userId, user) <- requireApiAuthPair
    existingBookmark <- runDB $ getBy $ UniqueWordBookmark userId wordId
    active <- case existingBookmark of
        Just (Entity bookmarkId _) -> do
            runDB $ delete bookmarkId
            pure False
        Nothing -> do
            currentCount <- runDB $ count [WordBookmarkUser ==. userId]
            when (not (userPremium user) && currentCount >= freeBookmarkLimit) $
                apiError status403 "Free accounts can save up to 20 bookmarks. Upgrade to premium for unlimited saves."
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordBookmark userId wordId now
            pure True
    bookmarkCount <- runDB $ count [WordBookmarkWord ==. wordId]
    returnJson $ object
        [ "active" .= active
        , "count" .= bookmarkCount
        ]

postApiCollectionsR :: Handler Value
postApiCollectionsR = do
    (userId, user) <- requireApiAuthPair
    titleInput <- runInputPost $ fromMaybe "" <$> iopt textField "title"
    descriptionInput <- runInputPost $ iopt textField "description"
    let title = T.strip titleInput
        description = cleanOptionalText descriptionInput
    when (title == "") $
        apiError status400 "Collection title is required."
    existingCount <- runDB $ count [WordCollectionUser ==. userId]
    when (not (userPremium user) && existingCount >= freeCollectionLimit) $
        apiError status403 "Free accounts can create up to 2 collections. Upgrade to premium for unlimited folders."
    existingCollection <- runDB $ getBy $ UniqueWordCollection userId title
    when (isJust existingCollection) $
        apiError status400 "That collection title already exists."
    now <- liftIO getCurrentTime
    collectionId <- runDB $ insert $ WordCollection userId title description now now
    payloads <- loadCollectionPayloads userId
    collectionWordMap <- loadWordMap $ concatMap (map (wordCollectionItemWord . entityVal) . snd) payloads
    collection <- runDB $ get404 collectionId
    returnJson $ object
        [ "collection" .= wordCollectionValue collectionWordMap (Entity collectionId collection, [])
        , "message" .= ("Collection created." :: Text)
        ]

postApiCollectionDeleteR :: WordCollectionId -> Handler Value
postApiCollectionDeleteR collectionId = do
    (userId, _user) <- requireApiAuthPair
    _ <- requireOwnedCollection userId collectionId
    runDB $ deleteWhere [WordCollectionItemCollection ==. collectionId]
    runDB $ delete collectionId
    returnJson $ object
        [ "deletedCollectionId" .= fromSqlKey collectionId
        ]

postApiCollectionAddWordR :: WordCollectionId -> WordId -> Handler Value
postApiCollectionAddWordR collectionId wordId = do
    (userId, _user) <- requireApiAuthPair
    _ <- runDB $ get404 wordId
    _ <- requireOwnedCollection userId collectionId
    existing <- runDB $ getBy $ UniqueWordCollectionItem collectionId wordId
    active <- case existing of
        Just _ -> pure True
        Nothing -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert $ WordCollectionItem collectionId wordId now
            runDB $ update collectionId [WordCollectionUpdatedAt =. now]
            pure True
    itemCount <- runDB $ count [WordCollectionItemCollection ==. collectionId]
    returnJson $ object
        [ "active" .= active
        , "collectionId" .= fromSqlKey collectionId
        , "wordId" .= fromSqlKey wordId
        , "itemCount" .= itemCount
        ]

postApiCollectionRemoveWordR :: WordCollectionId -> WordId -> Handler Value
postApiCollectionRemoveWordR collectionId wordId = do
    (userId, _user) <- requireApiAuthPair
    _ <- requireOwnedCollection userId collectionId
    existing <- runDB $ getBy $ UniqueWordCollectionItem collectionId wordId
    active <- case existing of
        Just (Entity itemId _) -> do
            runDB $ delete itemId
            now <- liftIO getCurrentTime
            runDB $ update collectionId [WordCollectionUpdatedAt =. now]
            pure False
        Nothing ->
            pure False
    itemCount <- runDB $ count [WordCollectionItemCollection ==. collectionId]
    returnJson $ object
        [ "active" .= active
        , "collectionId" .= fromSqlKey collectionId
        , "wordId" .= fromSqlKey wordId
        , "itemCount" .= itemCount
        ]

postApiWordSubmissionVoteR :: WordSubmissionId -> Handler Value
postApiWordSubmissionVoteR submissionId = do
    (userId, user) <- requireApiAuthPair
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
            _ <- runDB $ insert $ WordSubmissionVote userId submissionId (voteWeightForUser user) now
            pure True
    voteCount <- loadSubmissionVoteTotal submissionId
    returnJson $ object
        [ "active" .= active
        , "count" .= voteCount
        , "weight" .= voteWeightForUser user
        ]

getApiPremiumRecommendationsR :: Handler Value
getApiPremiumRecommendationsR = do
    (_userId, user) <- requireApiAuthPair
    ensurePremiumUser user
    contextParam <- fmap (fromMaybe "comfort") $ lookupGetParam "context"
    wordEntities <- runDB $ selectList [] [Asc WordText, LimitTo 40]
    let contextKey = normalizeContext contextParam
        items = take 4 $ scoreRecommendedWords contextKey wordEntities
    returnJson $ object
        [ "context" .= contextKey
        , "title" .= recommendationTitle contextKey
        , "description" .= recommendationDescription contextKey
        , "items" .= map wordValue items
        ]

postApiPremiumSentenceR :: Handler Value
postApiPremiumSentenceR = do
    (_userId, user) <- requireApiAuthPair
    ensurePremiumUser user
    wordId <- runInputPost $ ireq hiddenField "wordId"
    toneInput <- runInputPost $ fromMaybe "gentle" <$> iopt textField "tone"
    word <- runDB $ get404 wordId
    let tone = normalizeTone toneInput
    returnJson $ object
        [ "tone" .= tone
        , "lines" .= sentenceSuggestions tone word
        ]

postApiPremiumNicknameR :: Handler Value
postApiPremiumNicknameR = do
    (_userId, user) <- requireApiAuthPair
    ensurePremiumUser user
    rawSeed <- runInputPost $ fromMaybe "" <$> iopt textField "seed"
    rawWordId <- runInputPost $ iopt hiddenField "wordId"
    let seedText = T.strip rawSeed
    seedWordText <- case rawWordId of
        Just wordId -> wordText <$> runDB (get404 wordId)
        Nothing -> pure seedText
    when (seedWordText == "") $
        apiError status400 "A seed word is required."
    returnJson $ object
        [ "seed" .= seedWordText
        , "names" .= nicknameSuggestions seedWordText
        ]

getApiPremiumWordbookR :: Handler TypedContent
getApiPremiumWordbookR = do
    (userId, user) <- requireApiAuthPair
    ensurePremiumUser user
    formatParam <- fmap (fromMaybe "txt") $ lookupGetParam "format"
    mWordId <- lookupGetParam "wordId"
    bookmarks <- runDB $ selectList [WordBookmarkUser ==. userId] [Desc WordBookmarkCreatedAt, LimitTo 100]
    bookmarkWordMap <- loadWordMap $ map (wordBookmarkWord . entityVal) bookmarks
    collections <- loadCollectionPayloads userId
    collectionWordMap <- loadWordMap $ concatMap (map (wordCollectionItemWord . entityVal) . snd) collections
    mFeaturedWord <- case mWordId >>= fromPathPiece of
        Just wordId -> do
            mWord <- runDB $ get wordId
            pure $ Entity wordId <$> mWord
        Nothing ->
            pure Nothing
    let entries = collectWordbookEntries mFeaturedWord bookmarks bookmarkWordMap collections collectionWordMap
        formatValue = normalizeWordbookFormat formatParam
    case formatValue of
        "pdf" -> do
            addHeader "Content-Disposition" "attachment; filename=\"premium-wordbook.pdf\""
            sendResponse (("application/pdf" :: BS.ByteString), toContent $ renderPremiumWordbookPdf user entries)
        "svg" -> do
            addHeader "Content-Disposition" "attachment; filename=\"premium-wordbook-cards.svg\""
            sendResponse (("image/svg+xml; charset=utf-8" :: BS.ByteString), toContent $ renderPremiumWordbookSvg user entries)
        _ -> do
            addHeader "Content-Disposition" "attachment; filename=\"premium-wordbook.txt\""
            sendResponse (typePlain, toContent $ renderPremiumWordbookText user entries)

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
                , userPremium = False
                , userPremiumBadge = Nothing
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
    allBookmarks <- runDB $ selectList [WordBookmarkUser ==. userId] [Desc WordBookmarkCreatedAt, LimitTo 100]
    bookmarkWordMap <- loadWordMap $ map (wordBookmarkWord . entityVal) allBookmarks
    creatorMap <- loadUserMap [userId]
    collectionPayloads <- loadCollectionPayloads userId
    collectionWordMap <- loadWordMap $ concatMap (map (wordCollectionItemWord . entityVal) . snd) collectionPayloads
    archiveEntries <- loadDailyWordEntries
    archiveWordMap <- loadWordMap $ map (dailyWordEntryWord . entityVal) archiveEntries
    adMap <- loadActiveAdsBySlots [profileRightRailAdSlot]
    let bookmarkSummaries =
            mapMaybe
                (\bookmark ->
                    (\savedWord -> wordValue $ Entity (wordBookmarkWord $ entityVal bookmark) savedWord)
                        <$> Map.lookup (wordBookmarkWord $ entityVal bookmark) bookmarkWordMap
                )
                bookmarks
        collectionValues = map (wordCollectionValue collectionWordMap) collectionPayloads
        visibleArchive =
            if userPremium user
                then archiveEntries
                else take 3 archiveEntries
        archiveValues = mapMaybe (dailyWordEntryValue archiveWordMap) visibleArchive
        tasteReport =
            if userPremium user
                then Just $ buildTasteReport allBookmarks collectionPayloads bookmarkWordMap
                else Nothing
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
        , "bookmarks" .= bookmarkSummaries
        , "premium" .= object
            [ "isPremium" .= userPremium user
            , "adsEnabled" .= not (userPremium user)
            , "badge" .= premiumBadgeValue user
            , "bookmarkLimit" .= bookmarkLimitValue user
            , "collectionLimit" .= collectionLimitValue user
            , "voteWeight" .= voteWeightForUser user
            , "priorityReviewScore" .= submissionPriorityScoreForUser user
            , "collections" .= collectionValues
            , "dailyArchive" .= archiveValues
            , "dailyArchiveLocked" .= not (userPremium user)
            , "tasteReport" .= maybe Null id tasteReport
            , "wordbookUrl" .= if userPremium user then Just ("/api/premium/wordbook" :: Text) else Nothing
            ]
        , "ads" .= object
            [ "profileRightRail" .= maybe Null adValue (Map.lookup profileRightRailAdSlot adMap)
            ]
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
            voteCount <- loadSubmissionVoteTotal submissionId
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

loadSubmissionVoteTotal :: WordSubmissionId -> Handler Int
loadSubmissionVoteTotal submissionId = do
    votes <- runDB $ selectList [WordSubmissionVoteSubmission ==. submissionId] []
    pure $ sum $ map (wordSubmissionVoteWeight . entityVal) votes

loadCollectionPayloads :: UserId -> Handler [(Entity WordCollection, [Entity WordCollectionItem])]
loadCollectionPayloads userId = do
    collections <- runDB $ selectList [WordCollectionUser ==. userId] [Desc WordCollectionUpdatedAt]
    let collectionIds = map entityKey collections
    items <-
        if null collectionIds
            then pure []
            else runDB $ selectList [WordCollectionItemCollection <-. collectionIds] [Desc WordCollectionItemCreatedAt]
    pure $
        map
            (\collectionEntity@(Entity collectionId _) ->
                (collectionEntity, filter (\item -> wordCollectionItemCollection (entityVal item) == collectionId) items)
            )
            collections

loadDailyWordEntries :: Handler [Entity DailyWordEntry]
loadDailyWordEntries =
    runDB $ selectList [] [Desc DailyWordEntryDay, LimitTo 21]

resolveDailyWordEntity :: Handler (Maybe (Entity Word))
resolveDailyWordEntity = do
    entries <- loadDailyWordEntries
    now <- liftIO getCurrentTime
    let today = utctDay now
        matchingEntry =
            find (\entry -> dailyWordEntryDay (entityVal entry) == today) entries <|> listToMaybe entries
    case matchingEntry of
        Just (Entity _ entry) -> do
            mWord <- runDB $ get (dailyWordEntryWord entry)
            pure $ Entity (dailyWordEntryWord entry) <$> mWord
        Nothing ->
            runDB $ selectFirst [] [Asc WordText]

dailyWordEntryValue :: Map.Map WordId Word -> Entity DailyWordEntry -> Maybe Value
dailyWordEntryValue wordMap (Entity _ entry) = do
    word <- Map.lookup (dailyWordEntryWord entry) wordMap
    pure $
        object
            [ "day" .= show (dailyWordEntryDay entry)
            , "note" .= dailyWordEntryNote entry
            , "word" .= wordValue (Entity (dailyWordEntryWord entry) word)
            ]

buildTasteReport :: [Entity WordBookmark] -> [(Entity WordCollection, [Entity WordCollectionItem])] -> Map.Map WordId Word -> Value
buildTasteReport bookmarks collections wordMap =
    let savedWords = mapMaybe (\bookmark -> Map.lookup (wordBookmarkWord $ entityVal bookmark) wordMap) bookmarks
        wordLengths = map (T.length . wordText) savedWords
        averageLength =
            if null wordLengths
                then 0
                else sum wordLengths `div` length wordLengths
        voice =
            ( if averageLength >= 9
                then "You lean toward expressive, longer entries with a strong signature."
                else if averageLength >= 5
                    then "Your list balances clarity with a slightly literary tone."
                    else "You favor short, sharp words that read cleanly in public."
            ) :: Text
        initials =
            ordNub $
                mapMaybe
                    (\savedWord -> T.take 1 <$> headMay (T.words $ wordText savedWord))
                    savedWords
        archiveStyle =
            ( if length collections >= 3
                then "Curator"
                else if length bookmarks >= 8
                    then "Collector"
                    else "Scout"
            ) :: Text
    in object
        [ "savedCount" .= length bookmarks
        , "collectionCount" .= length collections
        , "style" .= archiveStyle
        , "voice" .= voice
        , "topInitials" .= take 4 initials
        ]

collectWordbookEntries :: Maybe (Entity Word) -> [Entity WordBookmark] -> Map.Map WordId Word -> [(Entity WordCollection, [Entity WordCollectionItem])] -> Map.Map WordId Word -> [(Entity Word, [Text])]
collectWordbookEntries mFeaturedWord bookmarks bookmarkWordMap collections collectionWordMap =
    foldl' insertEntry [] rawEntries
  where
    rawEntries =
        maybe [] (\wordEntity -> [(wordEntity, "Featured card")]) mFeaturedWord
            ++ mapMaybe
                (\bookmark ->
                    (\word -> (Entity (wordBookmarkWord $ entityVal bookmark) word, "Bookmark")) <$>
                        Map.lookup (wordBookmarkWord $ entityVal bookmark) bookmarkWordMap
                )
                bookmarks
            ++ concatMap
                (\(Entity _ collection, items) ->
                    mapMaybe
                        (\item ->
                            (\word -> (Entity (wordCollectionItemWord $ entityVal item) word, "Collection: " <> wordCollectionTitle collection)) <$>
                                Map.lookup (wordCollectionItemWord $ entityVal item) collectionWordMap
                        )
                        items
                )
                collections
    insertEntry :: [(Entity Word, [Text])] -> (Entity Word, Text) -> [(Entity Word, [Text])]
    insertEntry entries (Entity wordId word, originLabel) =
        case break (\(Entity existingId _, _) -> existingId == wordId) entries of
            (before, (_, origins) : after) ->
                before ++ [(Entity wordId word, ordNub $ origins ++ [originLabel])] ++ after
            _ ->
                entries ++ [(Entity wordId word, [originLabel])]

renderPremiumWordbookText :: User -> [(Entity Word, [Text])] -> Text
renderPremiumWordbookText user entries =
    let header =
            [ "Premium Wordbook"
            , "Owner: " <> fromMaybe (userIdent user) (userName user)
            , "Badge: " <> fromMaybe "Premium" (premiumBadgeValue user)
            , ""
            , "Saved Words"
            ]
        entryLines =
            if null entries
                then ["- No bookmarks saved yet."]
                else
                    concatMap renderTextEntry entries
    in T.intercalate "\n" $ header <> entryLines
  where
    renderTextEntry (Entity _ word, origins) =
        [ "- " <> wordText word <> maybe "" (\transcription -> " [" <> transcription <> "]") (wordTranscription word)
        , "  Origins: " <> T.intercalate ", " origins
        ]

renderPremiumWordbookSvg :: User -> [(Entity Word, [Text])] -> Text
renderPremiumWordbookSvg user entries =
    let visibleEntries = take 6 $ if null entries then [] else entries
        cardWidth = 460 :: Int
        cardHeight = 210 :: Int
        columns = 2 :: Int
        gap = 28 :: Int
        rowCount = max 1 ((length visibleEntries + columns - 1) `div` columns)
        svgWidth = 80 + (cardWidth * columns) + (gap * (columns - 1))
        svgHeight = 120 + (rowCount * cardHeight) + (gap * max 0 (rowCount - 1))
        cards =
            T.concat $
                zipWith
                    (\cardIndex entry -> renderSvgCard cardIndex cardWidth cardHeight gap columns entry)
                    [0 ..]
                    visibleEntries
    in T.concat
        [ "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"", tshow svgWidth, "\" height=\"", tshow svgHeight, "\" viewBox=\"0 0 ", tshow svgWidth, " ", tshow svgHeight, "\">"
        , "<rect width=\"100%\" height=\"100%\" fill=\"#f8f0dc\"/>"
        , "<text x=\"42\" y=\"56\" font-family=\"Georgia, serif\" font-size=\"34\" font-weight=\"700\" fill=\"#111\">", xmlEscape (fromMaybe (userIdent user) (userName user)), "'s Premium Wordbook</text>"
        , "<text x=\"42\" y=\"88\" font-family=\"Space Grotesk, sans-serif\" font-size=\"16\" fill=\"#544e45\">", xmlEscape (fromMaybe "Premium" (premiumBadgeValue user)), " export cards</text>"
        , cards
        , "</svg>"
        ]

renderPremiumWordbookPdf :: User -> [(Entity Word, [Text])] -> LBS.ByteString
renderPremiumWordbookPdf user entries =
    buildPdfDocument $ chunkWordbookLines 22 $
        [ "Premium Wordbook"
        , "Owner: " <> fromMaybe (userIdent user) (userName user)
        , "Badge: " <> fromMaybe "Premium" (premiumBadgeValue user)
        , ""
        ]
            <> if null entries then ["No saved words yet."] else concatMap renderPdfEntry entries
  where
    renderPdfEntry (Entity _ word, origins) =
        [ wordText word <> maybe "" (\transcription -> " [" <> transcription <> "]") (wordTranscription word)
        , "Origins: " <> T.intercalate ", " origins
        , ""
        ]

chunkWordbookLines :: Int -> [Text] -> [[Text]]
chunkWordbookLines pageSize linesToChunk
    | null linesToChunk = [[]]
    | otherwise =
        let (pageLines, rest) = splitAt pageSize linesToChunk
        in pageLines : if null rest then [] else chunkWordbookLines pageSize rest

buildPdfDocument :: [[Text]] -> LBS.ByteString
buildPdfDocument pages =
    LBS.fromStrict $ BS.concat $ header : objectBlobs ++ [xrefBlob, trailerBlob]
  where
    header = "%PDF-1.4\n%\226\227\207\211\n"
    fontObjectNum = 3 :: Int
    descendantFontObjectNum = 4 :: Int
    pageObjectNums = [5,7 .. 5 + (length pages - 1) * 2]
    streamObjectNums = [6,8 .. 6 + (length pages - 1) * 2]
    fontObject =
        renderPdfObject fontObjectNum $
            "<< /Type /Font /Subtype /Type0 /BaseFont /HYGoThic-Medium /Encoding /UniKS-UCS2-H /DescendantFonts [4 0 R] >>\n"
    descendantFontObject =
        renderPdfObject descendantFontObjectNum $
            "<< /Type /Font /Subtype /CIDFontType0 /BaseFont /HYGoThic-Medium /CIDSystemInfo << /Registry (Adobe) /Ordering (Korea1) /Supplement 1 >> >>\n"
    pageObjects =
        concat $
            zipWith3
                (\pageObjectNum streamObjectNum pageLines ->
                    [ renderPdfObject pageObjectNum $
                        BS.concat
                            [ "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 "
                            , BS8.pack $ show fontObjectNum
                            , " 0 R >> >> /Contents "
                            , BS8.pack $ show streamObjectNum
                            , " 0 R >>\n"
                            ]
                    , renderPdfStreamObject streamObjectNum $ renderPdfPageContent pageLines
                    ]
                )
                pageObjectNums
                streamObjectNums
                pages
    pagesObject =
        renderPdfObject 2 $
            BS.concat
                [ "<< /Type /Pages /Count "
                , BS8.pack $ show (length pages)
                , " /Kids ["
                , BS8.pack $ unwords $ map (\n -> show n <> " 0 R") pageObjectNums
                , "] >>\n"
                ]
    catalogObject = renderPdfObject 1 "<< /Type /Catalog /Pages 2 0 R >>\n"
    objectBlobs = [catalogObject, pagesObject, fontObject, descendantFontObject] <> pageObjects
    objectOffsets =
        map
            (\objectIndex -> BS.length header + sum (map BS.length (take objectIndex objectBlobs)))
            [0 .. length objectBlobs - 1]
    objectCount = length objectBlobs + 1
    xrefStart = BS.length header + sum (map BS.length objectBlobs)
    xrefBlob =
        BS.concat
            [ "xref\n0 "
            , BS8.pack $ show objectCount
            , "\n0000000000 65535 f \n"
            , BS.concat $ map renderPdfOffset objectOffsets
            ]
    trailerBlob =
        BS.concat
            [ "trailer\n<< /Size "
            , BS8.pack $ show objectCount
            , " /Root 1 0 R >>\nstartxref\n"
            , BS8.pack $ show xrefStart
            , "\n%%EOF\n"
            ]

renderPdfObject :: Int -> BS.ByteString -> BS.ByteString
renderPdfObject objectNum body =
    BS.concat [BS8.pack $ show objectNum, " 0 obj\n", body, "endobj\n"]

renderPdfStreamObject :: Int -> BS.ByteString -> BS.ByteString
renderPdfStreamObject objectNum streamBody =
    renderPdfObject objectNum $
        BS.concat
            [ "<< /Length "
            , BS8.pack $ show (BS.length streamBody)
            , " >>\nstream\n"
            , streamBody
            , "\nendstream\n"
            ]

renderPdfPageContent :: [Text] -> BS.ByteString
renderPdfPageContent pageLines =
    BS.concat $
        [ "BT\n/F1 20 Tf\n50 790 Td\n" ]
            <> zipWith renderPdfLine [0 :: Int ..] pageLines
            <> [ "ET" ]

renderPdfLine :: Int -> Text -> BS.ByteString
renderPdfLine lineIndex lineText =
    let fontSize :: Int
        fontSize = if lineIndex == 0 then 20 else 14
        encoded = utf16PdfHex lineText
        linePrefix =
            if lineIndex == 0
                then BS.concat ["/F1 ", BS8.pack $ show fontSize, " Tf <", encoded, "> Tj\n"]
                else BS.concat ["0 -24 Td /F1 ", BS8.pack $ show fontSize, " Tf <", encoded, "> Tj\n"]
    in linePrefix

renderPdfOffset :: Int -> BS.ByteString
renderPdfOffset offset =
    let raw = show offset
        padded = replicate (10 - length raw) '0' ++ raw
    in BS8.pack $ padded <> " 00000 n \n"

utf16PdfHex :: Text -> BS.ByteString
utf16PdfHex txt =
    "FEFF" <> hexEncodeByteString (TE.encodeUtf16BE txt)

hexEncodeByteString :: BS.ByteString -> BS.ByteString
hexEncodeByteString =
    BS.concatMap encodeByte
  where
    encodeByte byte =
        BS.pack [nibble (byte `div` 16), nibble (byte `mod` 16)]
    nibble value
        | value < 10 = 48 + value
        | otherwise = 55 + value

renderSvgCard :: Int -> Int -> Int -> Int -> Int -> (Entity Word, [Text]) -> Text
renderSvgCard cardIndex cardWidth cardHeight gap columns (Entity _ word, origins) =
    let col = cardIndex `mod` columns
        row = cardIndex `div` columns
        x = 40 + col * (cardWidth + gap)
        y = 120 + row * (cardHeight + gap)
        transcriptionLine = fromMaybe "No transcription" (wordTranscription word)
        originLine = T.intercalate ", " origins
    in T.concat
        [ "<g transform=\"translate(", tshow x, ",", tshow y, ")\">"
        , "<rect width=\"", tshow cardWidth, "\" height=\"", tshow cardHeight, "\" rx=\"26\" fill=\"#fff9ef\" stroke=\"#111\" stroke-width=\"4\"/>"
        , "<rect x=\"18\" y=\"18\" width=\"", tshow (cardWidth - 36), "\" height=\"", tshow (cardHeight - 36), "\" rx=\"20\" fill=\"#ffffff\" stroke=\"#111\" stroke-width=\"2\"/>"
        , "<text x=\"34\" y=\"62\" font-family=\"Georgia, serif\" font-size=\"34\" font-weight=\"700\" fill=\"#111\">", xmlEscape (wordText word), "</text>"
        , "<text x=\"34\" y=\"96\" font-family=\"Space Grotesk, sans-serif\" font-size=\"16\" fill=\"#544e45\">", xmlEscape transcriptionLine, "</text>"
        , "<text x=\"34\" y=\"132\" font-family=\"Space Grotesk, sans-serif\" font-size=\"14\" fill=\"#111\">", xmlEscape originLine, "</text>"
        , "<text x=\"34\" y=\"174\" font-family=\"Space Grotesk, sans-serif\" font-size=\"13\" fill=\"#544e45\">kdic premium card</text>"
        , "</g>"
        ]

xmlEscape :: Text -> Text
xmlEscape =
    T.concatMap $ \char ->
        case char of
            '&' -> "&amp;"
            '<' -> "&lt;"
            '>' -> "&gt;"
            '"' -> "&quot;"
            '\'' -> "&apos;"
            _ -> T.singleton char

normalizeWordbookFormat :: Text -> Text
normalizeWordbookFormat rawFormat =
    let lowered = T.toLower $ T.strip rawFormat
    in if lowered `elem` ["txt", "pdf", "svg"]
        then lowered
        else "txt"

loadActiveAdsBySlots :: [Text] -> Handler (Map.Map Text (Entity Ad))
loadActiveAdsBySlots slots
    | null uniqueSlots = pure Map.empty
    | otherwise = do
        now <- liftIO getCurrentTime
        ads <- runDB $ selectList [AdSlot <-. uniqueSlots, AdIsActive ==. True] [Asc AdSlot, Asc AdSortOrder, Desc AdUpdatedAt]
        let activeAds = filter (isAdServingAt now . entityVal) ads
        pure $ selectRotatingAds now activeAds
  where
    uniqueSlots = ordNub slots

selectRotatingAds :: UTCTime -> [Entity Ad] -> Map.Map Text (Entity Ad)
selectRotatingAds now ads =
    Map.mapMaybe (selectSlotAd now) groupedAds
  where
    groupedAds =
        foldl'
            (\acc adEntity@(Entity _ ad) -> Map.insertWith (\new old -> old <> new) (adSlot ad) [adEntity] acc)
            Map.empty
            ads

selectSlotAd :: UTCTime -> [Entity Ad] -> Maybe (Entity Ad)
selectSlotAd _ [] = Nothing
selectSlotAd now slotAds =
    let rotationIndex = fromInteger (toModifiedJulianDay (utctDay now) `mod` toInteger (length slotAds))
    in listToMaybe $ drop rotationIndex slotAds

isAdServingAt :: UTCTime -> Ad -> Bool
isAdServingAt now ad =
    adIsActive ad
        && maybe True (<= now) (adStartAt ad)
        && maybe True (> now) (adEndAt ad)

collectionPickerValue :: WordId -> Map.Map WordId Word -> (Entity WordCollection, [Entity WordCollectionItem]) -> Value
collectionPickerValue currentWordId collectionWordMap payload@(_, items) =
    case wordCollectionValue collectionWordMap payload of
        Object valueMap ->
            Object $
                KeyMap.insert "containsWord" (toJSON $ any (\item -> wordCollectionItemWord (entityVal item) == currentWordId) items) valueMap
        other -> other

requireOwnedCollection :: UserId -> WordCollectionId -> Handler (Entity WordCollection)
requireOwnedCollection userId collectionId = do
    collection <- runDB $ get404 collectionId
    if wordCollectionUser collection == userId
        then pure (Entity collectionId collection)
        else apiError status403 "You can manage only your own collections."

ensurePremiumUser :: User -> Handler ()
ensurePremiumUser user =
    unless (userPremium user) $
        apiError status403 "This premium feature is available after upgrading your account."

scoreRecommendedWords :: Text -> [Entity Word] -> [Entity Word]
scoreRecommendedWords contextKey wordEntities =
    map snd $
        sortOn
            (\(score, _) -> negate score)
            [ (recommendationScoreForWord contextKey word, entity)
            | entity@(Entity _ word) <- wordEntities
            ]

recommendationScoreForWord :: Text -> Word -> Int
recommendationScoreForWord contextKey word =
    let loweredWord = T.toLower (wordText word)
        loweredTranscription = maybe "" T.toLower (wordTranscription word)
        tokens = recommendationTokens contextKey
        matchScore =
            sum $
                map
                    (\token ->
                        if token `T.isInfixOf` loweredWord || token `T.isInfixOf` loweredTranscription
                            then 10
                            else 0
                    )
                    tokens
    in matchScore + T.length (wordText word)

recommendationTokens :: Text -> [Text]
recommendationTokens "comfort" = ["soft", "ha", "ye", "calm"]
recommendationTokens "letter" = ["write", "let", "ly", "dear"]
recommendationTokens "nickname" = ["bright", "star", "lin", "ra"]
recommendationTokens "focus" = ["ref", "core", "clear", "sharp"]
recommendationTokens _ = ["light", "sun", "warm", "new"]

recommendationTitle :: Text -> Text
recommendationTitle "comfort" = "Words for gentler moods"
recommendationTitle "letter" = "Words that read well in letters"
recommendationTitle "nickname" = "Name-friendly picks"
recommendationTitle "focus" = "Clear words for concentrated work"
recommendationTitle _ = "Bright daily picks"

recommendationDescription :: Text -> Text
recommendationDescription "comfort" = "Soft rhythm and calmer shapes for reflective moments."
recommendationDescription "letter" = "Entries that sit naturally in a message, note, or caption."
recommendationDescription "nickname" = "Compact words that can bend into nicknames and handles."
recommendationDescription "focus" = "Sharper entries that feel stable and direct."
recommendationDescription _ = "A lighter set of words to rotate into daily use."

sentenceSuggestions :: Text -> Word -> [Text]
sentenceSuggestions tone word =
    let subject = wordText word
    in case tone of
        "warm" ->
            [ subject <> " is the word I reach for when I want to sound softer."
            , "I kept " <> subject <> " close because it leaves room for warmth."
            , "When the sentence needed calm, " <> subject <> " stayed."
            ]
        "bold" ->
            [ subject <> " lands with enough force to anchor the whole line."
            , "I chose " <> subject <> " because the idea needed a sharper edge."
            , subject <> " gives the sentence a clean, public confidence."
            ]
        _ ->
            [ subject <> " fit the mood without overexplaining it."
            , "I used " <> subject <> " to keep the tone clear and measured."
            , subject <> " worked because it sounded precise but still human."
            ]

nicknameSuggestions :: Text -> [Text]
nicknameSuggestions seedText =
    let cleaned = T.filter (\char -> char /= ' ') seedText
        short = T.take 4 cleaned
        long = T.take 6 cleaned
    in ordNub
        [ short <> "im"
        , short <> "ora"
        , "dear-" <> short
        , long <> "note"
        , "mono-" <> short
        ]

normalizeContext :: Text -> Text
normalizeContext contextParam =
    let lowered = T.toLower $ T.strip contextParam
    in if lowered `elem` ["comfort", "letter", "nickname", "focus", "bright"]
        then lowered
        else "comfort"

normalizeTone :: Text -> Text
normalizeTone toneInput =
    let lowered = T.toLower $ T.strip toneInput
    in if lowered `elem` ["gentle", "warm", "bold"]
        then lowered
        else "gentle"

premiumBadgeValue :: User -> Maybe Text
premiumBadgeValue user
    | userPremium user = Just $ fromMaybe "Premium" (userPremiumBadge user)
    | otherwise = Nothing

canonicalRootUrl :: App -> Text
canonicalRootUrl app =
    let rootUrl = appRoot $ appSettings app
    in fromMaybe rootUrl (T.stripSuffix "/" rootUrl)

wordSeoTitle :: Word -> Text
wordSeoTitle word =
    wordText word <> maybe "" (\transcription -> " [" <> transcription <> "]") (wordTranscription word) <> " | KDIC"

wordSeoDescription :: Word -> [Entity Meaning] -> Text
wordSeoDescription word meanings =
    truncateSeoDescription $
        case meanings of
            Entity _ meaning : _ -> meaningDefinition meaning
            [] -> "Explore the definition, examples, and community stories for " <> wordText word <> "."

truncateSeoDescription :: Text -> Text
truncateSeoDescription textValue
    | T.length compact <= 160 = compact
    | otherwise = T.take 157 compact <> "..."
  where
    compact = T.unwords $ T.words textValue

voteWeightForUser :: User -> Int
voteWeightForUser user
    | userPremium user = 3
    | otherwise = 1

submissionPriorityScoreForUser :: User -> Int
submissionPriorityScoreForUser user
    | userPremium user = 100
    | otherwise = 0

bookmarkLimitValue :: User -> Maybe Int
bookmarkLimitValue user
    | userPremium user = Nothing
    | otherwise = Just freeBookmarkLimit

collectionLimitValue :: User -> Maybe Int
collectionLimitValue user
    | userPremium user = Nothing
    | otherwise = Just freeCollectionLimit

freeBookmarkLimit :: Int
freeBookmarkLimit = 20

freeCollectionLimit :: Int
freeCollectionLimit = 2

homeRightRailAdSlot :: Text
homeRightRailAdSlot = "home_right_rail"

profileRightRailAdSlot :: Text
profileRightRailAdSlot = "profile_right_rail"

wordRightRailAdSlot :: Text
wordRightRailAdSlot = "word_right_rail"

pendingStatus :: Text
pendingStatus = "pending"

approvedStatus :: Text
approvedStatus = "approved"
