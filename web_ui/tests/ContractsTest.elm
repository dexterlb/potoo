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
        , test "can parse int type" <|
            \_ -> Expect.equal
              (parseType "\"int\"")
              (Ok TInt)
        , test "can parse float type" <|
            \_ -> Expect.equal
              (parseType "\"float\"")
              (Ok TFloat)
        , test "can parse bool type" <|
            \_ -> Expect.equal
              (parseType "\"bool\"")
              (Ok TBool)
        , test "can parse atom type" <|
            \_ -> Expect.equal
              (parseType "\"atom\"")
              (Ok TAtom)
        , test "can parse string type" <|
            \_ -> Expect.equal
              (parseType "\"string\"")
              (Ok TString)
        , test "can parse string literal type" <|
            \_ -> Expect.equal
              (parseType """
                ["literal", "foo"]
              """)
              (Ok <| TLiteral "\"foo\"")
        , test "can parse JSON literal type" <|
            -- need something more elaborate here, but cba
            \_ -> Expect.equal
              (parseType """
                ["literal", {"foo": 42, "bar": "baz"}]
              """)
              (Ok <| TLiteral "{\"foo\": 42, \"bar\": \"baz\"}")
        , test "can parse delegate type" <|
            \_ -> Expect.equal
              (parseType "\"delegate\"")
              (Ok TDelegate)
        , test "can parse tagged type" <|
            \_ -> Expect.equal
              (parseType """
                ["type", "int", {"foo": "bar"}]
              """)
              (Ok <| TType TInt <| Dict.fromList [("foo", "bar")])
        , test "can parse channel of ints" <|
            \_ -> Expect.equal
              (parseType """
                ["channel", "int"]
              """)
              (Ok <| TChannel TInt)
        , test "can parse union of simple types" <|
            \_ -> Expect.equal
              (parseType """
                ["union", "int", "float"]
              """)
              (Ok <| TUnion TInt TFloat)
        , test "can parse nested union" <|
            \_ -> Expect.equal
              (parseType """
                ["union", ["union", "int", "string"], "float"]
              """)
              (Ok <| TUnion (TUnion TInt TString) TFloat)
        , test "can parse list of strings" <|
            \_ -> Expect.equal
              (parseType """
                ["list", "string"]
              """)
              (Ok <| TList TString)
        , test "can parse nested list" <|
            \_ -> Expect.equal
              (parseType """
                ["list", ["list" "int"]]
              """)
              (Ok <| TList (TList TInt))
        , test "can parse map string -> int" <|
            \_ -> Expect.equal
              (parseType """
                ["map", "string", "int"]
              """)
              (Ok <| TMap TString TInt)
        , test "can parse nested map" <|
            \_ -> Expect.equal
              (parseType """
                ["map", "string", ["map" "string" "int"]]
              """)
              (Ok <| TMap TString (TMap TString TInt))
        , test "can parse tuple" <|
            \_ -> Expect.equal
              (parseType """
                ["struct", ["int", "string"]]
              """)
              (Ok <| TTuple [TInt, TString])
        , test "can parse struct" <|
            \_ -> Expect.equal
              (parseType """
                ["struct", {"foo": "int", "bar": "string"}]
              """)
              (Ok <| TStruct <| Dict.fromList [("foo", TInt), ("bar", TString)])
        ]
    ]
