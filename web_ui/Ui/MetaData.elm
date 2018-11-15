module Ui.MetaData exposing(getMetaData, MetaData, noMetaData, dataMetaData, PropData, noPropData)

import Contracts
import Contracts exposing (Contract, Properties, emptyData, Data, fetch, Pid, PropertyID)

import Dict
import Dict exposing(Dict)

import Json.Encode
import Json.Decode

type alias MetaData =
  { key         : String
  , propData    : PropData
  , uiLevel     : Int
  , description : String
  , enabled     : Bool
  , extra       : Data
  }

type alias PropData =
  { hasGetter       : Bool
  , hasSetter       : Bool
  , hasSubscriber   : Bool
  , property        : (Pid, PropertyID)
  }

noMetaData : MetaData
noMetaData =
  { key = ""
  , uiLevel = 0
  , description = ""
  , enabled = True
  , extra = emptyData
  , propData = noPropData
  }

noPropData : PropData
noPropData =
  { hasGetter     = False
  , hasSetter     = False
  , hasSubscriber = False
  , property      = (-1, -1)
  }

getMetaData : String -> Contract -> Pid -> Properties -> MetaData
getMetaData key c pid properties = case c of
  Contracts.StringValue _ -> case key of
    "description" -> { noMetaData | key = key, uiLevel = 1 }
    _             -> { noMetaData | key = key }
  Contracts.BoolValue _ ->   case key of
    "enabled"     -> { noMetaData | key = key, uiLevel = 1 }
    _             -> { noMetaData | key = key }
  Contracts.IntValue _ ->    case key of
    "ui_level"    -> { noMetaData | key = key, uiLevel = 1 }
    _             -> { noMetaData | key = key }
  Contracts.PropertyKey propertyID _ -> let
      { getter, setter, subscriber } = properties |> fetch pid |> fetch propertyID
      priorData = extractData c pid properties |> dataMetaData key
    in let
      propData =
        { hasGetter     = getter /= Nothing
        , hasSetter     = setter /= Nothing
        , hasSubscriber = subscriber /= Nothing
        , property      = (pid, propertyID)
        }
    in
      { priorData | propData = propData }
  _ ->
    extractData c pid properties |> dataMetaData key

dataMetaData : String -> Data -> MetaData
dataMetaData key d =
  { key = key
  , uiLevel = (  Dict.get "ui_level" d
    |> Maybe.withDefault (Json.Encode.int 0)
    |> Json.Decode.decodeValue Json.Decode.int
    |> Result.withDefault 0)
  , description = (  Dict.get "description" d
    |> Maybe.withDefault (Json.Encode.string "")
    |> Json.Decode.decodeValue Json.Decode.string
    |> Result.withDefault "")
  , enabled = (  Dict.get "enabled" d
    |> Maybe.withDefault (Json.Encode.bool True)
    |> Json.Decode.decodeValue Json.Decode.bool
    |> Result.withDefault True)
  , extra = d
  , propData = noPropData
  }

extractData : Contract -> Int -> Properties -> Data
extractData c pid properties = case c of
  Contracts.MapContract d -> Dict.map (\_ value -> extractValue properties pid value) d
  Contracts.Function { data } -> data
  Contracts.Delegate { data } -> data
  Contracts.PropertyKey _ contract -> extractData contract pid properties
  _ -> emptyData


extractValue : Properties -> Int -> Contract -> Json.Encode.Value
extractValue properties pid c = case c of
  Contracts.StringValue x -> Json.Encode.string x
  Contracts.IntValue x    -> Json.Encode.int x
  Contracts.FloatValue x  -> Json.Encode.float x
  Contracts.BoolValue x   -> Json.Encode.bool x
  Contracts.PropertyKey propertyID _ -> let { value } = properties |> fetch pid |> fetch propertyID
    in case value of
      Just (Contracts.SimpleInt x    ) -> Json.Encode.int x
      Just (Contracts.SimpleString x ) -> Json.Encode.string x
      Just (Contracts.SimpleFloat x  ) -> Json.Encode.float x
      Just (Contracts.SimpleBool x   ) -> Json.Encode.bool x
      _ -> Json.Encode.null
  _ -> Json.Encode.null
