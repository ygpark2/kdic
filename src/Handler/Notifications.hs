{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Notifications where

import Import

getNotificationsR :: Handler Html
getNotificationsR =
    redirect $ FrontendAppPathR ["notifications"]

postNotificationsReadAllR :: Handler Html
postNotificationsReadAllR = do
    uid <- requireAuthId
    runDB $ updateWhere [NotificationUser ==. uid, NotificationIsRead ==. False] [NotificationIsRead =. True]
    redirect NotificationsR
