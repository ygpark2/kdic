{-# LANGUAGE OverloadedStrings, TemplateHaskell, MultiParamTypeClasses, TypeFamilies, NoImplicitPrelude #-}
module Handler.Notifications where

import Import

getNotificationsR :: Handler Html
getNotificationsR = do
    uid <- requireAuthId
    notifications <- runDB $ selectList [NotificationUser ==. uid] [Desc NotificationCreatedAt, LimitTo 50]
    defaultLayout $ do
        setTitle "Notifications"
        $(widgetFile "notifications")

postNotificationsReadAllR :: Handler Html
postNotificationsReadAllR = do
    uid <- requireAuthId
    runDB $ updateWhere [NotificationUser ==. uid, NotificationIsRead ==. False] [NotificationIsRead =. True]
    redirect NotificationsR
