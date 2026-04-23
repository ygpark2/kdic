{-# LANGUAGE TemplateHaskell, QuasiQuotes, OverloadedStrings, MultiParamTypeClasses, TypeFamilies, GADTs, ViewPatterns #-}
module Foundation where

import Import.NoFoundation hiding ((.), (++))
import qualified Prelude as P
import Database.Persist.Sql (ConnectionPool, runSqlPool)
import Text.Jasmine         (minifym)
import Yesod.Auth.HashDB     (authHashDB)
import Yesod.Auth.OAuth2.Google (oauth2Google)
import Auth.OAuth2Providers  (oauth2Kakao, oauth2Naver)
import Yesod.Default.Util   (addStaticContentExternal)
import Storage              (Storage, StorageBackendType(..))

import Yesod.Core.Types     (Logger)
import qualified Yesod.Core.Unsafe as Unsafe

-- | The foundation datatype for your application. This can be a good place to
-- keep settings and values requiring initialization before your application
-- starts running, such as database connections. Every handler will have
-- access to the data present here.
data App = App
    { appSettings    :: AppSettings
    , appStatic      :: Static -- ^ Settings for static file serving.
    , appConnPool    :: ConnectionPool -- ^ Database connection pool.
    , appHttpManager :: Manager
    , appLogger      :: Logger
    , appStorage     :: Storage App
    , appStorageBackendType :: StorageBackendType
    }

instance HasHttpManager App where
    getHttpManager = appHttpManager

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://www.yesodweb.com/book/routing-and-handlers
--
-- Note that this is really half the story; in Application.hs, mkYesodDispatch
-- generates the rest of the code. Please see the linked documentation for an
-- explanation for this split.
--
-- This function also generates the following type synonyms:
-- type Handler = HandlerT App IO
-- type Widget = WidgetT App IO ()
mkYesodData "App" $(parseRoutesFile "config/routes")

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod App where
    -- Controls the base of generated URLs. For more information on modifying,
    -- see: https://github.com/yesodweb/yesod/wiki/Overriding-approot
    approot = ApprootMaster $ appRoot P.. appSettings

    defaultLayout widget = do
        master <- getYesod
        mmsg <- getMessage
        pc <- widgetToPageContent $ do
            [whamlet|
$maybe msg <- mmsg
  <div id="alert-message" class="fixed top-6 right-4 z-[100] rounded-xl border border-orange-200 bg-amber-50 px-4 py-3 text-sm text-amber-700 shadow-lg animate-bounce">
    #{msg}

<div class="min-h-screen">
  <main>
    ^{widget}
|]
        withUrlRenderer [hamlet|
$newline never
<!doctype html>
<html class="no-js" lang="en">
  <head>
    <meta charset="UTF-8">
    <title>#{pageTitle pc}
    <meta name="description" content="">
    <meta name="author" content="">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap" rel="stylesheet">
    ^{pageHead pc}
    <link rel="stylesheet" href=@{StaticR css_tailwind_css}>
  <body class="bg-[#efe4d6] text-slate-900">
    <div class="min-h-screen flex flex-col">
      <main class="flex-1">
        <div class="mx-auto w-full max-w-[1216px] px-2 py-3 md:px-3">
          ^{pageBody pc}
      <footer class="text-slate-500">
        <div class="mx-auto w-full max-w-[1216px] px-2 py-4 text-xs text-center md:px-3">
          #{appCopyright $ appSettings master}
|]

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend _ = Just <$> defaultClientSessionBackend
        120    -- timeout in minutes
        "config/client_session_key.aes"

    -- The page to be redirected to when authentication is required.
    authRoute _ = Just FrontendLoginR

    -- Routes not requiring authentication.
    isAuthorized (AuthR _) _ = return Authorized
    isAuthorized FaviconR _ = return Authorized
    isAuthorized RobotsR _ = return Authorized
    isAuthorized SitemapR _ = return Authorized
    isAuthorized HealthzR _ = return Authorized
    isAuthorized (WordOgImageR _) _ = return Authorized
    isAuthorized (WordOgPngR _) _ = return Authorized
    isAuthorized HomeR _ = return Authorized
    isAuthorized (FrontendAssetR _) _ = return Authorized
    isAuthorized FrontendNewWordR _ = return Authorized
    isAuthorized FrontendLoginR _ = return Authorized
    isAuthorized (FrontendWordDetailR _) _ = return Authorized
    isAuthorized ApiHomeR _ = return Authorized
    isAuthorized ApiSearchR _ = return Authorized
    isAuthorized (ApiAdImpressionR _) _ = return Authorized
    isAuthorized ApiAdminDashboardR _ = isAdmin
    isAuthorized ApiAdminOpsR _ = isAdmin
    isAuthorized ApiAdminWordsR _ = isAdmin
    isAuthorized (ApiAdminWordR _) _ = isAdmin
    isAuthorized ApiAdminSubmissionsR _ = isAdmin
    isAuthorized (ApiAdminSubmissionApproveR _) _ = isAdmin
    isAuthorized (ApiAdminSubmissionRejectR _) _ = isAdmin
    isAuthorized ApiAdminAdsR _ = isAdmin
    isAuthorized (ApiAdminAdR _) _ = isAdmin
    isAuthorized ApiAdminUsersR _ = isAdmin
    isAuthorized (ApiAdminUserR _) _ = isAdmin
    isAuthorized ApiAdminSettingsR _ = isAdmin
    isAuthorized (ApiAdminSettingR _) _ = isAdmin
    isAuthorized (ApiWordR _) _ = return Authorized
    isAuthorized (ApiWordCommentR _) _ = return Authorized
    isAuthorized (ApiWordLikeR _) _ = return Authorized
    isAuthorized (ApiWordBookmarkR _) _ = return Authorized
    isAuthorized (ApiWordSubmissionVoteR _) _ = return Authorized
    isAuthorized (ApiCommentDeleteR _) _ = return Authorized
    isAuthorized ApiNotificationsR _ = return Authorized
    isAuthorized ApiNotificationsReadAllR _ = return Authorized
    isAuthorized ApiAuthLoginR _ = return Authorized
    isAuthorized ApiAuthRegisterR _ = return Authorized
    isAuthorized ApiAuthLogoutR _ = return Authorized
    isAuthorized ApiSessionR _ = return Authorized
    isAuthorized ApiMeR _ = return Authorized
    isAuthorized ApiMeUpdateR _ = return Authorized
    isAuthorized SearchR _ = return Authorized
    isAuthorized (WordR _) _ = return Authorized
    
    isAuthorized (WordCommentR _) _ = return Authorized
    isAuthorized (WordLikeR _) _ = return Authorized
    isAuthorized (WordBookmarkR _) _ = return Authorized
    isAuthorized (WordCommentDeleteR _) _ = return Authorized

    isAuthorized NotificationsR _ = return Authorized
    isAuthorized NotificationsReadAllR _ = return Authorized
    
    isAuthorized ProfileR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (AdClickR _) _ = return Authorized
    isAuthorized SettingsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized

    -- Admin-only routes.
    isAuthorized AdminR _ = isAdmin
    isAuthorized AdminOpsR _ = isAdmin
    isAuthorized AdminWordsR _ = isAdmin
    isAuthorized AdminWordNewR _ = isAdmin
    isAuthorized (AdminWordEditR _) _ = isAdmin
    isAuthorized AdminSubmissionsR _ = isAdmin
    isAuthorized AdminAdsR _ = isAdmin
    isAuthorized AdminAdNewR _ = isAdmin
    isAuthorized (AdminAdR _) _ = isAdmin
    isAuthorized AdminUsersR _ = isAdmin
    isAuthorized AdminUserNewR _ = isAdmin
    isAuthorized (AdminUserR _) _ = isAdmin
    isAuthorized AdminSettingsR _ = isAdmin
    isAuthorized AdminSettingNewR _ = isAdmin
    isAuthorized (AdminSettingR _) _ = isAdmin
    
    -- Default to Authorized for now.
    isAuthorized _ _ = return Authorized

    -- This function creates static content files in the static folder
    -- and names them based on a hash of their content. This allows
    -- expiration dates to be set far in the future without worry of
    -- users receiving stale content.
    addStaticContent ext mime content = do
        master <- getYesod
        let staticDir = appStaticDir $ appSettings master
        addStaticContentExternal
            minifym
            genFileName
            staticDir
            (StaticR P.. flip StaticRoute [])
            ext
            mime
            content
      where
        -- Generate a unique filename based on the content itself
        genFileName lbs = "autogen-" P.++ base64md5 lbs

    makeLogger = return P.. appLogger

-- How to run database actions.
instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB action = do
        master <- getYesod
        runSqlPool action $ appConnPool master
instance YesodPersistRunner App where
    getDBRunner = defaultGetDBRunner appConnPool

instance YesodAuth App where
    type AuthId App = UserId
    loginDest _ = HomeR
    logoutDest _ = HomeR
    redirectToReferer _ = False
    authHttpManager = getYesod >>= return P.. getHttpManager
    authPlugins app =
        [authHashDB (Just P.. UniqueUser)]
        P.++ oauthPlugin oauth2Google appGoogleClientId appGoogleClientSecret
        P.++ oauthPlugin oauth2Kakao appKakaoClientId appKakaoClientSecret
        P.++ oauthPlugin oauth2Naver appNaverClientId appNaverClientSecret
      where
        settings = appSettings app
        oauthPlugin plugin getId getSecret =
            case (getId settings, getSecret settings) of
                (Just clientId, Just clientSecret) -> [plugin clientId clientSecret]
                _ -> []

    authenticate creds = liftHandler $ runDB $ do
        let ident =
                if credsPlugin creds `elem` ["hashdb", "api"]
                    then credsIdent creds
                    else credsPlugin creds <> ":" <> credsIdent creds
        mUser <- getBy $ UniqueUser ident
        case mUser of
            Just (Entity userId _) -> return $ Authenticated userId
            Nothing -> Authenticated <$> insert (User ident Nothing "user" Nothing Nothing False Nothing)

instance YesodAuthPersist App where
    type AuthEntity App = User

isAdmin :: Handler AuthResult
isAdmin = do
    mUserId <- maybeAuthId
    case mUserId of
        Nothing -> return AuthenticationRequired
        Just userId -> do
            mUser <- runDB $ get userId
            case mUser of
                Nothing -> return AuthenticationRequired
                Just user ->
                    if userRole user == "admin"
                        then return Authorized
                        else return $ Unauthorized "Admin only"


-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

unsafeHandler :: App -> Handler a -> IO a
unsafeHandler = Unsafe.fakeHandlerGetLogger appLogger

-- Note: Some functionality previously present in the scaffolding has been
-- moved to documentation in the Wiki. Following are some hopefully helpful
-- links:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email
-- https://github.com/yesodweb/yesod/wiki/Serve-static-files-from-a-separate-domain
-- https://github.com/yesodweb/yesod/wiki/i18n-messages-in-the-scaffolding
