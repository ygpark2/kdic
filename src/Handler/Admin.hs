{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Admin where

import Import
import Yesod.Auth.HashDB (setPassword)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

getAdminR :: Handler Html
getAdminR = do
    totalWords <- runDB $ count ([] :: [Filter Word])
    totalUsers <- runDB $ count ([] :: [Filter User])
    totalSettings <- runDB $ count ([] :: [Filter SiteSetting])
    pendingSubmissions <- runDB $ count [WordSubmissionStatus ==. pendingStatus]
    recentWords <- runDB $ selectList [] [Desc WordId, LimitTo 4]
    adminPage "overview" "Admin" $(widgetFile "admin/admin")

getAdminWordsR :: Handler Html
getAdminWordsR = do
    words <- runDB $ selectList [] [Asc WordText]
    adminPage "words" "Admin - Words" $(widgetFile "admin/words")

postAdminWordsR :: Handler Html
postAdminWordsR = do
    text <- runInputPost $ ireq textField "text"
    transcription <- runInputPost $ iopt textField "transcription"
    _ <- runDB $ insert $ Word text transcription Nothing
    setMessage "Word added."
    redirect AdminWordsR

getAdminWordNewR :: Handler Html
getAdminWordNewR = do
    let isEditing = False
        formAction = AdminWordsR
        formWordText = "" :: Text
        formTranscription = "" :: Text
        submitLabel = "Create word" :: Text
        headerTitle = "Create a new dictionary word" :: Text
        headerCopy = "Add the entry text and optional transcription." :: Text
    adminPage "words" "Admin - New Word" $(widgetFile "admin/word-edit")

getAdminWordEditR :: WordId -> Handler Html
getAdminWordEditR wordId = do
    word <- runDB $ get404 wordId
    let isEditing = True
        formAction = AdminWordEditR wordId
        formWordText = wordText word
        formTranscription = fromMaybe "" (wordTranscription word)
        submitLabel = "Save changes" :: Text
        headerTitle = "Edit dictionary word" :: Text
        headerCopy = "Update the entry text or transcription." :: Text
    adminPage "words" "Admin - Edit Word" $(widgetFile "admin/word-edit")

postAdminWordEditR :: WordId -> Handler Html
postAdminWordEditR wordId = do
    text <- runInputPost $ ireq textField "text"
    transcription <- runInputPost $ iopt textField "transcription"
    runDB $ update wordId [WordText =. text, WordTranscription =. transcription]
    setMessage "Word updated."
    redirect AdminWordsR

getAdminSubmissionsR :: Handler Html
getAdminSubmissionsR = do
    submissions <- runDB $ selectList [] [Desc WordSubmissionSubmittedAt]
    creatorMap <- loadAdminUserMap $ map (wordSubmissionCreator . entityVal) submissions
    voteCountMap <- loadAdminSubmissionVoteCounts submissions
    mCsrfToken <- reqToken <$> getRequest
    let creatorLabel submission =
            maybe "Unknown user" userIdent (Map.lookup (wordSubmissionCreator submission) creatorMap)
        voteCount submissionId =
            fromMaybe 0 (Map.lookup submissionId voteCountMap)
    adminPage "submissions" "Admin - Word Submissions" $(widgetFile "admin/submissions")

postAdminSubmissionApproveR :: WordSubmissionId -> Handler Html
postAdminSubmissionApproveR submissionId = do
    adminId <- requireAuthId
    submission <- runDB $ get404 submissionId
    if wordSubmissionStatus submission /= pendingStatus
        then setMessage "Only pending submissions can be approved."
        else do
            existingWord <- runDB $ getBy $ UniqueWord (wordSubmissionText submission)
            wordId <- case existingWord of
                Just (Entity existingWordId _) ->
                    pure existingWordId
                Nothing ->
                    runDB $ insert $
                        Word
                            (wordSubmissionText submission)
                            (wordSubmissionTranscription submission)
                            (wordSubmissionPronunciationUrl submission)
            now <- liftIO getCurrentTime
            runDB $ update submissionId
                [ WordSubmissionStatus =. approvedStatus
                , WordSubmissionUpdatedAt =. now
                , WordSubmissionApprovedAt =. Just now
                , WordSubmissionApprovedBy =. Just adminId
                , WordSubmissionPromotedWord =. Just wordId
                ]
            setMessage "Submission approved and promoted to an official word."
    redirect AdminSubmissionsR

postAdminSubmissionRejectR :: WordSubmissionId -> Handler Html
postAdminSubmissionRejectR submissionId = do
    submission <- runDB $ get404 submissionId
    if wordSubmissionStatus submission /= pendingStatus
        then setMessage "Only pending submissions can be rejected."
        else do
            now <- liftIO getCurrentTime
            runDB $ update submissionId
                [ WordSubmissionStatus =. rejectedStatus
                , WordSubmissionUpdatedAt =. now
                ]
            setMessage "Submission rejected."
    redirect AdminSubmissionsR

getAdminUsersR :: Handler Html
getAdminUsersR = do
    users <- runDB $ selectList [] [Asc UserIdent]
    mCsrfToken <- reqToken <$> getRequest
    mUserId <- maybeAuthId
    adminPage "users" "Admin - Users" $(widgetFile "admin/users")

postAdminUsersR :: Handler Html
postAdminUsersR = do
    ident <- T.strip <$> runInputPost (ireq textField "ident")
    password <- runInputPost $ ireq textField "password"
    nameValue <- fmap cleanOptionalText $ runInputPost (iopt textField "name")
    descriptionValue <- fmap cleanOptionalText $ runInputPost (iopt textField "description")
    roleValue <- runInputPost $ ireq textField "role"
    existingUser <- runDB $ getBy $ UniqueUser ident
    case existingUser of
        Just _ -> setMessage "Username already exists."
        Nothing -> do
            let baseUser = User ident Nothing roleValue nameValue descriptionValue
            user <- liftIO $ setPassword password baseUser
            _ <- runDB $ insert user
            setMessage "User created."
    redirect AdminUsersR

getAdminUserNewR :: Handler Html
getAdminUserNewR = do
    let isNew = True
        mUser = Nothing :: Maybe (Entity User)
    mCsrfToken <- reqToken <$> getRequest
    adminPage "users" "Admin - New User" $(widgetFile "admin/admin-user-detail")

getAdminUserR :: UserId -> Handler Html
getAdminUserR userId = do
    user <- runDB $ get404 userId
    let isNew = False
        mUser = Just (Entity userId user)
    mCsrfToken <- reqToken <$> getRequest
    adminPage "users" "Admin - User Detail" $(widgetFile "admin/admin-user-detail")

postAdminUserR :: UserId -> Handler Html
postAdminUserR userId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            mViewerId <- maybeAuthId
            if Just userId == mViewerId
                then setMessage "You cannot delete the account you are currently using."
                else do
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
                    runDB $ deleteWhere [UploadOwnerId ==. userId]
                    runDB $ deleteWhere [EmailUser ==. Just userId]
                    runDB $ deleteWhere [WordSubmissionCreator ==. userId]
                    runDB $ delete userId
                    setMessage "User deleted."
            redirect AdminUsersR
        _ -> do
            currentUser <- runDB $ get404 userId
            ident <- T.strip <$> runInputPost (ireq textField "ident")
            roleValue <- runInputPost $ ireq textField "role"
            nameValue <- fmap cleanOptionalText $ runInputPost (iopt textField "name")
            descriptionValue <- fmap cleanOptionalText $ runInputPost (iopt textField "description")
            rawPassword <- fmap (fromMaybe "") $ runInputPost (iopt textField "password")
            existingUser <- runDB $ getBy $ UniqueUser ident
            case existingUser of
                Just (Entity existingUserId _)
                    | existingUserId /= userId -> setMessage "Username already exists."
                _ -> do
                    let updatedBase =
                            currentUser
                                { userIdent = ident
                                , userRole = roleValue
                                , userName = nameValue
                                , userDescription = descriptionValue
                                }
                    updatedUser <-
                        if T.strip rawPassword == ""
                            then pure updatedBase
                            else liftIO $ setPassword rawPassword updatedBase
                    runDB $ replace userId updatedUser
                    setMessage "User updated."
            redirect $ AdminUserR userId

getAdminSettingsR :: Handler Html
getAdminSettingsR = do
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    mCsrfToken <- reqToken <$> getRequest
    mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
    mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
    let siteTitleValue = maybe "" (siteSettingValue . entityVal) mSiteTitle
        siteSubtitleValue = maybe "" (siteSettingValue . entityVal) mSiteSubtitle
    adminPage "settings" "Admin - Settings" $(widgetFile "admin/settings")

postAdminSettingsR :: Handler Html
postAdminSettingsR = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "site-identity" -> do
            siteTitle <- runInputPost $ ireq textField "site_title"
            siteSubtitle <- fmap (fromMaybe "") $ runInputPost (iopt textField "site_subtitle")
            upsertSetting "site_title" siteTitle
            upsertSetting "site_subtitle" siteSubtitle
            setMessage "Site identity updated."
        "upsert" -> do
            key <- T.strip <$> runInputPost (ireq textField "key")
            value <- runInputPost $ ireq textField "value"
            upsertSetting key value
            setMessage "Setting saved."
        "delete" -> do
            key <- runInputPost $ ireq textField "key"
            runDB $ deleteBy $ UniqueSiteSetting key
            setMessage "Setting deleted."
        _ ->
            setMessage "Unsupported settings action."
    redirect AdminSettingsR

getAdminSettingNewR :: Handler Html
getAdminSettingNewR = do
    let isNew = True
        mSetting = Nothing :: Maybe (Entity SiteSetting)
    mCsrfToken <- reqToken <$> getRequest
    adminPage "settings" "Admin - New Setting" $(widgetFile "admin/admin-setting-detail")

getAdminSettingR :: SiteSettingId -> Handler Html
getAdminSettingR settingId = do
    setting <- runDB $ get404 settingId
    let isNew = False
        mSetting = Just (Entity settingId setting)
    mCsrfToken <- reqToken <$> getRequest
    adminPage "settings" "Admin - Setting Detail" $(widgetFile "admin/admin-setting-detail")

postAdminSettingR :: SiteSettingId -> Handler Html
postAdminSettingR _ =
    postAdminSettingsR

adminPage :: Text -> Text -> Widget -> Handler Html
adminPage activeMenu pageTitleText adminBody =
    defaultLayout $ do
        setTitle $ toHtml pageTitleText
        let menuClass :: Text -> Text
            menuClass key =
                if key == activeMenu
                    then "bg-[#57d5e5] text-black border-[4px] border-black shadow-[6px_6px_0_#000]"
                    else "bg-white text-slate-700 border-[4px] border-black shadow-[6px_6px_0_#000] hover:bg-[#fff9ef]"
        $(widgetFile "layout/admin-layout")

cleanOptionalText :: Maybe Text -> Maybe Text
cleanOptionalText =
    fmap T.strip >=> \value ->
        if value == ""
            then Nothing
            else Just value

upsertSetting :: Text -> Text -> Handler ()
upsertSetting key value = do
    existing <- runDB $ getBy $ UniqueSiteSetting key
    case existing of
        Just (Entity settingId _) ->
            runDB $ update settingId [SiteSettingValue =. value]
        Nothing -> do
            _ <- runDB $ insert $ SiteSetting key value
            pure ()

loadAdminUserMap :: [UserId] -> Handler (Map.Map UserId User)
loadAdminUserMap userIds
    | null uniqueIds = pure Map.empty
    | otherwise = do
        users <- runDB $ selectList [UserId <-. uniqueIds] []
        pure $ Map.fromList $ map (\(Entity userId user) -> (userId, user)) users
  where
    uniqueIds = ordNub userIds

loadAdminSubmissionVoteCounts :: [Entity WordSubmission] -> Handler (Map.Map WordSubmissionId Int)
loadAdminSubmissionVoteCounts submissions
    | null submissionIds = pure Map.empty
    | otherwise = do
        counts <- forM submissionIds $ \submissionId -> do
            voteCount <- runDB $ count [WordSubmissionVoteSubmission ==. submissionId]
            pure (submissionId, voteCount)
        pure $ Map.fromList counts
  where
    submissionIds = map entityKey submissions

pendingStatus :: Text
pendingStatus = "pending"

approvedStatus :: Text
approvedStatus = "approved"

rejectedStatus :: Text
rejectedStatus = "rejected"
