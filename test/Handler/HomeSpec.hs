module Handler.HomeSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    yit "serves the frontend homepage at the root route" $ do
        get HomeR
        statusIs 200

    yit "serves an anonymous session payload from the public API" $ do
        get ApiSessionR
        statusIs 200
        bodyContains "\"authenticated\":false"
