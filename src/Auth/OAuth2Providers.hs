{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
module Auth.OAuth2Providers
    ( oauth2Kakao
    , oauth2Naver
    ) where

import ClassyPrelude
import Data.Aeson (FromJSON (..), Value, eitherDecode, withObject, (.:))
import URI.ByteString (URI, parseURI, strictURIParserOptions)
import Yesod.Auth (AuthPlugin, Creds (..), YesodAuth)
import Yesod.Auth.OAuth2.Prelude (OAuth2 (..), authGetProfile, authOAuth2, setExtra)

newtype KakaoProfile = KakaoProfile
    { kakaoId :: Integer
    }

instance FromJSON KakaoProfile where
    parseJSON = withObject "KakaoProfile" $ \o ->
        KakaoProfile <$> o .: "id"

newtype NaverResponse = NaverResponse
    { naverResponse :: NaverProfile
    }

newtype NaverProfile = NaverProfile
    { naverId :: Text
    }

instance FromJSON NaverResponse where
    parseJSON = withObject "NaverResponse" $ \o ->
        NaverResponse <$> o .: "response"

instance FromJSON NaverProfile where
    parseJSON = withObject "NaverProfile" $ \o ->
        NaverProfile <$> o .: "id"

oauth2Kakao :: YesodAuth m => Text -> Text -> AuthPlugin m
oauth2Kakao clientId clientSecret =
    authOAuth2 "kakao" oauth2Config $ \manager token -> do
        (_, userResponse) <- authGetProfile @Value "kakao" manager token kakaoProfileUri
        userId <- parseKakaoId userResponse
        pure Creds
            { credsPlugin = "kakao"
            , credsIdent = userId
            , credsExtra = setExtra token userResponse
            }
  where
    oauth2Config = OAuth2
        { oauth2ClientId = clientId
        , oauth2ClientSecret = Just clientSecret
        , oauth2AuthorizeEndpoint = "https://kauth.kakao.com/oauth/authorize"
        , oauth2TokenEndpoint = "https://kauth.kakao.com/oauth/token"
        , oauth2RedirectUri = Nothing
        }

    parseKakaoId :: LByteString -> IO Text
    parseKakaoId raw =
        case eitherDecode raw of
            Right (KakaoProfile kid) -> pure $ tshow kid
            Left err -> throwString $ "Kakao profile parse failed: " <> err

    kakaoProfileUri :: URI
    kakaoProfileUri = parseProfileUri "https://kapi.kakao.com/v2/user/me"

oauth2Naver :: YesodAuth m => Text -> Text -> AuthPlugin m
oauth2Naver clientId clientSecret =
    authOAuth2 "naver" oauth2Config $ \manager token -> do
        (_, userResponse) <- authGetProfile @Value "naver" manager token naverProfileUri
        userId <- parseNaverId userResponse
        pure Creds
            { credsPlugin = "naver"
            , credsIdent = userId
            , credsExtra = setExtra token userResponse
            }
  where
    oauth2Config = OAuth2
        { oauth2ClientId = clientId
        , oauth2ClientSecret = Just clientSecret
        , oauth2AuthorizeEndpoint = "https://nid.naver.com/oauth2.0/authorize"
        , oauth2TokenEndpoint = "https://nid.naver.com/oauth2.0/token"
        , oauth2RedirectUri = Nothing
        }

    parseNaverId :: LByteString -> IO Text
    parseNaverId raw =
        case eitherDecode raw of
            Right (NaverResponse (NaverProfile nid)) -> pure nid
            Left err -> throwString $ "Naver profile parse failed: " <> err

    naverProfileUri :: URI
    naverProfileUri = parseProfileUri "https://openapi.naver.com/v1/nid/me"

parseProfileUri :: Text -> URI
parseProfileUri urlText =
    case parseURI strictURIParserOptions (encodeUtf8 urlText) of
        Right uri -> uri
        Left err -> error $ "OAuth2 profile URI parse failed: " <> unpack (tshow err)
