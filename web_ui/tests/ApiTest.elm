module ApiTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string, float)
import Test exposing (..)

import Api exposing (..)
import Contracts exposing (..)

suite : Test
suite =
  describe "Api"
    [ describe "Parsing response"
        [ test "can parse GotContract" <|
          \_ -> Expect.equal
            (parseResponse """
              ["foo", {"pid": 42, "msg": "got_contract"}]
            """)
            (Ok <| GotContract 42 (StringValue "foo"))
        ]
    ]