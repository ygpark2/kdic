module Handler.CommonSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    yit "serves the frontend search page at the root-level search route" $ do
        get SearchR
        statusIs 200
