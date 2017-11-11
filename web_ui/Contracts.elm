module Contracts exposing (..)
import Dict exposing (Dict)

import Json.Decode exposing (decodeString, string)
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
parseContract s = Result.map StringValue (decodeString string s)