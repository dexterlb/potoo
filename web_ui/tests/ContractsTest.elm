module ContractsTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string)
import Test exposing (..)

import Json.Encode

import Contracts exposing (..)


suite : Test
suite =
  describe "Parsing contract"
    [ fuzz string "can parse string value" <|
      \s -> Expect.equal 
        (parseContract (Json.Encode.encode 4 (Json.Encode.string s)))
        (Ok (StringValue s))
    ]
