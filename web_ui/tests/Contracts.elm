module Contracts exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string)
import Test exposing (..)


suite : Test
suite =
    describe "Parsing contract"
      [ test "can parse string value" <|
            \_ -> Expect.equal (parseContract "\"foo\"") "foo"
      ]
