{-# LANGUAGE OverloadedStrings #-}
module Handler.ApiSpec (spec) where

import qualified Model as M
import TestImport

spec :: Spec
spec = withApp $ do
    yit "registers through the public API and creates an authenticated session" $ do
        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "api-smoke"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
            addPostParam "displayName" "API Smoke"
        statusIs 200
        bodyContains "\"authenticated\":true"
        bodyContains "\"ident\":\"api-smoke\""

        get ApiSessionR
        statusIs 200
        bodyContains "\"authenticated\":true"
        bodyContains "\"ident\":\"api-smoke\""

    yit "supports liking and bookmarking a word through the API" $ do
        wordId <- runDB $ insert $ M.Word "TestWord" (Just "test-word") Nothing Nothing

        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "api-actions"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        request $ do
            setMethod "POST"
            setUrl (ApiWordLikeR wordId)
        statusIs 200
        bodyContains "\"active\":true"
        bodyContains "\"count\":1"

        request $ do
            setMethod "POST"
            setUrl (ApiWordBookmarkR wordId)
        statusIs 200
        bodyContains "\"active\":true"
        bodyContains "\"count\":1"

        get ApiMeR
        statusIs 200
        bodyContains "\"bookmarkCount\":1"
        bodyContains "\"likeCount\":1"

    yit "allows an authenticated user to create a word and returns it in myWords" $ do
        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "api-word-owner"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        request $ do
            setMethod "POST"
            setUrl ApiWordsR
            addPostParam "text" "FreshWord"
            addPostParam "transcription" "fresh-word"
        statusIs 200
        bodyContains "\"text\":\"FreshWord\""

        get ApiMeR
        statusIs 200
        bodyContains "\"myWords\":["
        bodyContains "\"text\":\"FreshWord\""
