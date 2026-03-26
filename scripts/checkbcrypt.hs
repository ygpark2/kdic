{-# LANGUAGE OverloadedStrings #-}
import Crypto.BCrypt
import Data.ByteString.Char8 (pack)
main :: IO ()
main = do
    let hashed = "$2y$04$IiuJAkCFBHMzADC/yBKHIOqC0i7/MzTAXKamBFt4QD5RRYkH0HgG2"
    print $ validatePassword (pack hashed) (pack "1234")
