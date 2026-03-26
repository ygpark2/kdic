{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Profile
    ( getProfileR
    , postProfileR
    , getSettingsR
    ) where

import Import
import Text.Blaze (preEscapedText)

getProfileR :: Handler Html
getProfileR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    (widget, enctype) <- generateFormPost (profileForm user)
    defaultLayout $ do
        setTitle $ preEscapedText "Edit profile"
        $(widgetFile "profile")

getSettingsR :: Handler Html
getSettingsR = redirect ProfileR

postProfileR :: Handler Html
postProfileR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    ((result, widget), enctype) <- runFormPost (profileForm user)
    case result of
        FormSuccess (nameVal, descVal) -> do
            runDB $ update userId
                [ UserName =. nameVal
                , UserDescription =. descVal
                ]
            setMessage "Profile updated."
            redirect ProfileR
        _ -> defaultLayout $ do
            setTitle $ preEscapedText "Edit profile"
            $(widgetFile "profile")

profileForm :: User -> Form (Maybe Text, Maybe Text)
profileForm user = renderDivs $ (,)
    <$> aopt textField nameSettings (Just $ userName user)
    <*> fmap (fmap unTextarea) (aopt textareaField descSettings (Just descInit))
  where
    descInit = Textarea <$> userDescription user
    inputAttrs =
        [ ("class", "w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-900")
        ]
    nameSettings = FieldSettings
        { fsLabel = "Name"
        , fsTooltip = Nothing
        , fsId = Just "name"
        , fsName = Just "name"
        , fsAttrs = inputAttrs
        }
    descSettings = FieldSettings
        { fsLabel = "Description"
        , fsTooltip = Nothing
        , fsId = Just "description"
        , fsName = Just "description"
        , fsAttrs = inputAttrs
        }
