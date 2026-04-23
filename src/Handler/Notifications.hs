{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Notifications where

import Import
import Handler.Common (serveFrontendPath)

getNotificationsR :: Handler TypedContent
getNotificationsR =
    serveFrontendPath ["notifications"]

postNotificationsReadAllR :: Handler Html
postNotificationsReadAllR = do
    uid <- requireAuthId
    runDB $ updateWhere [NotificationUser ==. uid, NotificationIsRead ==. False] [NotificationIsRead =. True]
    redirect NotificationsR
