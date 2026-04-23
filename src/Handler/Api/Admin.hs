{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Admin where

import Import
import Database.Persist.Sql (fromSqlKey)
import Data.Char (isAlphaNum, isSpace)
import Data.Time.LocalTime (TimeZone, getCurrentTimeZone, localTimeToUTC, utcToLocalTime)
import Handler.Api.Shared (apiError, cleanOptionalText, isoTime, userValue)
import Yesod.Auth.HashDB (setPassword)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

getApiAdminDashboardR :: Handler Value
getApiAdminDashboardR = do
    (viewerId, _viewer) <- requireAdminApi
    totalWords <- runDB $ count ([] :: [Filter Word])
    totalUsers <- runDB $ count ([] :: [Filter User])
    premiumUsers <- runDB $ count [UserPremium ==. True]
    totalSettings <- runDB $ count ([] :: [Filter SiteSetting])
    pendingSubmissions <- runDB $ count [WordSubmissionStatus ==. pendingStatus]
    recentWords <- runDB $ selectList [] [Desc WordId, LimitTo 5]
    ads <- runDB $ selectList [] [Asc AdSlot, Asc AdSortOrder, Desc AdUpdatedAt]
    timezone <- liftIO getCurrentTimeZone
    now <- liftIO getCurrentTime
    let totalAds = length ads
        liveAds = length $ filter (isAdServingAt now . entityVal) ads
        totalAdImpressions = sum $ map (adImpressionCount . entityVal) ads
        totalAdClicks = sum $ map (adClickCount . entityVal) ads
        topAds =
            take 5 $
                sortOn
                    (\(Entity _ ad) -> (negate (adClickCount ad), negate (adImpressionCount ad), adSlot ad, adTitle ad))
                    ads
    returnJson $
        object
            [ "viewer" .= fromSqlKey viewerId
            , "stats" .= object
                [ "totalWords" .= totalWords
                , "totalUsers" .= totalUsers
                , "premiumUsers" .= premiumUsers
                , "pendingSubmissions" .= pendingSubmissions
                , "totalSettings" .= totalSettings
                , "totalAds" .= totalAds
                , "liveAds" .= liveAds
                , "totalAdImpressions" .= totalAdImpressions
                , "totalAdClicks" .= totalAdClicks
                ]
            , "recentWords" .= map adminWordValue recentWords
            , "topAds" .= map (adminAdValue timezone now) topAds
            ]

getApiAdminOpsR :: Handler Value
getApiAdminOpsR = do
    _ <- requireAdminApi
    logs <- runDB $ selectList [] [Desc AdminActionLogCreatedAt, LimitTo 40]
    adminMap <- loadAdminUserMap $ mapMaybe (adminActionLogAdmin . entityVal) logs
    returnJson $
        object
            [ "healthUrl" .= ("/healthz" :: Text)
            , "sitemapUrl" .= ("/sitemap.xml" :: Text)
            , "backupCommand" .= ("./scripts/backup.sh" :: Text)
            , "restoreCommand" .= ("./scripts/restore.sh /path/to/archive.tar.gz" :: Text)
            , "deployChecklist" .= deployChecklistItems
            , "monitoringChecklist" .= monitoringChecklistItems
            , "recentActions" .= map (adminActionLogValue adminMap) logs
            ]

getApiAdminWordsR :: Handler Value
getApiAdminWordsR = do
    _ <- requireAdminApi
    wordEntities <- runDB $ selectList [] [Asc WordText]
    returnJson $ object ["items" .= map adminWordValue wordEntities]

postApiAdminWordsR :: Handler Value
postApiAdminWordsR = do
    (adminId, _adminUser) <- requireAdminApi
    text <- T.strip <$> runInputPost (ireq textField "text")
    transcription <- cleanOptionalText <$> runInputPost (iopt textField "transcription")
    when (text == "") $
        apiError status400 "Word text is required."
    existingWord <- runDB $ getBy $ UniqueWord text
    when (isJust existingWord) $
        apiError status400 "That word already exists."
    wordId <- runDB $ insert $ Word text transcription Nothing
    word <- runDB $ get404 wordId
    recordAdminAction adminId "word.create" "word" (Just $ tshow $ fromSqlKey wordId) ("Created dictionary word " <> text <> ".") transcription
    returnJson $
        object
            [ "item" .= adminWordValue (Entity wordId word)
            , "message" .= ("Word created." :: Text)
            ]

getApiAdminWordR :: WordId -> Handler Value
getApiAdminWordR wordId = do
    _ <- requireAdminApi
    word <- runDB $ get404 wordId
    returnJson $ object ["item" .= adminWordValue (Entity wordId word)]

postApiAdminWordR :: WordId -> Handler Value
postApiAdminWordR wordId = do
    (adminId, _adminUser) <- requireAdminApi
    currentWord <- runDB $ get404 wordId
    text <- T.strip <$> runInputPost (ireq textField "text")
    transcription <- cleanOptionalText <$> runInputPost (iopt textField "transcription")
    when (text == "") $
        apiError status400 "Word text is required."
    existingWord <- runDB $ getBy $ UniqueWord text
    case existingWord of
        Just (Entity existingWordId _)
            | existingWordId /= wordId ->
                apiError status400 "That word already exists."
        _ -> pure ()
    let updatedWord =
            currentWord
                { wordText = text
                , wordTranscription = transcription
                }
    runDB $ replace wordId updatedWord
    recordAdminAction adminId "word.update" "word" (Just $ tshow $ fromSqlKey wordId) ("Updated dictionary word " <> text <> ".") transcription
    returnJson $
        object
            [ "item" .= adminWordValue (Entity wordId updatedWord)
            , "message" .= ("Word updated." :: Text)
            ]

getApiAdminSubmissionsR :: Handler Value
getApiAdminSubmissionsR = do
    _ <- requireAdminApi
    submissions <- runDB $ selectList [] [Desc WordSubmissionPriorityScore, Desc WordSubmissionSubmittedAt]
    creatorMap <- loadAdminUserMap $ map (wordSubmissionCreator . entityVal) submissions
    approverMap <- loadAdminUserMap $ mapMaybe (wordSubmissionApprovedBy . entityVal) submissions
    voteCountMap <- loadSubmissionVoteCounts submissions
    returnJson $
        object
            [ "items" .= map (adminSubmissionValue creatorMap approverMap voteCountMap) submissions
            ]

postApiAdminSubmissionApproveR :: WordSubmissionId -> Handler Value
postApiAdminSubmissionApproveR submissionId = do
    (adminId, _adminUser) <- requireAdminApi
    submission <- runDB $ get404 submissionId
    when (wordSubmissionStatus submission /= pendingStatus) $
        apiError status400 "Only pending submissions can be approved."
    existingWord <- runDB $ getBy $ UniqueWord (wordSubmissionText submission)
    wordId <- case existingWord of
        Just (Entity existingWordId _) ->
            pure existingWordId
        Nothing ->
            runDB $
                insert $
                    Word
                        (wordSubmissionText submission)
                        (wordSubmissionTranscription submission)
                        (wordSubmissionPronunciationUrl submission)
    now <- liftIO getCurrentTime
    runDB $
        update submissionId
            [ WordSubmissionStatus =. approvedStatus
            , WordSubmissionUpdatedAt =. now
            , WordSubmissionApprovedAt =. Just now
            , WordSubmissionApprovedBy =. Just adminId
            , WordSubmissionPromotedWord =. Just wordId
            ]
    updatedSubmission <- runDB $ get404 submissionId
    creatorMap <- loadAdminUserMap [wordSubmissionCreator updatedSubmission]
    approverMap <- loadAdminUserMap [adminId]
    voteCountMap <- loadSubmissionVoteCounts [Entity submissionId updatedSubmission]
    recordAdminAction adminId "submission.approve" "submission" (Just $ tshow $ fromSqlKey submissionId) ("Approved word submission " <> wordSubmissionText updatedSubmission <> ".") (Just $ "promotedWordId=" <> tshow (fromSqlKey wordId))
    returnJson $
        object
            [ "item" .= adminSubmissionValue creatorMap approverMap voteCountMap (Entity submissionId updatedSubmission)
            , "message" .= ("Submission approved." :: Text)
            ]

postApiAdminSubmissionRejectR :: WordSubmissionId -> Handler Value
postApiAdminSubmissionRejectR submissionId = do
    (adminId, _adminUser) <- requireAdminApi
    submission <- runDB $ get404 submissionId
    when (wordSubmissionStatus submission /= pendingStatus) $
        apiError status400 "Only pending submissions can be rejected."
    now <- liftIO getCurrentTime
    runDB $
        update submissionId
            [ WordSubmissionStatus =. rejectedStatus
            , WordSubmissionUpdatedAt =. now
            ]
    updatedSubmission <- runDB $ get404 submissionId
    creatorMap <- loadAdminUserMap [wordSubmissionCreator updatedSubmission]
    approverMap <- pure Map.empty
    voteCountMap <- loadSubmissionVoteCounts [Entity submissionId updatedSubmission]
    recordAdminAction adminId "submission.reject" "submission" (Just $ tshow $ fromSqlKey submissionId) ("Rejected word submission " <> wordSubmissionText updatedSubmission <> ".") Nothing
    returnJson $
        object
            [ "item" .= adminSubmissionValue creatorMap approverMap voteCountMap (Entity submissionId updatedSubmission)
            , "message" .= ("Submission rejected." :: Text)
            ]

getApiAdminAdsR :: Handler Value
getApiAdminAdsR = do
    _ <- requireAdminApi
    ads <- runDB $ selectList [] [Asc AdSlot, Asc AdSortOrder, Desc AdUpdatedAt]
    timezone <- liftIO getCurrentTimeZone
    now <- liftIO getCurrentTime
    returnJson $
        object
            [ "items" .= map (adminAdValue timezone now) ads
            , "meta" .= object
                [ "availableSlots" .= map slotOptionValue availableAdSlots
                , "availableKinds" .= availableAdKinds
                ]
            ]

postApiAdminAdsR :: Handler Value
postApiAdminAdsR = do
    (adminId, _adminUser) <- requireAdminApi
    timezone <- liftIO getCurrentTimeZone
    now <- liftIO getCurrentTime
    newAd <- parseAdForm timezone now
    adId <- runDB $ insert newAd
    ad <- runDB $ get404 adId
    recordAdminAction adminId "ad.create" "ad" (Just $ tshow $ fromSqlKey adId) ("Created ad " <> adTitle ad <> ".") (Just $ "slot=" <> adSlot ad <> ", kind=" <> adKind ad)
    returnJson $
        object
            [ "item" .= adminAdValue timezone now (Entity adId ad)
            , "message" .= ("Ad created." :: Text)
            ]

getApiAdminAdR :: AdId -> Handler Value
getApiAdminAdR adId = do
    _ <- requireAdminApi
    timezone <- liftIO getCurrentTimeZone
    now <- liftIO getCurrentTime
    ad <- runDB $ get404 adId
    returnJson $
        object
            [ "item" .= adminAdValue timezone now (Entity adId ad)
            , "meta" .= object
                [ "availableSlots" .= map slotOptionValue availableAdSlots
                , "availableKinds" .= availableAdKinds
                ]
            ]

postApiAdminAdR :: AdId -> Handler Value
postApiAdminAdR adId = do
    (adminId, _adminUser) <- requireAdminApi
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            ad <- runDB $ get404 adId
            runDB $ delete adId
            recordAdminAction adminId "ad.delete" "ad" (Just $ tshow $ fromSqlKey adId) ("Deleted ad " <> adTitle ad <> ".") (Just $ "slot=" <> adSlot ad)
            returnJson $ object ["message" .= ("Ad deleted." :: Text)]
        _ -> do
            currentAd <- runDB $ get404 adId
            timezone <- liftIO getCurrentTimeZone
            now <- liftIO getCurrentTime
            updatedAd <- parseAdUpdateForm timezone now currentAd
            runDB $ replace adId updatedAd
            recordAdminAction adminId "ad.update" "ad" (Just $ tshow $ fromSqlKey adId) ("Updated ad " <> adTitle updatedAd <> ".") (Just $ "slot=" <> adSlot updatedAd <> ", kind=" <> adKind updatedAd)
            returnJson $
                object
                    [ "item" .= adminAdValue timezone now (Entity adId updatedAd)
                    , "message" .= ("Ad updated." :: Text)
                    ]

getApiAdminUsersR :: Handler Value
getApiAdminUsersR = do
    (viewerId, _viewer) <- requireAdminApi
    users <- runDB $ selectList [] [Asc UserIdent]
    returnJson $
        object
            [ "items" .= map (adminUserRecordValue (Just viewerId)) users
            ]

postApiAdminUsersR :: Handler Value
postApiAdminUsersR = do
    (adminId, _adminUser) <- requireAdminApi
    ident <- T.strip <$> runInputPost (ireq textField "ident")
    password <- runInputPost $ ireq textField "password"
    nameValue <- cleanOptionalText <$> runInputPost (iopt textField "name")
    descriptionValue <- cleanOptionalText <$> runInputPost (iopt textField "description")
    roleValue <- normalizeUserRole <$> runInputPost (ireq textField "role")
    premiumValue <- runInputPost $ fmap isJust (iopt textField "premium")
    badgeValue <- cleanOptionalText <$> runInputPost (iopt textField "premiumBadge")
    when (ident == "") $
        apiError status400 "Username is required."
    existingUser <- runDB $ getBy $ UniqueUser ident
    when (isJust existingUser) $
        apiError status400 "Username already exists."
    let baseUser = User ident Nothing roleValue nameValue descriptionValue premiumValue badgeValue
    user <- liftIO $ setPassword password baseUser
    userId <- runDB $ insert user
    createdUser <- runDB $ get404 userId
    recordAdminAction adminId "user.create" "user" (Just $ tshow $ fromSqlKey userId) ("Created user " <> ident <> ".") (Just $ "role=" <> roleValue)
    returnJson $
        object
            [ "item" .= adminUserRecordValue Nothing (Entity userId createdUser)
            , "message" .= ("User created." :: Text)
            ]

getApiAdminUserR :: UserId -> Handler Value
getApiAdminUserR userId = do
    (viewerId, _viewer) <- requireAdminApi
    user <- runDB $ get404 userId
    returnJson $ object ["item" .= adminUserRecordValue (Just viewerId) (Entity userId user)]

postApiAdminUserR :: UserId -> Handler Value
postApiAdminUserR userId = do
    (viewerId, _viewer) <- requireAdminApi
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            when (viewerId == userId) $
                apiError status400 "You cannot delete the account you are currently using."
            deletedUser <- runDB $ get404 userId
            userSubmissions <- runDB $ selectList [WordSubmissionCreator ==. userId] []
            let userSubmissionIds = map entityKey userSubmissions
            runDB $ deleteWhere [NotificationUser ==. userId]
            runDB $ deleteWhere [NotificationActor ==. Just userId]
            runDB $ deleteWhere [FollowingFollower ==. userId]
            runDB $ deleteWhere [FollowingFollowee ==. userId]
            runDB $ deleteWhere [WordBookmarkUser ==. userId]
            runDB $ deleteWhere [WordLikeUser ==. userId]
            runDB $ deleteWhere [WordCommentAuthor ==. userId]
            runDB $ deleteWhere [WordSubmissionVoteUser ==. userId]
            unless (null userSubmissionIds) $
                runDB $ deleteWhere [WordSubmissionVoteSubmission <-. userSubmissionIds]
            runDB $ updateWhere [WordSubmissionApprovedBy ==. Just userId] [WordSubmissionApprovedBy =. Nothing]
            runDB $ updateWhere [AdminActionLogAdmin ==. Just userId] [AdminActionLogAdmin =. Nothing]
            runDB $ deleteWhere [UploadOwnerId ==. userId]
            runDB $ deleteWhere [EmailUser ==. Just userId]
            runDB $ deleteWhere [WordSubmissionCreator ==. userId]
            runDB $ delete userId
            recordAdminAction viewerId "user.delete" "user" (Just $ tshow $ fromSqlKey userId) ("Deleted user " <> userIdent deletedUser <> ".") Nothing
            returnJson $ object ["message" .= ("User deleted." :: Text)]
        _ -> do
            currentUser <- runDB $ get404 userId
            ident <- T.strip <$> runInputPost (ireq textField "ident")
            roleValue <- normalizeUserRole <$> runInputPost (ireq textField "role")
            premiumValue <- runInputPost $ fmap isJust (iopt textField "premium")
            badgeValue <- cleanOptionalText <$> runInputPost (iopt textField "premiumBadge")
            nameValue <- cleanOptionalText <$> runInputPost (iopt textField "name")
            descriptionValue <- cleanOptionalText <$> runInputPost (iopt textField "description")
            rawPassword <- fromMaybe "" <$> runInputPost (iopt textField "password")
            when (ident == "") $
                apiError status400 "Username is required."
            existingUser <- runDB $ getBy $ UniqueUser ident
            case existingUser of
                Just (Entity existingUserId _)
                    | existingUserId /= userId ->
                        apiError status400 "Username already exists."
                _ -> pure ()
            let updatedBase =
                    currentUser
                        { userIdent = ident
                        , userRole = roleValue
                        , userName = nameValue
                        , userDescription = descriptionValue
                        , userPremium = premiumValue
                        , userPremiumBadge = badgeValue
                        }
            updatedUser <-
                if T.strip rawPassword == ""
                    then pure updatedBase
                    else liftIO $ setPassword rawPassword updatedBase
            runDB $ replace userId updatedUser
            recordAdminAction viewerId "user.update" "user" (Just $ tshow $ fromSqlKey userId) ("Updated user " <> userIdent updatedUser <> ".") (Just $ "role=" <> userRole updatedUser)
            returnJson $
                object
                    [ "item" .= adminUserRecordValue (Just viewerId) (Entity userId updatedUser)
                    , "message" .= ("User updated." :: Text)
                    ]

getApiAdminSettingsR :: Handler Value
getApiAdminSettingsR = do
    _ <- requireAdminApi
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
    mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
    returnJson $
        object
            [ "siteIdentity" .= object
                [ "siteTitle" .= maybe "" (siteSettingValue . entityVal) mSiteTitle
                , "siteSubtitle" .= maybe "" (siteSettingValue . entityVal) mSiteSubtitle
                ]
            , "items" .= map adminSettingValue settings
            ]

postApiAdminSettingsR :: Handler Value
postApiAdminSettingsR = do
    (adminId, _adminUser) <- requireAdminApi
    action <- runInputPost $ ireq textField "action"
    case action of
        "site-identity" -> do
            siteTitle <- T.strip <$> runInputPost (ireq textField "site_title")
            siteSubtitle <- fromMaybe "" <$> runInputPost (iopt textField "site_subtitle")
            when (siteTitle == "") $
                apiError status400 "Site title is required."
            upsertSetting "site_title" siteTitle
            upsertSetting "site_subtitle" siteSubtitle
            recordAdminAction adminId "settings.identity" "site" Nothing "Updated site identity." (Just $ "title=" <> siteTitle)
            returnJson $
                object
                    [ "message" .= ("Site identity updated." :: Text)
                    , "siteIdentity" .= object
                        [ "siteTitle" .= siteTitle
                        , "siteSubtitle" .= siteSubtitle
                        ]
                    ]
        "delete" -> do
            key <- runInputPost $ ireq textField "key"
            runDB $ deleteBy $ UniqueSiteSetting key
            recordAdminAction adminId "setting.delete" "setting" (Just key) ("Deleted setting " <> key <> ".") Nothing
            returnJson $ object ["message" .= ("Setting deleted." :: Text)]
        _ -> do
            key <- T.strip <$> runInputPost (ireq textField "key")
            value <- runInputPost $ ireq textField "value"
            when (key == "") $
                apiError status400 "Setting key is required."
            upsertSetting key value
            recordAdminAction adminId "setting.upsert" "setting" (Just key) ("Saved setting " <> key <> ".") (Just value)
            mSetting <- runDB $ getBy $ UniqueSiteSetting key
            case mSetting of
                Just setting ->
                    returnJson $
                        object
                            [ "item" .= adminSettingValue setting
                            , "message" .= ("Setting saved." :: Text)
                            ]
                Nothing ->
                    apiError status400 "Unable to save setting."

getApiAdminSettingR :: SiteSettingId -> Handler Value
getApiAdminSettingR settingId = do
    _ <- requireAdminApi
    setting <- runDB $ get404 settingId
    returnJson $ object ["item" .= adminSettingValue (Entity settingId setting)]

postApiAdminSettingR :: SiteSettingId -> Handler Value
postApiAdminSettingR settingId = do
    (adminId, _adminUser) <- requireAdminApi
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            setting <- runDB $ get404 settingId
            runDB $ delete settingId
            recordAdminAction adminId "setting.delete" "setting" (Just $ siteSettingKey setting) ("Deleted setting " <> siteSettingKey setting <> ".") Nothing
            returnJson $ object ["message" .= ("Setting deleted." :: Text)]
        _ -> do
            setting <- runDB $ get404 settingId
            value <- runInputPost $ ireq textField "value"
            let updatedSetting = setting {siteSettingValue = value}
            runDB $ replace settingId updatedSetting
            recordAdminAction adminId "setting.update" "setting" (Just $ siteSettingKey updatedSetting) ("Updated setting " <> siteSettingKey updatedSetting <> ".") (Just value)
            returnJson $
                object
                    [ "item" .= adminSettingValue (Entity settingId updatedSetting)
                    , "message" .= ("Setting updated." :: Text)
                    ]

requireAdminApi :: Handler (UserId, User)
requireAdminApi = do
    mAuth <- maybeAuth
    case mAuth of
        Nothing ->
            apiError status401 "Authentication required."
        Just (Entity userId user)
            | userRole user /= ("admin" :: Text) ->
                apiError status403 "Admin access required."
            | otherwise ->
                pure (userId, user)

adminWordValue :: Entity Word -> Value
adminWordValue (Entity wordId word) =
    object
        [ "id" .= fromSqlKey wordId
        , "text" .= wordText word
        , "transcription" .= wordTranscription word
        , "pronunciationUrl" .= wordPronunciationUrl word
        ]

adminSubmissionValue :: Map.Map UserId User -> Map.Map UserId User -> Map.Map WordSubmissionId Int -> Entity WordSubmission -> Value
adminSubmissionValue creatorMap approverMap voteCountMap (Entity submissionId submission) =
    object
        [ "id" .= fromSqlKey submissionId
        , "text" .= wordSubmissionText submission
        , "transcription" .= wordSubmissionTranscription submission
        , "pronunciationUrl" .= wordSubmissionPronunciationUrl submission
        , "status" .= wordSubmissionStatus submission
        , "priorityScore" .= wordSubmissionPriorityScore submission
        , "voteCount" .= fromMaybe 0 (Map.lookup submissionId voteCountMap)
        , "submittedAt" .= isoTime (wordSubmissionSubmittedAt submission)
        , "updatedAt" .= isoTime (wordSubmissionUpdatedAt submission)
        , "approvedAt" .= fmap isoTime (wordSubmissionApprovedAt submission)
        , "promotedWordId" .= fmap fromSqlKey (wordSubmissionPromotedWord submission)
        , "creator" .= maybe Null userValue (Map.lookup (wordSubmissionCreator submission) creatorMap)
        , "approvedBy" .=
            maybe Null userValue
                (wordSubmissionApprovedBy submission >>= (`Map.lookup` approverMap))
        ]

adminAdValue :: TimeZone -> UTCTime -> Entity Ad -> Value
adminAdValue timezone now (Entity adId ad) =
    object
        [ "id" .= fromSqlKey adId
        , "slot" .= adSlot ad
        , "kind" .= adKind ad
        , "title" .= adTitle ad
        , "body" .= adBody ad
        , "link" .= adLink ad
        , "ctaLabel" .= adCtaLabel ad
        , "imageUrl" .= adImageUrl ad
        , "embedHtml" .= adEmbedHtml ad
        , "sortOrder" .= adSortOrder ad
        , "isActive" .= adIsActive ad
        , "startAt" .= fmap isoTime (adStartAt ad)
        , "endAt" .= fmap isoTime (adEndAt ad)
        , "startAtInput" .= formatDateTimeInput timezone (adStartAt ad)
        , "endAtInput" .= formatDateTimeInput timezone (adEndAt ad)
        , "impressionCount" .= adImpressionCount ad
        , "lastImpressionAt" .= fmap isoTime (adLastImpressionAt ad)
        , "clickCount" .= adClickCount ad
        , "lastClickedAt" .= fmap isoTime (adLastClickedAt ad)
        , "lifecycle" .= adLifecycleLabel now ad
        , "clickUrl" .= ("/ads/" <> toPathPiece adId <> "/click" :: Text)
        ]

adminUserRecordValue :: Maybe UserId -> Entity User -> Value
adminUserRecordValue mViewerId (Entity userId user) =
    object
        [ "id" .= fromSqlKey userId
        , "ident" .= userIdent user
        , "displayName" .= fromMaybe (userIdent user) (userName user)
        , "name" .= userName user
        , "description" .= userDescription user
        , "role" .= userRole user
        , "isAdmin" .= (userRole user == ("admin" :: Text))
        , "isPremium" .= userPremium user
        , "premiumBadge" .= userPremiumBadge user
        , "isCurrent" .= maybe False (== userId) mViewerId
        ]

adminSettingValue :: Entity SiteSetting -> Value
adminSettingValue (Entity settingId setting) =
    object
        [ "id" .= fromSqlKey settingId
        , "key" .= siteSettingKey setting
        , "value" .= siteSettingValue setting
        ]

adminActionLogValue :: Map.Map UserId User -> Entity AdminActionLog -> Value
adminActionLogValue adminMap (Entity logId actionLog) =
    object
        [ "id" .= fromSqlKey logId
        , "action" .= adminActionLogAction actionLog
        , "targetType" .= adminActionLogTargetType actionLog
        , "targetId" .= adminActionLogTargetId actionLog
        , "summary" .= adminActionLogSummary actionLog
        , "details" .= adminActionLogDetails actionLog
        , "createdAt" .= isoTime (adminActionLogCreatedAt actionLog)
        , "admin" .= adminActorValue adminMap actionLog
        ]

adminActorValue :: Map.Map UserId User -> AdminActionLog -> Value
adminActorValue adminMap actionLog =
    case adminActionLogAdmin actionLog >>= (`Map.lookup` adminMap) of
        Just adminUser ->
            userValue adminUser
        Nothing ->
            object
                [ "ident" .= adminActionLogAdminIdent actionLog
                , "displayName" .= fromMaybe (adminActionLogAdminIdent actionLog) (adminActionLogAdminDisplayName actionLog)
                , "description" .= (Nothing :: Maybe Text)
                , "role" .= ("admin" :: Text)
                , "isAdmin" .= True
                , "isPremium" .= False
                , "premiumBadge" .= (Nothing :: Maybe Text)
                ]

loadAdminUserMap :: [UserId] -> Handler (Map.Map UserId User)
loadAdminUserMap userIds
    | null uniqueIds = pure Map.empty
    | otherwise = do
        users <- runDB $ selectList [UserId <-. uniqueIds] []
        pure $ Map.fromList $ map (\(Entity userId user) -> (userId, user)) users
  where
    uniqueIds = ordNub userIds

loadSubmissionVoteCounts :: [Entity WordSubmission] -> Handler (Map.Map WordSubmissionId Int)
loadSubmissionVoteCounts submissions
    | null submissionIds = pure Map.empty
    | otherwise = do
        counts <- forM submissionIds $ \submissionId -> do
            votes <- runDB $ selectList [WordSubmissionVoteSubmission ==. submissionId] []
            pure (submissionId, sum $ map (wordSubmissionVoteWeight . entityVal) votes)
        pure $ Map.fromList counts
  where
    submissionIds = map entityKey submissions

upsertSetting :: Text -> Text -> Handler ()
upsertSetting key value = do
    existing <- runDB $ getBy $ UniqueSiteSetting key
    case existing of
        Just (Entity settingId _) ->
            runDB $ update settingId [SiteSettingValue =. value]
        Nothing -> do
            _ <- runDB $ insert $ SiteSetting key value
            pure ()

slotOptionValue :: (Text, Text) -> Value
slotOptionValue (slotKey, slotLabel) =
    object
        [ "key" .= slotKey
        , "label" .= slotLabel
        ]

parseAdForm :: TimeZone -> UTCTime -> Handler Ad
parseAdForm timezone now = do
    title <- T.strip <$> runInputPost (ireq textField "title")
    slotValue <- normalizeAdminAdSlot <$> runInputPost (ireq textField "slot")
    kindValue <- normalizeAdminAdKind <$> runInputPost (ireq textField "kind")
    bodyValue <- cleanOptionalText <$> runInputPost (iopt textField "body")
    linkValue <- cleanOptionalText <$> runInputPost (iopt textField "link")
    ctaLabelValue <- cleanOptionalText <$> runInputPost (iopt textField "ctaLabel")
    imageUrlValue <- cleanOptionalText <$> runInputPost (iopt textField "imageUrl")
    embedHtmlValue <- cleanOptionalText <$> runInputPost (iopt textField "embedHtml")
    startAtValue <- parseAdminDateTimeInput timezone <$> runInputPost (iopt textField "startAt")
    endAtValue <- parseAdminDateTimeInput timezone <$> runInputPost (iopt textField "endAt")
    sortOrderValue <- runInputPost $ ireq intField "sortOrder"
    isActiveValue <- runInputPost $ fmap isJust (iopt textField "isActive")
    validatedEmbedHtmlValue <- validateAdFields title slotValue kindValue bodyValue linkValue imageUrlValue embedHtmlValue startAtValue endAtValue
    pure $
        Ad
            slotValue
            kindValue
            title
            bodyValue
            linkValue
            ctaLabelValue
            imageUrlValue
            validatedEmbedHtmlValue
            sortOrderValue
            isActiveValue
            startAtValue
            endAtValue
            0
            Nothing
            0
            Nothing
            now
            now

parseAdUpdateForm :: TimeZone -> UTCTime -> Ad -> Handler Ad
parseAdUpdateForm timezone now currentAd = do
    title <- T.strip <$> runInputPost (ireq textField "title")
    slotValue <- normalizeAdminAdSlot <$> runInputPost (ireq textField "slot")
    kindValue <- normalizeAdminAdKind <$> runInputPost (ireq textField "kind")
    bodyValue <- cleanOptionalText <$> runInputPost (iopt textField "body")
    linkValue <- cleanOptionalText <$> runInputPost (iopt textField "link")
    ctaLabelValue <- cleanOptionalText <$> runInputPost (iopt textField "ctaLabel")
    imageUrlValue <- cleanOptionalText <$> runInputPost (iopt textField "imageUrl")
    embedHtmlValue <- cleanOptionalText <$> runInputPost (iopt textField "embedHtml")
    startAtValue <- parseAdminDateTimeInput timezone <$> runInputPost (iopt textField "startAt")
    endAtValue <- parseAdminDateTimeInput timezone <$> runInputPost (iopt textField "endAt")
    sortOrderValue <- runInputPost $ ireq intField "sortOrder"
    isActiveValue <- runInputPost $ fmap isJust (iopt textField "isActive")
    validatedEmbedHtmlValue <- validateAdFields title slotValue kindValue bodyValue linkValue imageUrlValue embedHtmlValue startAtValue endAtValue
    pure $
        currentAd
            { adSlot = slotValue
            , adKind = kindValue
            , adTitle = title
            , adBody = bodyValue
            , adLink = linkValue
            , adCtaLabel = ctaLabelValue
            , adImageUrl = imageUrlValue
            , adEmbedHtml = validatedEmbedHtmlValue
            , adSortOrder = sortOrderValue
            , adIsActive = isActiveValue
            , adStartAt = startAtValue
            , adEndAt = endAtValue
            , adUpdatedAt = now
            }

validateAdFields :: Text -> Text -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe UTCTime -> Maybe UTCTime -> Handler (Maybe Text)
validateAdFields title slotValue kindValue bodyValue linkValue imageUrlValue embedHtmlValue startAtValue endAtValue = do
    when (title == "") $
        apiError status400 "Title is required."
    when (not (slotValue `elem` map fst availableAdSlots)) $
        apiError status400 "Choose a valid ad slot."
    when (not (kindValue `elem` availableAdKinds)) $
        apiError status400 "Choose a valid ad type."
    when (isInvalidAdSchedule startAtValue endAtValue) $
        apiError status400 "End time must be later than the start time."
    validateUrlField "Link URL" linkValue
    validateUrlField "Image URL" imageUrlValue
    when (kindValue == "custom" && isNothing bodyValue && isNothing imageUrlValue && isNothing linkValue) $
        apiError status400 "Custom ads need body copy, image, or a destination link."
    validateEmbedHtml kindValue embedHtmlValue

validateEmbedHtml :: Text -> Maybe Text -> Handler (Maybe Text)
validateEmbedHtml kindValue embedHtmlValue
    | kindValue /= "embed" = pure Nothing
    | otherwise = do
        value <- maybe (apiError status400 "Embed HTML is required for embed ads.") pure (cleanOptionalText embedHtmlValue)
        when (T.length value > 8000) $
            apiError status400 "Embed HTML must be 8000 characters or fewer."
        let lowered = T.toLower value
            blockedFragments =
                [ "<object"
                , "<embed"
                , "<form"
                , "<base"
                , "<meta"
                , "<iframe"
                , "<img"
                , "<link"
                , "<style"
                , "<video"
                , "<audio"
                , "javascript:"
                , "data:text/html"
                , "srcdoc="
                ]
        when (any (`T.isInfixOf` lowered) blockedFragments) $
            apiError status400 "Embed HTML contains blocked elements or protocols."
        when (containsInlineEventHandler lowered) $
            apiError status400 "Inline event handlers are not allowed in embed HTML."
        when (not (all (`elem` ["script", "ins"]) (extractTagNames lowered))) $
            apiError status400 "Embed HTML only supports Google Ads script and ins tags."
        when (not (isAllowedGoogleEmbed lowered)) $
            apiError status400 "Embed HTML must match the supported Google Ads snippet pattern."
        when (not (allAllowedEmbedSources lowered)) $
            apiError status400 "Embed script sources must use the supported Google Ads domains."
        when (any isDisallowedInlineScript (extractScriptBodies lowered)) $
            apiError status400 "Inline embed scripts must use the standard adsbygoogle push call."
        pure (Just value)

isAllowedGoogleEmbed :: Text -> Bool
isAllowedGoogleEmbed lowered =
    "<ins" `T.isInfixOf` lowered
        && "adsbygoogle" `T.isInfixOf` lowered
        && ("pagead2.googlesyndication.com/pagead/js/adsbygoogle.js" `T.isInfixOf` lowered
            || "partner.googleadservices.com" `T.isInfixOf` lowered
            || "www.googletagservices.com" `T.isInfixOf` lowered)

allAllowedEmbedSources :: Text -> Bool
allAllowedEmbedSources html =
    all srcIsAllowedForEmbed (extractAttributeValues "src=" html)

srcIsAllowedForEmbed :: Text -> Bool
srcIsAllowedForEmbed rawSrcValue =
    any (`T.isPrefixOf` normalizedSrcValue)
        [ "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"
        , "https://partner.googleadservices.com/"
        , "https://www.googletagservices.com/"
        ]
  where
    normalizedSrcValue
        | "//" `T.isPrefixOf` rawSrcValue = "https:" <> rawSrcValue
        | otherwise = rawSrcValue

extractAttributeValues :: Text -> Text -> [Text]
extractAttributeValues needle haystack =
    case T.breakOn needle haystack of
        (_before, matched)
            | T.null matched -> []
            | otherwise ->
                let raw = T.drop (T.length needle) matched
                    value =
                        case T.uncons raw of
                            Just ('"', rest) -> T.takeWhile (/= '"') rest
                            Just ('\'', rest) -> T.takeWhile (/= '\'') rest
                            _ -> T.takeWhile (\char -> char /= ' ' && char /= '>') raw
                    remainder = T.drop (T.length value) raw
                in value : extractAttributeValues needle remainder

extractTagNames :: Text -> [Text]
extractTagNames html =
    case T.breakOn "<" html of
        (_before, matched)
            | T.null matched -> []
            | otherwise ->
                let afterOpen = T.drop 1 matched
                    afterSlash = fromMaybe afterOpen (T.stripPrefix "/" afterOpen)
                    tagName = T.takeWhile isTagNameChar afterSlash
                    rest = T.dropWhile (/= '>') afterOpen
                    nextHtml = if T.null rest then "" else T.drop 1 rest
                in case tagName of
                    "" -> extractTagNames nextHtml
                    "!--" -> extractTagNames nextHtml
                    _ -> tagName : extractTagNames nextHtml

isTagNameChar :: Char -> Bool
isTagNameChar char = isAlphaNum char || char `elem` ("-:" :: String)

containsInlineEventHandler :: Text -> Bool
containsInlineEventHandler html =
    any isEventAttributeName (extractAttributeNames html)

extractAttributeNames :: Text -> [Text]
extractAttributeNames html =
    mapMaybe attributeNameFromRaw (extractRawAttributes html)

extractRawAttributes :: Text -> [Text]
extractRawAttributes html =
    case T.breakOn "<" html of
        (_before, matched)
            | T.null matched -> []
            | otherwise ->
                let tagContent = T.takeWhile (/= '>') $ T.drop 1 matched
                    nextHtml =
                        let rest = T.dropWhile (/= '>') matched
                        in if T.null rest then "" else T.drop 1 rest
                    attributes =
                        case T.words tagContent of
                            [] -> []
                            (_tagName : rawAttributes) -> rawAttributes
                in attributes <> extractRawAttributes nextHtml

attributeNameFromRaw :: Text -> Maybe Text
attributeNameFromRaw rawAttribute =
    cleanOptionalText $
        Just $
            T.takeWhile (\char -> char /= '=' && not (isSpace char)) rawAttribute

isEventAttributeName :: Text -> Bool
isEventAttributeName attributeName =
    "on" `T.isPrefixOf` T.toLower attributeName

extractScriptBodies :: Text -> [Text]
extractScriptBodies html =
    case T.breakOn "<script" html of
        (_before, matched)
            | T.null matched -> []
            | otherwise ->
                let afterOpen = snd $ T.breakOn ">" matched
                    scriptContentWithClose = T.drop 1 afterOpen
                    (scriptBody, afterClose) = T.breakOn "</script>" scriptContentWithClose
                    remainder =
                        if T.null afterClose
                            then ""
                            else T.drop (T.length ("</script>" :: Text)) afterClose
                in scriptBody : extractScriptBodies remainder

isDisallowedInlineScript :: Text -> Bool
isDisallowedInlineScript scriptBody =
    let compactBody = T.toLower $ T.filter (not . isSpace) scriptBody
    in compactBody /= "" && not ("adsbygoogle" `T.isInfixOf` compactBody && ".push(" `T.isInfixOf` compactBody)

validateUrlField :: Text -> Maybe Text -> Handler ()
validateUrlField _ Nothing = pure ()
validateUrlField fieldName (Just value) =
    unless ("https://" `T.isPrefixOf` value || "http://" `T.isPrefixOf` value || "/" `T.isPrefixOf` value) $
        apiError status400 (fieldName <> " must start with https://, http://, or /.")

normalizeUserRole :: Text -> Text
normalizeUserRole rawRole =
    let normalized = T.toLower $ T.strip rawRole
    in if normalized == "admin" then "admin" else "user"

parseAdminDateTimeInput :: TimeZone -> Maybe Text -> Maybe UTCTime
parseAdminDateTimeInput timezone rawValue = do
    value <- cleanOptionalText rawValue
    localTime <- parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M" (unpack value)
    pure $ localTimeToUTC timezone localTime

formatDateTimeInput :: TimeZone -> Maybe UTCTime -> Text
formatDateTimeInput timezone =
    maybe "" (pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M" . utcToLocalTime timezone)

isInvalidAdSchedule :: Maybe UTCTime -> Maybe UTCTime -> Bool
isInvalidAdSchedule startAtValue endAtValue =
    maybe False (\startAt -> maybe False (<= startAt) endAtValue) startAtValue

isAdServingAt :: UTCTime -> Ad -> Bool
isAdServingAt now ad =
    adIsActive ad
        && maybe True (<= now) (adStartAt ad)
        && maybe True (> now) (adEndAt ad)

adLifecycleLabel :: UTCTime -> Ad -> Text
adLifecycleLabel now ad
    | not (adIsActive ad) = "inactive"
    | maybe False (> now) (adStartAt ad) = "scheduled"
    | maybe False (<= now) (adEndAt ad) = "expired"
    | otherwise = "live"

availableAdSlots :: [(Text, Text)]
availableAdSlots =
    [ ("home_right_rail", "Home right rail")
    , ("profile_right_rail", "Profile right rail")
    , ("word_right_rail", "Word detail right rail")
    ]

availableAdKinds :: [Text]
availableAdKinds = ["custom", "embed"]

normalizeAdminAdSlot :: Text -> Text
normalizeAdminAdSlot = T.toLower . T.strip

normalizeAdminAdKind :: Text -> Text
normalizeAdminAdKind = T.toLower . T.strip

pendingStatus :: Text
pendingStatus = "pending"

approvedStatus :: Text
approvedStatus = "approved"

rejectedStatus :: Text
rejectedStatus = "rejected"

recordAdminAction :: UserId -> Text -> Text -> Maybe Text -> Text -> Maybe Text -> Handler ()
recordAdminAction adminId actionName targetType targetId summary details = do
    now <- liftIO getCurrentTime
    adminUser <- runDB $ get404 adminId
    _ <- runDB $ insert $ AdminActionLog (Just adminId) (userIdent adminUser) (userName adminUser) actionName targetType targetId summary details now
    pure ()

deployChecklistItems :: [Text]
deployChecklistItems =
    [ "Run stack test and npm run build before deployment."
    , "Create a backup archive with ./scripts/backup.sh."
    , "Apply migrations by starting the new build against the target database."
    , "Verify /healthz and /sitemap.xml after rollout."
    , "Open /admin/ops and confirm recent admin actions and monitoring links."
    ]

monitoringChecklistItems :: [Text]
monitoringChecklistItems =
    [ "Monitor /healthz from an external uptime probe."
    , "Review application logs for Content-Security-Policy or embed validation failures."
    , "Track ad click and impression changes for suspicious spikes."
    , "Check the admin action log after content, user, or ad moderation work."
    ]
