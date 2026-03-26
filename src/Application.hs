{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TemplateHaskell, ViewPatterns, RecordWildCards #-}
module Application
    ( getApplicationDev
    , appMain
    , develMain
    , makeFoundation
    -- * for DevelMain
    , getApplicationRepl
    , shutdownApp
    -- * for GHCI
    , handler
    , db
    ) where

import Control.Monad.Logger                 (LoggingT, liftLoc, runLoggingT)
import Database.Persist.Sqlite              (createSqlitePool, runSqlPool,
                                             sqlDatabase, sqlPoolSize,
                                             runMigrationUnsafe)
import Import hiding ((.), (++))
import qualified Prelude as P
import Yesod.Auth.HashDB                    (setPassword)
import Language.Haskell.TH.Syntax           (qLocation)
import Network.Wai.Handler.Warp             (Settings, defaultSettings,
                                             defaultShouldDisplayException,
                                             runSettings, setHost,
                                             setOnException, setPort, getPort)
import Network.Wai.Middleware.RequestLogger (Destination (Logger),
                                             IPAddrSource (..),
                                             OutputFormat (..), destination,
                                             mkRequestLogger, outputFormat)
import qualified Data.Text as T
import System.Directory                    (createDirectoryIfMissing, doesFileExist,
                                             makeAbsolute)
import System.Environment                  (setEnv)
import System.FilePath                     (takeDirectory)
import System.Log.FastLogger                (defaultBufSize, newStdoutLoggerSet,
                                             toLogStr)

-- Import all relevant handler modules here.
-- Don't forget to add new modules to your cabal file!
import Handler.Common
import Handler.Home
import Handler.Search
import Handler.Word
import Handler.Notifications
import Handler.Upload
import Handler.Register
import Handler.Admin
import Handler.Profile
import Storage (mkStorage, storageBackendType)

-- This line actually creates our YesodDispatch instance. It is the second half
-- of the call to mkYesodData which occurs in Foundation.hs. Please see the
-- comments there for more details.
mkYesodDispatch "App" resourcesApp

-- | This function allocates resources (such as a database connection pool),
-- performs initialization and returns a foundation datatype value. This is also
-- the place to put your migrate statements to have automatic database
-- migrations handled by Yesod.
makeFoundation :: AppSettings -> IO App
makeFoundation appSettings = do
    -- Some basic initializations: HTTP connection manager, logger, and static
    -- subsite.
    appHttpManager <- newManager
    appLogger <- newStdoutLoggerSet defaultBufSize >>= makeYesodLogger
    appStatic <-
        (if appMutableStatic appSettings then staticDevel else static)
        (appStaticDir appSettings)
    appStorage <- mkStorage appSettings
    let appStorageBackendType = storageBackendType appStorage

    -- We need a log function to create a connection pool. We need a connection
    -- pool to create our foundation. And we need our foundation to get a
    -- logging function. To get out of this loop, we initially create a
    -- temporary foundation without a real connection pool, get a log function
    -- from there, and then create the real foundation.
    let mkFoundation appConnPool = App {..}
        -- The App {..} syntax is an example of record wild cards. For more
        -- information, see:
        -- https://ocharles.org.uk/blog/posts/2014-12-04-record-wildcards.html
        tempFoundation = mkFoundation $ error "connPool forced in tempFoundation"
        logFunc = messageLoggerSource tempFoundation appLogger

    let rawDbPath = unpack $ sqlDatabase $ appDatabaseConf appSettings
    absDbPath <- makeAbsolute rawDbPath
    let dbDir = takeDirectory absDbPath
        dbConf = (appDatabaseConf appSettings) { sqlDatabase = pack absDbPath }
    when (dbDir /= "." && dbDir /= "") $
        createDirectoryIfMissing True dbDir
    flip runLoggingT logFunc $
        $(logInfo) $ "Using SQLite database at: " <> pack absDbPath

    -- Create the database connection pool
    pool <- flip runLoggingT logFunc $ createSqlitePool
        (sqlDatabase dbConf)
        (sqlPoolSize dbConf)

    -- Perform database migration using our application's logging settings.
    runLoggingT (runSqlPool (runMigrationUnsafe migrateAll >> seedDefaults) pool) logFunc

    -- Return the foundation
    return $ mkFoundation pool

seedDefaults :: SqlPersistT (LoggingT IO) ()
seedDefaults = do
    adminId <- seedAdmin
    seedInitialWords

seedAdmin :: SqlPersistT (LoggingT IO) UserId
seedAdmin = do
    liftIO $ putStrLn "Seeding admin..."
    mUser <- getBy $ UniqueUser "ygpark2"
    case mUser of
        Just (Entity userId _) -> do
            liftIO $ putStrLn "Admin user exists, updating role."
            update userId [UserRole =. "admin"]
            pure userId
        Nothing -> do
            liftIO $ putStrLn "Creating new admin user..."
            user <- liftIO $ do
                putStrLn "Calling setPassword..."
                u <- setPassword "1234" (User "ygpark2" Nothing "admin" Nothing Nothing)
                putStrLn "setPassword finished."
                return u
            insert user

seedInitialWords :: SqlPersistT (LoggingT IO) ()
seedInitialWords = do
    -- Seed "Yesod"
    mYesod <- getBy $ UniqueWord "Yesod"
    case mYesod of
        Just _ -> return ()
        Nothing -> do
            wordId <- insert $ Word "Yesod" (Just "ye-sod") Nothing
            meaningId <- insert $ Meaning wordId (Just "noun") "A Haskell web framework for productive development of type-safe, RESTful web applications."
            void $ insert $ Example meaningId "I built my first dictionary SNS with Yesod." (Just "나는 Yesod로 나의 첫 번째 사전 SNS를 만들었다.")
            
            -- Add some comments
            mAdmin <- getBy $ UniqueUser "ygpark2"
            case mAdmin of
                Just (Entity adminId _) -> do
                    now <- liftIO getCurrentTime
                    void $ insert $ WordComment wordId adminId "This framework is amazing for building type-safe apps!" Nothing now now
                Nothing -> return ()

    -- Seed "Haskell"
    mHaskell <- getBy $ UniqueWord "Haskell"
    case mHaskell of
        Just _ -> return ()
        Nothing -> do
            wordId <- insert $ Word "Haskell" (Just "has-kel") Nothing
            meaningId <- insert $ Meaning wordId (Just "noun") "A standard, purely functional programming language with non-strict semantics and strong static typing."
            void $ insert $ Example meaningId "Haskell is known for its elegant syntax and powerful abstraction capabilities." (Just "Haskell은 우아한 구문과 강력한 추상화 능력으로 잘 알려져 있다.")
            
            mAdmin <- getBy $ UniqueUser "ygpark2"
            case mAdmin of
                Just (Entity adminId _) -> do
                    now <- liftIO getCurrentTime
                    void $ insert $ WordComment wordId adminId "Learning Haskell changed the way I think about programming." Nothing now now
                Nothing -> return ()

    -- Seed "Refactor"
    mRefactor <- getBy $ UniqueWord "Refactor"
    case mRefactor of
        Just _ -> return ()
        Nothing -> do
            wordId <- insert $ Word "Refactor" (Just "ree-fak-ter") Nothing
            meaningId <- insert $ Meaning wordId (Just "verb") "Restructure existing computer code without changing its external behavior."
            void $ insert $ Example meaningId "I am refactoring the dictionary app to make it a social network." (Just "나는 이 사전 앱을 소셜 네트워크로 만들기 위해 리팩토링하고 있다.")

    -- Seed "SNS"
    mSNS <- getBy $ UniqueWord "SNS"
    case mSNS of
        Just _ -> return ()
        Nothing -> do
            wordId <- insert $ Word "SNS" (Just "ess-enn-ess") Nothing
            meaningId <- insert $ Meaning wordId (Just "noun") "Social Networking Service; an online platform which people use to build social networks or social relationships."
            void $ insert $ Example meaningId "This site is a dictionary-based SNS." (Just "이 사이트는 사전 기반의 SNS이다.")


-- | Convert our foundation to a WAI Application by calling @toWaiAppPlain@ and
-- applying some additional middlewares.
makeApplication :: App -> IO Application
makeApplication foundation = do
    logWare <- mkRequestLogger def
        { outputFormat =
            if appDetailedRequestLogging $ appSettings foundation
                then Detailed True
                else Apache
                        (if appIpFromHeader $ appSettings foundation
                            then FromFallback
                            else FromSocket)
        , destination = Logger $ loggerSet $ appLogger foundation
        }

    -- Create the WAI application and apply middlewares
    appPlain <- toWaiAppPlain foundation
    return $ logWare $ defaultMiddlewaresNoLogging appPlain

-- | Warp settings for the given foundation value.
warpSettings :: App -> Settings
warpSettings foundation =
      setPort (appPort $ appSettings foundation)
    $ setHost (appHost $ appSettings foundation)
    $ setOnException (\_req e ->
        when (defaultShouldDisplayException e) $ messageLoggerSource
            foundation
            (appLogger foundation)
            $(qLocation >>= liftLoc)
            "yesod"
            LevelError
            (toLogStr $ "Exception from Warp: " P.++ show e))
      defaultSettings

-- | For yesod devel, return the Warp settings and WAI Application.
getApplicationDev :: IO (Settings, Application)
getApplicationDev = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app <- makeApplication foundation
    return (wsettings, app)

getAppSettings :: IO AppSettings
getAppSettings = do
    loadDotenv
    loadYamlSettings [configSettingsYml] [] useEnv

-- | main function for use by yesod devel
develMain :: IO ()
develMain = develMainHelper getApplicationDev

-- | The @main@ function for an executable running this site.
appMain :: IO ()
appMain = do
    loadDotenv
    -- Get the settings from all relevant sources
    settings <- loadYamlSettingsArgs
        -- fall back to compile-time values, set to [] to require values at runtime
        [configSettingsYmlValue]

        -- allow environment variables to override
        useEnv

    -- Generate the foundation from the settings
    foundation <- makeFoundation settings

    -- Generate a WAI Application from the foundation
    app <- makeApplication foundation

    -- Run the application with Warp
    runSettings (warpSettings foundation) app

loadDotenv :: IO ()
loadDotenv = do
    exists <- doesFileExist ".env"
    when exists $ do
        contents <- readFile ".env"
        forM_ (T.lines $ decodeUtf8 contents) $ \rawLine -> do
            let line = T.strip rawLine
            when (not (T.null line) && T.head line /= '#') $ do
                let line' =
                        if "export " `T.isPrefixOf` line
                            then T.drop 7 line
                            else line
                    (key, rest) = T.breakOn "=" line'
                    value = T.drop 1 rest
                when (not (T.null key) && not (T.null rest)) $
                    setEnv (T.unpack key) (T.unpack $ stripQuotes $ T.strip value)
  where
    stripQuotes s =
        case T.uncons s of
            Just ('"', xs) | not (T.null xs) && T.last xs == '"' -> T.init xs
            Just ('\'', xs) | not (T.null xs) && T.last xs == '\'' -> T.init xs
            _ -> s


--------------------------------------------------------------
-- Functions for DevelMain.hs (a way to run the app from GHCi)
--------------------------------------------------------------
getApplicationRepl :: IO (Int, App, Application)
getApplicationRepl = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app1 <- makeApplication foundation
    return (getPort wsettings, foundation, app1)

shutdownApp :: App -> IO ()
shutdownApp _ = return ()


---------------------------------------------
-- Functions for use in development with GHCi
---------------------------------------------

-- | Run a handler
handler :: Handler a -> IO a
handler h = getAppSettings >>= makeFoundation >>= flip unsafeHandler h

-- | Run DB queries
db :: ReaderT SqlBackend (HandlerFor App) a -> IO a
db = handler P.. runDB
