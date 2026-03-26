{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Admin where

import Import

getAdminR :: Handler Html
getAdminR = do
    defaultLayout $ do
        setTitle "Admin"
        $(widgetFile "admin/admin")

getAdminWordsR :: Handler Html
getAdminWordsR = do
    words <- runDB $ selectList [] [Asc WordText]
    defaultLayout $ do
        setTitle "Admin - Words"
        $(widgetFile "admin/words")

postAdminWordsR :: Handler Html
postAdminWordsR = do
    text <- runInputPost $ ireq textField "text"
    transcription <- runInputPost $ iopt textField "transcription"
    _ <- runDB $ insert $ Word text transcription Nothing
    setMessage "Word added."
    redirect AdminWordsR

getAdminWordNewR :: Handler Html
getAdminWordNewR = do
    defaultLayout $ do
        setTitle "Admin - New Word"
        $(widgetFile "admin/word-edit")

getAdminWordEditR :: WordId -> Handler Html
getAdminWordEditR wordId = do
    word <- runDB $ get404 wordId
    defaultLayout $ do
        setTitle "Admin - Edit Word"
        $(widgetFile "admin/word-edit")

postAdminWordEditR :: WordId -> Handler Html
postAdminWordEditR wordId = do
    text <- runInputPost $ ireq textField "text"
    transcription <- runInputPost $ iopt textField "transcription"
    runDB $ update wordId [WordText =. text, WordTranscription =. transcription]
    setMessage "Word updated."
    redirect AdminWordsR

getAdminUsersR :: Handler Html
getAdminUsersR = do
    users <- runDB $ selectList [] [Asc UserIdent]
    mCsrfToken <- reqToken <$> getRequest
    mUserId <- maybeAuthId
    defaultLayout $ do
        setTitle "Admin - Users"
        $(widgetFile "admin/users")

postAdminUsersR :: Handler Html
postAdminUsersR = do
    setMessage "Not implemented."
    redirect AdminUsersR

getAdminUserNewR :: Handler Html
getAdminUserNewR = do
    setMessage "Not implemented."
    redirect AdminUsersR

getAdminUserR :: UserId -> Handler Html
getAdminUserR _ = do
    setMessage "Not implemented."
    redirect AdminUsersR

postAdminUserR :: UserId -> Handler Html
postAdminUserR _ = do
    setMessage "Not implemented."
    redirect AdminUsersR

getAdminSettingsR :: Handler Html
getAdminSettingsR = do
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    mCsrfToken <- reqToken <$> getRequest
    mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
    mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
    let siteTitleValue = maybe "" (siteSettingValue . entityVal) mSiteTitle
        siteSubtitleValue = maybe "" (siteSettingValue . entityVal) mSiteSubtitle
    defaultLayout $ do
        setTitle "Admin - Settings"
        $(widgetFile "admin/settings")

postAdminSettingsR :: Handler Html
postAdminSettingsR = do
    setMessage "Not implemented."
    redirect AdminSettingsR

getAdminSettingNewR :: Handler Html
getAdminSettingNewR = do
    setMessage "Not implemented."
    redirect AdminSettingsR

getAdminSettingR :: SiteSettingId -> Handler Html
getAdminSettingR _ = do
    setMessage "Not implemented."
    redirect AdminSettingsR

postAdminSettingR :: SiteSettingId -> Handler Html
postAdminSettingR _ = do
    setMessage "Not implemented."
    redirect AdminSettingsR

getAdminBoardsR :: Handler Html
getAdminBoardsR = do
    setMessage "Not implemented."
    redirect AdminR

getAdminCompaniesR :: Handler Html
getAdminCompaniesR = do
    setMessage "Not implemented."
    redirect AdminR

getAdminCompanyCategoriesR :: Handler Html
getAdminCompanyCategoriesR = do
    setMessage "Not implemented."
    redirect AdminR

getAdminAdsR :: Handler Html
getAdminAdsR = do
    setMessage "Not implemented."
    redirect AdminR