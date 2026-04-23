module Handler.AuthSpec (spec) where

import TestImport

spec :: Spec
spec = withApp $ do
    yit "redirects unauthorized profile requests to the frontend login route" $ do
        get ProfileR
        statusIs 303

    yit "protects the admin user creation screen" $ do
        get AdminUserNewR
        statusIs 303

    yit "protects the admin setting creation screen" $ do
        get AdminSettingNewR
        statusIs 303

    yit "protects the admin ad creation screen" $ do
        get AdminAdNewR
        statusIs 303
