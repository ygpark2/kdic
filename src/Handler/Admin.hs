{-# LANGUAGE OverloadedStrings, NoImplicitPrelude #-}
module Handler.Admin where

import Import
import Handler.Common (serveFrontendPath)

getAdminR :: Handler TypedContent
getAdminR =
    serveFrontendPath ["admin"]

getAdminOpsR :: Handler TypedContent
getAdminOpsR =
    serveFrontendPath ["admin", "ops"]

getAdminWordsR :: Handler TypedContent
getAdminWordsR =
    serveFrontendPath ["admin", "words"]

getAdminWordNewR :: Handler TypedContent
getAdminWordNewR =
    serveFrontendPath ["admin", "words", "new"]

getAdminWordEditR :: WordId -> Handler TypedContent
getAdminWordEditR wordId =
    serveFrontendPath ["admin", "words", "edit", toPathPiece wordId]

getAdminSubmissionsR :: Handler TypedContent
getAdminSubmissionsR =
    serveFrontendPath ["admin", "submissions"]

getAdminAdsR :: Handler TypedContent
getAdminAdsR =
    serveFrontendPath ["admin", "ads"]

getAdminAdNewR :: Handler TypedContent
getAdminAdNewR =
    serveFrontendPath ["admin", "ads", "new"]

getAdminAdR :: AdId -> Handler TypedContent
getAdminAdR adId =
    serveFrontendPath ["admin", "ads", "id", toPathPiece adId]

getAdminUsersR :: Handler TypedContent
getAdminUsersR =
    serveFrontendPath ["admin", "users"]

getAdminUserNewR :: Handler TypedContent
getAdminUserNewR =
    serveFrontendPath ["admin", "users", "new"]

getAdminUserR :: UserId -> Handler TypedContent
getAdminUserR userId =
    serveFrontendPath ["admin", "users", "id", toPathPiece userId]

getAdminSettingsR :: Handler TypedContent
getAdminSettingsR =
    serveFrontendPath ["admin", "settings"]

getAdminSettingNewR :: Handler TypedContent
getAdminSettingNewR =
    serveFrontendPath ["admin", "settings", "new"]

getAdminSettingR :: SiteSettingId -> Handler TypedContent
getAdminSettingR settingId =
    serveFrontendPath ["admin", "settings", "id", toPathPiece settingId]
