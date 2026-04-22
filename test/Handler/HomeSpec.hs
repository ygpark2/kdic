module Handler.HomeSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    yit "redirects the legacy homepage to the split frontend" $ do
        get HomeR
        statusIs 303

    yit "serves an anonymous session payload from the public API" $ do
        get ApiSessionR
        statusIs 200
        bodyContains "\"authenticated\":false"
