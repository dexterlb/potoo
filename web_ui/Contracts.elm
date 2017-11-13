module Contracts exposing (..)
import Dict exposing (Dict)

import Json.Decode exposing (Decoder, decodeString, string, int, float, oneOf, andThen, field, fail)
import Result

type alias Data = Dict String String

type Type
  = TInt Int
  | TFloat Float

type Contract
  = StringValue String
  | IntValue Int
  | FloatValue Float
  | Delegate {
    destination : Int,
    data: Data
  }
  | Function {
    argument: Type,
    name: String,
    retval: Type,
    data: Data
  }
  | MapContract (Dict String Contract)
  | ListContract (List Contract)

parseContract : String -> Result String Contract
parseContract s = decodeString contractDecoder s

contractDecoder : Decoder Contract
contractDecoder = oneOf [
    stringValueDecoder,
    intValueDecoder,
    floatValueDecoder,
    objectDecoder
  ]

stringValueDecoder : Decoder Contract
stringValueDecoder = Json.Decode.map StringValue string

intValueDecoder : Decoder Contract
intValueDecoder = Json.Decode.map IntValue int

floatValueDecoder : Decoder Contract
floatValueDecoder = Json.Decode.map FloatValue float

objectDecoder : Decoder Contract
objectDecoder = field "__type__" string
  |> andThen (\t -> case t of
    "delegate" -> delegateDecoder
    "function" -> functionDecoder
    _ -> fail <| "object type `" ++ t ++ "' is unknown")

delegateDecoder : Decoder Contract
delegateDecoder = fail "not implemented"

functionDecoder : Decoder Contract
functionDecoder = fail "not implemented"
