-- | Common handler functions.
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Handler.Common where

import Import
import Data.Char (isSpace)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as LBS
import Data.FileEmbed (embedFile)
import System.Directory (doesFileExist)
import System.FilePath (takeExtension)
import qualified System.FilePath as FP
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Aeson as Aeson

-- These handlers embed files in the executable at compile time to avoid a
-- runtime dependency, and for efficiency.

getFaviconR :: Handler TypedContent
getFaviconR = return $ TypedContent (BS.pack "image/x-icon")
                     $ toContent $(embedFile "config/favicon.ico")

robotsBaseContent :: Text
robotsBaseContent = TE.decodeUtf8 $(embedFile "config/robots.txt")

getRobotsR :: Handler TypedContent
getRobotsR = do
    app <- getYesod
    let rootUrl = canonicalRootUrl app
        body =
            T.stripEnd robotsBaseContent
                <> "\n\nSitemap: "
                <> rootUrl
                <> "/sitemap.xml\n"
    addHeader "X-Content-Type-Options" ("nosniff" :: Text)
    return $ TypedContent typePlain $ toContent body

getSitemapR :: Handler TypedContent
getSitemapR = do
    app <- getYesod
    wordEntities <- runDB $ selectList [] [Asc WordText]
    let rootUrl = canonicalRootUrl app
        staticUrls =
            [ rootUrl <> "/"
            , rootUrl <> "/search"
            , rootUrl <> "/new-word"
            ]
        wordUrls =
            map (\(Entity wordId _) -> rootUrl <> "/words/" <> toPathPiece wordId) wordEntities
        xmlBody =
            T.concat
                [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                , "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
                , T.concat $ map sitemapUrlEntry (staticUrls <> wordUrls)
                , "</urlset>"
                ]
    addHeader "X-Content-Type-Options" ("nosniff" :: Text)
    return $ TypedContent "application/xml; charset=utf-8" $ toContent xmlBody

getHealthzR :: Handler Value
getHealthzR = do
    _ <- runDB $ count ([] :: [Filter Word])
    now <- liftIO getCurrentTime
    returnJson $
        object
            [ "ok" .= True
            , "timestamp" .= T.pack (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" now)
            ]

getWordOgImageR :: WordId -> Handler TypedContent
getWordOgImageR wordId = do
    word <- runDB $ get404 wordId
    mMeaning <- runDB $ selectFirst [MeaningWord ==. wordId] [Asc MeaningId]
    addHeader "Cache-Control" ("public, max-age=3600" :: Text)
    addHeader "X-Content-Type-Options" ("nosniff" :: Text)
    return $
        TypedContent
            "image/svg+xml; charset=utf-8"
            $ toContent (wordOgSvg word (entityVal <$> mMeaning))

getWordOgPngR :: WordId -> Handler TypedContent
getWordOgPngR wordId = do
    redirect (WordOgImageR wordId)

getFrontendAssetR :: [Text] -> Handler TypedContent
getFrontendAssetR pieces =
    serveFrontendPath ("_app" : pieces)

getFrontendNewWordR :: Handler TypedContent
getFrontendNewWordR =
    serveFrontendPath ["new-word"]

getFrontendLoginR :: Handler TypedContent
getFrontendLoginR =
    serveFrontendPath ["login"]

getFrontendWordDetailR :: WordId -> Handler TypedContent
getFrontendWordDetailR wordId = do
    word <- runDB $ get404 wordId
    mMeaning <- runDB $ selectFirst [MeaningWord ==. wordId] [Asc MeaningId]
    app <- getYesod
    htmlTemplate <- loadFrontendHtml app ["words", toPathPiece wordId]
    applySecurityHeaders
    let pageUrl = canonicalRootUrl app <> "/words/" <> toPathPiece wordId
        imageUrl = canonicalRootUrl app <> ogImageSvgPath wordId
        titleText = wordMetaTitle word
        descriptionText = wordMetaDescription word (entityVal <$> mMeaning)
        document = injectHeadMetadata pageUrl imageUrl titleText descriptionText (wordStructuredData pageUrl word (entityVal <$> mMeaning)) htmlTemplate
    return $ TypedContent "text/html; charset=utf-8" $ toContent document

serveFrontendPath :: [Text] -> Handler TypedContent
serveFrontendPath pieces = do
    app <- getYesod
    applySecurityHeaders
    targetPath <- resolveFrontendPath app pieces
    let contentType = frontendContentType targetPath
    sendFile contentType targetPath

applySecurityHeaders :: Handler ()
applySecurityHeaders = do
    addHeader "Content-Security-Policy" frontendCspPolicy
    addHeader "Referrer-Policy" ("strict-origin-when-cross-origin" :: Text)
    addHeader "X-Content-Type-Options" ("nosniff" :: Text)
    addHeader "X-Frame-Options" ("SAMEORIGIN" :: Text)

frontendCspPolicy :: Text
frontendCspPolicy =
    T.intercalate
        "; "
        [ "default-src 'self'"
        , "script-src 'self' 'unsafe-inline' https://pagead2.googlesyndication.com https://partner.googleadservices.com https://www.googletagservices.com https://www.google.com"
        , "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com"
        , "font-src 'self' https://fonts.gstatic.com data:"
        , "img-src 'self' data: blob: https:"
        , "connect-src 'self' https:"
        , "frame-src 'self' https:"
        , "object-src 'none'"
        , "base-uri 'self'"
        , "form-action 'self'"
        , "frame-ancestors 'self'"
        ]

resolveFrontendPath :: App -> [Text] -> Handler FilePath
resolveFrontendPath app pieces = do
    let staticRoot = appStaticDir $ appSettings app
        frontendRoot = staticRoot FP.</> "app"
        relativePath = FP.joinPath $ map unpack pieces
        requestedPath =
            if null pieces
                then frontendRoot FP.</> "index.html"
                else frontendRoot FP.</> relativePath
        fallbackPath = frontendRoot FP.</> "index.html"
    fallbackExists <- liftIO $ doesFileExist fallbackPath
    unless fallbackExists notFound
    requestedExists <- liftIO $ doesFileExist requestedPath
    pure $ if requestedExists then requestedPath else fallbackPath

loadFrontendHtml :: App -> [Text] -> Handler Text
loadFrontendHtml app pieces = do
    targetPath <- resolveFrontendPath app pieces
    liftIO $ readFileUtf8 targetPath

canonicalRootUrl :: App -> Text
canonicalRootUrl app =
    let rootUrl = appRoot $ appSettings app
    in fromMaybe rootUrl (T.stripSuffix "/" rootUrl)

ogImageSvgPath :: WordId -> Text
ogImageSvgPath wordId =
    "/og/word/" <> toPathPiece wordId <> "/card.svg"

sitemapUrlEntry :: Text -> Text
sitemapUrlEntry url =
    "<url><loc>" <> htmlEscape url <> "</loc></url>"

injectHeadMetadata :: Text -> Text -> Text -> Text -> Text -> Text -> Text
injectHeadMetadata pageUrl imageUrl titleText descriptionText structuredData document =
    let metaBlock =
            T.concat
                [ "\n<link rel=\"canonical\" href=\"", htmlEscape pageUrl, "\">"
                , "\n<meta name=\"description\" content=\"", htmlEscape descriptionText, "\">"
                , "\n<meta name=\"robots\" content=\"index,follow,max-image-preview:large\">"
                , "\n<meta property=\"og:type\" content=\"article\">"
                , "\n<meta property=\"og:title\" content=\"", htmlEscape titleText, "\">"
                , "\n<meta property=\"og:description\" content=\"", htmlEscape descriptionText, "\">"
                , "\n<meta property=\"og:url\" content=\"", htmlEscape pageUrl, "\">"
                , "\n<meta property=\"og:image\" content=\"", htmlEscape imageUrl, "\">"
                , "\n<meta property=\"og:image:type\" content=\"image/svg+xml\">"
                , "\n<meta property=\"og:image:width\" content=\"1200\">"
                , "\n<meta property=\"og:image:height\" content=\"630\">"
                , "\n<meta property=\"og:image:alt\" content=\"", htmlEscape titleText, "\">"
                , "\n<meta name=\"twitter:card\" content=\"summary\">"
                , "\n<meta name=\"twitter:title\" content=\"", htmlEscape titleText, "\">"
                , "\n<meta name=\"twitter:description\" content=\"", htmlEscape descriptionText, "\">"
                , "\n<meta name=\"twitter:image\" content=\"", htmlEscape imageUrl, "\">"
                , "\n<script type=\"application/ld+json\">", structuredData, "</script>\n"
                ]
    in injectBeforeHeadClose metaBlock $ replaceHtmlTitle titleText document

replaceHtmlTitle :: Text -> Text -> Text
replaceHtmlTitle titleText document =
    case T.breakOn "<title>" document of
        (before, matched)
            | T.null matched -> document
            | otherwise ->
                let afterOpen = T.drop (T.length ("<title>" :: Text)) matched
                    afterClose = snd $ T.breakOn "</title>" afterOpen
                in before <> "<title>" <> htmlEscape titleText <> afterClose

injectBeforeHeadClose :: Text -> Text -> Text
injectBeforeHeadClose inserted document =
    if "</head>" `T.isInfixOf` document
        then T.replace "</head>" (inserted <> "</head>") document
        else inserted <> document

wordMetaTitle :: Word -> Text
wordMetaTitle word =
    wordText word <> maybe "" (\transcription -> " [" <> transcription <> "]") (wordTranscription word) <> " | KDIC"

wordMetaDescription :: Word -> Maybe Meaning -> Text
wordMetaDescription word mMeaning =
    truncateMetaDescription $
        fromMaybe
            ("Explore the definition, examples, and community stories for " <> wordText word <> ".")
            (meaningDefinition <$> mMeaning)

truncateMetaDescription :: Text -> Text
truncateMetaDescription textValue
    | T.length compact <= 160 = compact
    | otherwise = T.take 157 compact <> "..."
  where
    compact = T.unwords $ T.words textValue

wordStructuredData :: Text -> Word -> Maybe Meaning -> Text
wordStructuredData pageUrl word mMeaning =
    TE.decodeUtf8 . LBS.toStrict $
        Aeson.encode $
            object
                [ "@context" .= ("https://schema.org" :: Text)
                , "@type" .= ("DefinedTerm" :: Text)
                , "name" .= wordText word
                , "description" .= wordMetaDescription word mMeaning
                , "url" .= pageUrl
                , "inDefinedTermSet" .= ("KDIC" :: Text)
                ]

wordOgSvg :: Word -> Maybe Meaning -> Text
wordOgSvg word mMeaning =
    T.concat
        [ "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1200\" height=\"630\" viewBox=\"0 0 1200 630\" role=\"img\" aria-labelledby=\"title desc\">"
        , "<title id=\"title\">", htmlEscape (wordMetaTitle word), "</title>"
        , "<desc id=\"desc\">", htmlEscape (wordMetaDescription word mMeaning), "</desc>"
        , "<defs>"
        , "<linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">"
        , "<stop offset=\"0%\" stop-color=\"#fff9ef\"/>"
        , "<stop offset=\"55%\" stop-color=\"#fff1a8\"/>"
        , "<stop offset=\"100%\" stop-color=\"#7ef0b2\"/>"
        , "</linearGradient>"
        , "<filter id=\"shadow\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"140%\">"
        , "<feDropShadow dx=\"10\" dy=\"10\" stdDeviation=\"0\" flood-color=\"#000000\" flood-opacity=\"1\"/>"
        , "</filter>"
        , "</defs>"
        , "<rect width=\"1200\" height=\"630\" fill=\"url(#bg)\"/>"
        , "<circle cx=\"1030\" cy=\"90\" r=\"130\" fill=\"#57d5e5\" fill-opacity=\"0.24\"/>"
        , "<circle cx=\"170\" cy=\"560\" r=\"150\" fill=\"#ffb39a\" fill-opacity=\"0.28\"/>"
        , "<rect x=\"60\" y=\"54\" width=\"1080\" height=\"522\" rx=\"26\" fill=\"#fffdf7\" stroke=\"#111111\" stroke-width=\"6\" filter=\"url(#shadow)\"/>"
        , "<text x=\"110\" y=\"126\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"26\" font-weight=\"700\" letter-spacing=\"4\" fill=\"#111111\">KDIC WORD CARD</text>"
        , "<text x=\"110\" y=\"214\" font-family=\"Georgia, 'Times New Roman', serif\" font-size=\"92\" font-weight=\"700\" fill=\"#111111\">", htmlEscape (truncateOgTitle $ wordText word), "</text>"
        , transcriptionBlock
        , definitionBlock
        , "<rect x=\"110\" y=\"488\" width=\"214\" height=\"64\" rx=\"14\" fill=\"#7ef0b2\" stroke=\"#111111\" stroke-width=\"5\"/>"
        , "<text x=\"142\" y=\"530\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"28\" font-weight=\"700\" fill=\"#111111\">Official entry</text>"
        , "<text x=\"800\" y=\"530\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"30\" font-weight=\"700\" fill=\"#111111\">kdic.app</text>"
        , "</svg>"
        ]
  where
    transcriptionBlock =
        maybe
            ""
            (\transcription ->
                "<text x=\"112\" y=\"260\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"34\" fill=\"#444444\">[" <> htmlEscape transcription <> "]</text>"
            )
            (wordTranscription word)
    definitionBlock =
        T.concat $
            zipWith
                (\lineValue cardIndex ->
                    let yPos = 338 + (cardIndex * 50)
                    in "<text x=\"110\" y=\"" <> tshow yPos <> "\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"32\" fill=\"#303030\">" <> htmlEscape lineValue <> "</text>"
                )
                (wrapOgText $ wordMetaDescription word mMeaning)
                [0 :: Int ..]

truncateOgTitle :: Text -> Text
truncateOgTitle titleText
    | T.length compact <= 18 = compact
    | otherwise = T.take 16 compact <> "..."
  where
    compact = T.strip titleText

wrapOgText :: Text -> [Text]
wrapOgText =
    take 4 . wrapWords 34 . T.words . normalizeOgWhitespace

wrapWords :: Int -> [Text] -> [Text]
wrapWords _ [] = []
wrapWords maxChars sourceWords =
    let (lineWords, restWords) = consumeWords maxChars [] sourceWords
    in case lineWords of
        [] -> []
        _ -> T.unwords lineWords : wrapWords maxChars restWords

consumeWords :: Int -> [Text] -> [Text] -> ([Text], [Text])
consumeWords _ acc [] = (reverse acc, [])
consumeWords maxChars [] (nextWord : remainingWords)
    | T.length nextWord > maxChars = ([T.take maxChars nextWord <> "..."], remainingWords)
    | otherwise = consumeWords maxChars [nextWord] remainingWords
consumeWords maxChars acc (nextWord : remainingWords)
    | currentLength + 1 + T.length nextWord <= maxChars = consumeWords maxChars (nextWord : acc) remainingWords
    | otherwise = (reverse acc, nextWord : remainingWords)
  where
    currentLength = T.length $ T.unwords $ reverse acc

normalizeOgWhitespace :: Text -> Text
normalizeOgWhitespace =
    T.unwords . T.words . T.map (\char -> if isSpace char then ' ' else char)

htmlEscape :: Text -> Text
htmlEscape =
    T.concatMap $ \char ->
        case char of
            '&' -> "&amp;"
            '<' -> "&lt;"
            '>' -> "&gt;"
            '"' -> "&quot;"
            '\'' -> "&#39;"
            _ -> T.singleton char

frontendContentType :: FilePath -> ContentType
frontendContentType filePath =
    case takeExtension filePath of
        ".html" -> "text/html; charset=utf-8"
        ".js" -> "application/javascript; charset=utf-8"
        ".css" -> "text/css; charset=utf-8"
        ".json" -> "application/json"
        ".svg" -> "image/svg+xml"
        ".png" -> "image/png"
        ".jpg" -> "image/jpeg"
        ".jpeg" -> "image/jpeg"
        ".webp" -> "image/webp"
        ".woff" -> "font/woff"
        ".woff2" -> "font/woff2"
        _ -> "application/octet-stream"
