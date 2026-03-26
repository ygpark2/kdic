{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Register where

import Import
import Yesod.Auth.HashDB (setPassword)
import Text.Blaze (preEscapedText)

renderRegister :: Widget -> Enctype -> Handler Html
renderRegister widget enctype = do
    mmsg <- getMessage
    defaultLayout $ do
        setTitle $ preEscapedText "Register"
        $(widgetFile "register")

getRegisterR :: Handler Html
getRegisterR = do
    (widget, enctype) <- generateFormPost registerForm
    renderRegister widget enctype

postRegisterR :: Handler Html
postRegisterR = do
    ((result, widget), enctype) <- runFormPost registerForm
    case result of
        FormSuccess (ident, pwd) -> do
            mUser <- runDB $ selectFirst [UserIdent ==. ident] []
            case mUser of
                Nothing -> do
                    user <- liftIO $ setPassword pwd (User ident Nothing "user" Nothing Nothing)
                    _ <- runDB $ insert user
                    setMessage "Registration successful. Please login."
                    redirect $ AuthR LoginR
                Just _ -> do
                      setMessage "Username already exists."
                      renderRegister widget enctype
        _ -> renderRegister widget enctype

registerForm :: Form (Text, Text)
registerForm = renderDivs $ (,)
    <$> areq textField usernameSettings Nothing
    <*> areq passwordField passwordSettings Nothing
  where
    inputAttrs =
        [ ("class", "w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-900")
        ]
    usernameSettings = FieldSettings
        { fsLabel = "Username"
        , fsTooltip = Nothing
        , fsId = Just "username"
        , fsName = Just "username"
        , fsAttrs = inputAttrs
        }
    passwordSettings = FieldSettings
        { fsLabel = "Password"
        , fsTooltip = Nothing
        , fsId = Just "password"
        , fsName = Just "password"
        , fsAttrs = inputAttrs
        }
