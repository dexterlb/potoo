module ContractsTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string, float)
import Test exposing (..)

import Dict

import Json.Encode

import Contracts exposing (..)


suite : Test
suite =
  describe "Contracts"
    [ describe "Parsing contract"
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
        , test "can parse a function object" <|
          \_ -> Expect.equal
            (parseContract """
              {
                "__type__": "function",
                "argument": null,
                "name": "foo",
                "retval": null,
                "data": {"foo": "bar"}
              }
            """)
            (Ok (
              Function {
                argument = TNil,
                name = "foo",
                retval = TNil,
                data = Dict.fromList [
                  ("foo", "bar")
                ]
              }
            ))
          , test "can parse a nested map contract" <|
            \_ -> Expect.equal
              (parseContract """
                {
                  "foo": 42,
                  "bar": {
                    "baz": 1337,
                    "qux": "bim"
                  }
                }
              """)
              (Ok (
                MapContract (Dict.fromList [
                  ("foo", IntValue 42),
                  ("bar", MapContract (Dict.fromList [
                    ("baz", IntValue 1337),
                    ("qux", StringValue "bim")
                  ]))
                ])
              ))
          , test "can parse a nested list contract" <|
            \_ -> Expect.equal
              (parseContract """
                [
                  42,
                  [
                    1337,
                    "bim"
                  ]
                ]
              """)
              (Ok (
                ListContract [
                  IntValue 42,
                  ListContract [
                    IntValue 1337,
                    StringValue "bim"
                  ]
                ]
              ))
        ]
      , describe "Parse types"
        [ test "can parse nil type" <|
          \_ -> Expect.equal
            (parseType "null")
            (Ok TNil)
        ]
    ]
