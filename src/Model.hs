{-# LANGUAGE TemplateHaskell, TypeFamilies, GADTs, DerivingStrategies, GeneralizedNewtypeDeriving, StandaloneDeriving, UndecidableInstances, DataKinds, FlexibleInstances, MultiParamTypeClasses, TypeOperators, NoImplicitPrelude #-}
module Model where

import ClassyPrelude.Yesod hiding (Word)
import Database.Persist.Quasi

-- You can define all of your database entities in the entities file.
-- You can find more information on persistent and how to declare entities
-- at:
-- http://www.yesodweb.com/book/persistent/
share [mkPersist sqlSettings, mkMigrate "migrateAll"]
    $(persistFileWith lowerCaseSettings "config/models")
