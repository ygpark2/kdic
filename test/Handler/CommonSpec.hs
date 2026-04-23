module Handler.CommonSpec (spec) where

import qualified Model as M
import TestImport

spec :: Spec
spec = withApp $ do
    yit "serves the frontend search page at the root-level search route" $ do
        get SearchR
        statusIs 200

    yit "serves a sitemap for public routes" $ do
        _ <- runDB $ insert $ M.Word (pack "SitemapWord") Nothing Nothing
        get SitemapR
        statusIs 200
        bodyContains "<urlset"
        bodyContains "/words/"

    yit "serves a health check payload" $ do
        get HealthzR
        statusIs 200
        bodyContains "\"ok\":true"

    yit "injects OG image metadata into word detail pages" $ do
        wordId <- runDB $ insert $ M.Word (pack "OgWord") (Just $ pack "og-word") Nothing
        get (FrontendWordDetailR wordId)
        statusIs 200
        bodyContains "og:image"
        bodyContains "/og/word/"
        bodyContains "/card.png"

    yit "serves a generated SVG OG image for a word" $ do
        wordId <- runDB $ insert $ M.Word (pack "CardWord") (Just $ pack "card-word") Nothing
        get (WordOgImageR wordId)
        statusIs 200
        bodyContains "<svg"
        bodyContains "CardWord"

    yit "serves a generated PNG OG image for a word" $ do
        wordId <- runDB $ insert $ M.Word (pack "PngWord") (Just $ pack "png-word") Nothing
        get (WordOgPngR wordId)
        statusIs 200
