module Handler.CommonSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    yit "redirects the legacy search page to the frontend search route" $ do
        get SearchR
        statusIs 303
