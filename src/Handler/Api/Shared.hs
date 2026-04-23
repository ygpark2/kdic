{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Shared
    ( apiError
    , cleanOptionalText
    , commentValue
    , isoTime
    , loadUserMap
    , loadWordMap
    , meaningValue
    , notificationValue
    , requireApiAuthPair
    , userValue
    , wordSubmissionValue
    , wordValue
    ) where

import Import
import Database.Persist.Sql (fromSqlKey)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Network.HTTP.Types.Status (Status, status401)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

apiError :: Status -> Text -> Handler a
apiError status message =
    sendResponseStatus status $ object ["message" .= message]

requireApiAuthPair :: Handler (UserId, User)
requireApiAuthPair = do
    mAuth <- maybeAuth
    case mAuth of
        Just (Entity userId user) -> pure (userId, user)
        Nothing -> apiError status401 "Authentication required."

cleanOptionalText :: Maybe Text -> Maybe Text
cleanOptionalText =
    fmap T.strip >=> \value ->
        if value == ""
            then Nothing
            else Just value

isoTime :: UTCTime -> Text
isoTime =
    pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

userValue :: User -> Value
userValue user =
    object
        [ "ident" .= userIdent user
        , "displayName" .= fromMaybe (userIdent user) (userName user)
        , "description" .= userDescription user
        , "role" .= userRole user
        , "isAdmin" .= (userRole user == ("admin" :: Text))
        ]

wordValue :: Entity Word -> Value
wordValue (Entity wordId word) =
    object
        [ "id" .= fromSqlKey wordId
        , "kind" .= ("word" :: Text)
        , "status" .= ("official" :: Text)
        , "text" .= wordText word
        , "transcription" .= wordTranscription word
        , "pronunciationUrl" .= wordPronunciationUrl word
        ]

wordSubmissionValue :: Maybe UserId -> Map.Map UserId User -> Map.Map WordSubmissionId Int -> [WordSubmissionId] -> Entity WordSubmission -> Value
wordSubmissionValue mViewerId creatorMap voteCountMap votedIds (Entity submissionId submission) =
    object
        [ "id" .= fromSqlKey submissionId
        , "kind" .= ("submission" :: Text)
        , "text" .= wordSubmissionText submission
        , "transcription" .= wordSubmissionTranscription submission
        , "pronunciationUrl" .= wordSubmissionPronunciationUrl submission
        , "status" .= wordSubmissionStatus submission
        , "submittedAt" .= isoTime (wordSubmissionSubmittedAt submission)
        , "updatedAt" .= isoTime (wordSubmissionUpdatedAt submission)
        , "approvedAt" .= fmap isoTime (wordSubmissionApprovedAt submission)
        , "promotedWordId" .= fmap fromSqlKey (wordSubmissionPromotedWord submission)
        , "voteCount" .= fromMaybe 0 (Map.lookup submissionId voteCountMap)
        , "voted" .= maybe False (\_ -> submissionId `elem` votedIds) mViewerId
        , "creator" .= maybe Null userValue (Map.lookup (wordSubmissionCreator submission) creatorMap)
        ]

meaningValue :: Entity Meaning -> [Entity Example] -> Value
meaningValue (Entity meaningId meaning) examples =
    object
        [ "id" .= fromSqlKey meaningId
        , "partOfSpeech" .= meaningPartOfSpeech meaning
        , "definition" .= meaningDefinition meaning
        , "examples" .=
            map
                (\(Entity exampleId example) ->
                    object
                        [ "id" .= fromSqlKey exampleId
                        , "sentence" .= exampleSentence example
                        , "translation" .= exampleTranslation example
                        ]
                )
                examples
        ]

commentValue :: Maybe UserId -> Map.Map UserId User -> Entity WordComment -> Value
commentValue mViewerId authorMap (Entity commentId comment) =
    let mauthor = Map.lookup (wordCommentAuthor comment) authorMap
    in object
        [ "id" .= fromSqlKey commentId
        , "content" .= wordCommentContent comment
        , "parentCommentId" .= fmap fromSqlKey (wordCommentParentComment comment)
        , "createdAt" .= isoTime (wordCommentCreatedAt comment)
        , "updatedAt" .= isoTime (wordCommentUpdatedAt comment)
        , "canManage" .= maybe False (\viewerId -> viewerId == wordCommentAuthor comment) mViewerId
        , "author" .= maybe Null userValue mauthor
        ]

notificationValue :: Map.Map UserId User -> Map.Map WordId Word -> Entity Notification -> Value
notificationValue actorMap wordMap (Entity notificationId notification) =
    object
        [ "id" .= fromSqlKey notificationId
        , "kind" .= notificationKind notification
        , "isRead" .= notificationIsRead notification
        , "createdAt" .= isoTime (notificationCreatedAt notification)
        , "actor" .= (notificationActor notification >>= (`Map.lookup` actorMap) >>= pure . userValue)
        , "word" .= (notificationWord notification >>= (`Map.lookup` wordMap) >>= pure . wordText)
        , "commentId" .= fmap fromSqlKey (notificationComment notification)
        ]

loadUserMap :: [UserId] -> Handler (Map.Map UserId User)
loadUserMap userIds
    | null uniqueIds = pure Map.empty
    | otherwise = do
        users <- runDB $ selectList [UserId <-. uniqueIds] []
        pure $ Map.fromList $ map (\(Entity userId user) -> (userId, user)) users
  where
    uniqueIds = ordNub userIds

loadWordMap :: [WordId] -> Handler (Map.Map WordId Word)
loadWordMap wordIds
    | null uniqueIds = pure Map.empty
    | otherwise = do
        words <- runDB $ selectList [WordId <-. uniqueIds] []
        pure $ Map.fromList $ map (\(Entity wordId word) -> (wordId, word)) words
  where
    uniqueIds = ordNub wordIds
