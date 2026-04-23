{-# LANGUAGE OverloadedStrings #-}
module Handler.ApiSpec (spec) where
import Database.Persist.Sql (fromSqlKey)
import qualified Model as M
import qualified Prelude as P
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

    yit "exposes active ads in public and authenticated API payloads" $ do
        now <- liftIO getCurrentTime
        _ <- runDB $ insert $ M.Ad "home_right_rail" "custom" "Home Sponsor" (Just "Dictionary sponsor") (Just "https://example.com") (Just "Visit") Nothing Nothing 0 True Nothing Nothing 0 Nothing 0 Nothing now now
        _ <- runDB $ insert $ M.Ad "profile_right_rail" "embed" "Profile Sponsor" Nothing Nothing Nothing Nothing (Just "<div>embedded slot</div>") 0 True Nothing Nothing 0 Nothing 0 Nothing now now

        get ApiHomeR
        statusIs 200
        bodyContains "\"homeRightRail\""
        bodyContains "\"title\":\"Home Sponsor\""
        bodyContains "\"clickUrl\":\"/ads/"

        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "ads-user"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        get ApiMeR
        statusIs 200
        bodyContains "\"profileRightRail\""
        bodyContains "\"kind\":\"embed\""

    yit "filters ads by serving window and tracks custom ad clicks" $ do
        now <- liftIO getCurrentTime
        let UTCTime currentDay currentTime = now
            ModifiedJulianDay currentMjd = currentDay
            future = UTCTime (ModifiedJulianDay (currentMjd + 1)) currentTime
            past = UTCTime (ModifiedJulianDay (currentMjd - 1)) currentTime
        activeAdId <- runDB $ insert $ M.Ad "home_right_rail" "custom" "Live Sponsor" Nothing (Just "https://example.com/live") (Just "Open") Nothing Nothing 0 True (Just past) (Just future) 0 Nothing 0 Nothing now now
        _ <- runDB $ insert $ M.Ad "profile_right_rail" "custom" "Scheduled Sponsor" Nothing (Just "https://example.com/scheduled") Nothing Nothing Nothing 0 True (Just future) Nothing 0 Nothing 0 Nothing now now

        get ApiHomeR
        statusIs 200
        bodyContains "\"title\":\"Live Sponsor\""

        request $ do
            setMethod "POST"
            setUrl (ApiAdImpressionR activeAdId)
        statusIs 200
        bodyContains "\"tracked\":true"

        request $ do
            setMethod "GET"
            setUrl (AdClickR activeAdId)
        statusIs 303

        (trackedImpressions, trackedClicks) <- runDB $ do
            mAd <- selectFirst [M.AdId ==. activeAdId] []
            case mAd of
                Just (Entity _ ad) -> pure (M.adImpressionCount ad, M.adClickCount ad)
                Nothing -> error "Expected active ad"
        liftIO $ do
            trackedImpressions `shouldBe` 1
            trackedClicks `shouldBe` 1

    yit "rotates among active ads in the same slot" $ do
        now <- liftIO getCurrentTime
        let UTCTime currentDay _ = now
            ModifiedJulianDay currentMjd = currentDay
            expectedTitle =
                if even currentMjd
                    then "Rotation A"
                    else "Rotation B"
        _ <- runDB $ insert $ M.Ad "home_right_rail" "custom" "Rotation A" Nothing (Just "https://example.com/a") Nothing Nothing Nothing 0 True Nothing Nothing 0 Nothing 0 Nothing now now
        _ <- runDB $ insert $ M.Ad "home_right_rail" "custom" "Rotation B" Nothing (Just "https://example.com/b") Nothing Nothing Nothing 1 True Nothing Nothing 0 Nothing 0 Nothing now now

        get ApiHomeR
        statusIs 200
        bodyContains ("\"title\":\"" <> expectedTitle <> "\"")

    yit "enforces the free bookmark limit" $ do
        wordIds <- runDB $ forM [1 .. 21 :: Int] $ \wordIndex ->
            insert $ M.Word ("LimitWord" <> tshow wordIndex) Nothing Nothing

        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "bookmark-limit-user"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        forM_ (P.take 20 wordIds) $ \wordId -> do
            request $ do
                setMethod "POST"
                setUrl (ApiWordBookmarkR wordId)
            statusIs 200

        request $ do
            setMethod "POST"
            setUrl (ApiWordBookmarkR (P.last wordIds))
        statusIs 403
        bodyContains "Free accounts can save up to 20 bookmarks"

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
            setUrl (ApiAdminSubmissionApproveR submissionId)
        statusIs 200

        runDB $ do
            mWord <- getBy $ M.UniqueWord "FreshWord"
            case mWord of
                Just _ -> pure ()
                Nothing -> error "Expected FreshWord to be promoted to Word"

    yit "unlocks premium collections, weighted votes, generators, and downloads" $ do
        wordId <- runDB $ insert $ M.Word "PremiumWord" (Just "pre-mi-um") Nothing

        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "premium-user"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        runDB $ do
            mUser <- getBy $ M.UniqueUser "premium-user"
            case mUser of
                Just (Entity userId _) -> update userId [M.UserPremium =. True, M.UserPremiumBadge =. Just "Founder"]
                Nothing -> error "Expected premium-user user"

        request $ do
            setMethod "POST"
            setUrl ApiWordsR
            addPostParam "text" "PriorityWord"
        statusIs 200
        bodyContains "\"priorityScore\":100"

        submissionId <- runDB $ do
            mSubmission <- selectFirst [M.WordSubmissionText ==. "PriorityWord"] []
            case mSubmission of
                Just (Entity sid _) -> pure sid
                Nothing -> error "Expected PriorityWord submission"

        request $ do
            setMethod "POST"
            setUrl (ApiWordSubmissionVoteR submissionId)
        statusIs 200
        bodyContains "\"count\":3"
        bodyContains "\"weight\":3"

        request $ do
            setMethod "POST"
            setUrl ApiCollectionsR
            addPostParam "title" "Studio"
            addPostParam "description" "Premium collection"
        statusIs 200
        bodyContains "\"title\":\"Studio\""

        collectionId <- runDB $ do
            mCollection <- selectFirst [M.WordCollectionTitle ==. "Studio"] []
            case mCollection of
                Just (Entity cid _) -> pure cid
                Nothing -> error "Expected Studio collection"

        request $ do
            setMethod "POST"
            setUrl (ApiCollectionAddWordR collectionId wordId)
        statusIs 200
        bodyContains "\"active\":true"

        request $ do
            setMethod "GET"
            setUrl ApiPremiumRecommendationsR
            addGetParam "context" "focus"
        statusIs 200
        bodyContains "\"context\":\"focus\""

        request $ do
            setMethod "POST"
            setUrl ApiPremiumSentenceR
            addPostParam "wordId" (tshow $ fromSqlKey wordId)
            addPostParam "tone" "warm"
        statusIs 200
        bodyContains "\"tone\":\"warm\""

        request $ do
            setMethod "POST"
            setUrl ApiPremiumNicknameR
            addPostParam "wordId" (tshow $ fromSqlKey wordId)
        statusIs 200
        bodyContains "\"seed\":\"PremiumWord\""

        request $ do
            setMethod "GET"
            setUrl ApiPremiumWordbookR
        statusIs 200
        bodyContains "Premium Wordbook"

        request $ do
            setMethod "GET"
            setUrl ApiPremiumWordbookR
            addGetParam "format" "pdf"
        statusIs 200
        assertHeader "Content-Type" "application/pdf"
        assertHeader "Content-Disposition" "attachment; filename=\"premium-wordbook.pdf\""

        request $ do
            setMethod "GET"
            setUrl ApiPremiumWordbookR
            addGetParam "format" "svg"
            addGetParam "wordId" (tshow $ fromSqlKey wordId)
        statusIs 200
        bodyContains "<svg"

    yit "rejects unsafe embed HTML in admin ad creation" $ do
        request $ do
            setMethod "POST"
            setUrl ApiAuthRegisterR
            addPostParam "ident" "admin-embed-audit"
            addPostParam "password" "pass1234"
            addPostParam "passwordConfirm" "pass1234"
        statusIs 200

        runDB $ do
            mUser <- getBy $ M.UniqueUser "admin-embed-audit"
            case mUser of
                Just (Entity userId _) -> update userId [M.UserRole =. "admin"]
                Nothing -> error "Expected admin-embed-audit user"

        request $ do
            setMethod "POST"
            setUrl ApiAdminAdsR
            addPostParam "title" "Unsafe Embed"
            addPostParam "slot" "home_right_rail"
            addPostParam "kind" "embed"
            addPostParam "embedHtml" "<script src=\"https://evil.example/embed.js\"></script>"
            addPostParam "sortOrder" "0"
        statusIs 400
        bodyContains "Google Ads snippets"
