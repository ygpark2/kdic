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
        wordId <- runDB $ insert $ M.Word "TestWord" (Just "test-word") Nothing

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

    yit "submits a user word, supports voting, and lets an admin promote it" $ do
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
        bodyContains "\"kind\":\"submission\""
        bodyContains "\"status\":\"pending\""
        bodyContains "\"text\":\"FreshWord\""

        get ApiMeR
        statusIs 200
        bodyContains "\"mySubmissions\":["
        bodyContains "\"text\":\"FreshWord\""

        submissionId <- runDB $ do
            mSubmission <- selectFirst [M.WordSubmissionText ==. "FreshWord"] []
            case mSubmission of
                Just (Entity sid _) -> pure sid
                Nothing -> error "Expected FreshWord submission"

        request $ do
            setMethod "POST"
            setUrl (ApiWordSubmissionVoteR submissionId)
        statusIs 200
        bodyContains "\"active\":true"
        bodyContains "\"count\":1"

        request $ do
            setMethod "GET"
            setUrl ApiSearchR
            addGetParam "q" "FreshWord"
        statusIs 200
        bodyContains "\"kind\":\"submission\""

        runDB $ do
            mUser <- getBy $ M.UniqueUser "api-word-owner"
            case mUser of
                Just (Entity userId _) -> update userId [M.UserRole =. "admin"]
                Nothing -> error "Expected api-word-owner user"

        request $ do
            setMethod "POST"
            setUrl (AdminSubmissionApproveR submissionId)
        statusIs 303

        runDB $ do
            mWord <- getBy $ M.UniqueWord "FreshWord"
            case mWord of
                Just _ -> pure ()
                Nothing -> error "Expected FreshWord to be promoted to Word"
