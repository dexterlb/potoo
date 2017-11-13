module ContractsTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string, float)
import Test exposing (..)

import Dict

import Json.Encode

import Contracts exposing (..)


suite : Test
suite =
  describe "Parsing contract"
    [ fuzz string "can parse string value" <|
      \s -> Expect.equal 
        (parseContract (Json.Encode.encode 4 (Json.Encode.string s)))
        (Ok (StringValue s))
    , fuzz int "can parse int value" <|
      \i -> Expect.equal 
        (parseContract (Json.Encode.encode 4 (Json.Encode.int i)))
        (Ok (IntValue i))
    , fuzz float "can parse float value" <|
      \f -> Expect.equal 
        (parseContract (Json.Encode.encode 4 (Json.Encode.float (f + 0.42))))
        (Ok (FloatValue (f + 0.42)))
    , todo "parse map and list contracts"
    , test "can parse a delegate object" <|
      \_ -> Expect.equal
        (parseContract """
          {
            "__type__": "delegate",
            "destination": 42,
            "data": {"foo": "bar"}
          }
        """)
        (Ok (
          Delegate {
            destination = 42,
            data = Dict.fromList [
              ("foo", "bar")
            ]
          }
        ))
    , todo "parse function contracts"
    ]
