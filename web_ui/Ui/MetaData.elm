module Ui.MetaData exposing(getMetaData, MetaData, noMetaData)

import Contracts
import Contracts exposing (Contract, Properties, emptyData, Data, fetch)

import Dict
import Dict exposing(Dict)

import Json.Encode
import Json.Decode

type alias MetaData =
  { uiLevel     : Int
  , description : String
  , enabled     : Bool
  , extra       : Data
  }

noMetaData : String -> MetaData
noMetaData key = { uiLevel = 0, description = key, enabled = True, extra = emptyData }

getMetaData : String -> Contract -> Int -> Properties -> MetaData
getMetaData key c pid properties = case c of
  Contracts.StringValue _ -> case key of
    "description" -> { uiLevel = 1, description = key, enabled = True, extra = emptyData }
    _             -> noMetaData key
  Contracts.BoolValue _ ->   case key of
    "enabled"     -> { uiLevel = 1, description = key, enabled = True, extra = emptyData }
    _             -> noMetaData key
  Contracts.IntValue _ ->    case key of
    "ui_level"    -> { uiLevel = 1, description = key, enabled = True, extra = emptyData }
    _             -> noMetaData key
  _ ->
    extractData c pid properties |> dataMetaData key

dataMetaData : String -> Data -> MetaData
dataMetaData defaultDescription d = MetaData
  (  Dict.get "ui_level" d
  |> Maybe.withDefault (Json.Encode.int 0)
  |> Json.Decode.decodeValue Json.Decode.int
  |> Result.withDefault 0)
  (  Dict.get "description" d
  |> Maybe.withDefault (Json.Encode.string defaultDescription)
  |> Json.Decode.decodeValue Json.Decode.string
  |> Result.withDefault "")
  (  Dict.get "enabled" d
  |> Maybe.withDefault (Json.Encode.bool True)
  |> Json.Decode.decodeValue Json.Decode.bool
  |> Result.withDefault True)
  d

extractData : Contract -> Int -> Properties -> Data
extractData c pid properties = case c of
  Contracts.MapContract d -> Dict.map (\_ value -> extractValue properties pid value) d
  Contracts.Function { data } -> data
  Contracts.Delegate { data } -> data
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
      Just (Contracts.Complex v) -> v
      Nothing -> Json.Encode.null
  _ -> Json.Encode.null
