module Ui.MetaData exposing (..)

import Contracts exposing (Contract, Children, Data, ContractProperties, Property, emptyData, fetch, getTypeFields, Value(..))
import Dict exposing (Dict)
import Json.Decode
import Json.Encode


type alias MetaData =
    { key : String
    , property : Maybe Property
    , description : String
    , enabled : Bool
    , uiTags : UiTags
    , extra : Data
    , valueMeta : ValueMeta
    }

type alias UiTags = Dict String UiTagValue

type UiTagValue
    = Tag
    | StringTag String
    | NumberTag Float


noMetaData : MetaData
noMetaData =
    { key = ""
    , description = ""
    , enabled = True
    , extra = emptyData
    , uiTags = Dict.empty
    , property = Nothing
    , valueMeta = emptyValueMeta
    }


getMetaData : String -> Contract -> ContractProperties -> MetaData
getMetaData key c properties =
    case c of
        Contracts.PropertyKey prop _ ->
            let
                priorData =
                    extractData c properties |> dataMetaData key
            in
                { priorData | property = Just prop }

        _ ->
            extractData c properties |> dataMetaData key


dataMetaData : String -> Data -> MetaData
dataMetaData key d =
    { key = key
    , description =
        Dict.get "description" d
            |> Maybe.withDefault (Json.Encode.string "")
            |> Json.Decode.decodeValue Json.Decode.string
            |> Result.withDefault ""
    , enabled =
        Dict.get "enabled" d
            |> Maybe.withDefault (Json.Encode.bool True)
            |> Json.Decode.decodeValue Json.Decode.bool
            |> Result.withDefault True
    , uiTags =
        Dict.get "ui_tags" d
            |> Maybe.withDefault (Json.Encode.string "")
            |> Json.Decode.decodeValue Json.Decode.string
            |> Result.withDefault ""
            |> String.split ","
            |> List.filter (\x -> x /= "")
            |> List.map parseUiTag
            |> Dict.fromList

    , extra = d
    , valueMeta =
        { min = Dict.get "min" d |> Maybe.andThen (parseValue Json.Decode.float)
        , max = Dict.get "max" d |> Maybe.andThen (parseValue Json.Decode.float)
        , stops = Dict.get "stops" d
            |> Maybe.andThen ((\x -> parseValue (Json.Decode.dict Json.Decode.string) x))
            |> Maybe.map Dict.toList
            |> Maybe.map (List.map (\(k, v) -> (String.toFloat k |> Maybe.withDefault 0, v)))
            |> Maybe.map List.sort
            |> Maybe.map List.reverse
            |> Maybe.withDefault []
        }
    , property = Nothing
    }

parseValue : Json.Decode.Decoder v -> Json.Decode.Value -> Maybe v
parseValue dec v =
    Json.Decode.decodeValue dec v
        |> Result.toMaybe

extractData : Contract -> ContractProperties -> Data
extractData c properties =
    case c of
        Contracts.MapContract d -> extractDataDict d properties

        Contracts.Function _ subcontract ->
            extractDataDict subcontract properties

        Contracts.PropertyKey prop subcontract ->
            let
                contractData = extractDataDict subcontract properties
                typeData = getTypeFields prop.propertyType
            in
                Dict.union contractData typeData

        _ ->
            emptyData

extractDataDict : Children -> ContractProperties -> Data
extractDataDict d properties = Dict.map (\_ value -> extractValue properties value) d

extractValue : ContractProperties -> Contract -> Json.Encode.Value
extractValue properties c =
    case c of
        Contracts.Constant (SimpleString x) ->
            Json.Encode.string x

        Contracts.Constant (SimpleInt x) ->
            Json.Encode.int x

        Contracts.Constant (SimpleFloat x) ->
            Json.Encode.float x

        Contracts.Constant (SimpleBool x) ->
            Json.Encode.bool x

        Contracts.PropertyKey { path } _ ->
            let
                value =
                    properties |> fetch path
            in
            case value of
                Contracts.SimpleInt x ->
                    Json.Encode.int x

                Contracts.SimpleString x ->
                    Json.Encode.string x

                Contracts.SimpleFloat x ->
                    Json.Encode.float x

                Contracts.SimpleBool x ->
                    Json.Encode.bool x

                _ ->
                    Json.Encode.null

        Contracts.MapContract subcontracts ->
            Json.Encode.dict (\k -> k) (extractValue properties) subcontracts

        _ -> Json.Encode.null

parseUiTag : String -> (String, UiTagValue)
parseUiTag s = case splitUpTo 2 ":" s of
    [k, v] -> (k, parseUiTagValue v)
    _ -> (s, Tag)

parseUiTagValue : String -> UiTagValue
parseUiTagValue s = case String.toFloat s of
    Just  f -> NumberTag f
    Nothing -> StringTag s

uiTagsToStrings : UiTags -> List String
uiTagsToStrings tags = tags |> Dict.toList |> List.map uiTagToString

uiTagToString : (String, UiTagValue) -> String
uiTagToString (k, v) = case v of
    Tag         -> k
    StringTag s -> k ++ ":" ++ s
    NumberTag n -> k ++ ":" ++ (String.fromFloat n)

getTag : String -> UiTags -> Maybe UiTagValue
getTag k m = Dict.get k m

getStringTag : String -> UiTags -> Maybe String
getStringTag k m = getTag k m |> Maybe.andThen (\tag -> case tag of
    StringTag s -> Just s
    _           -> Nothing)

getFloatTag : String -> UiTags -> Maybe Float
getFloatTag k m = getTag k m |> Maybe.andThen (\tag -> case tag of
    NumberTag n -> Just n
    _           -> Nothing)

getIntTag : String -> UiTags -> Maybe Int
getIntTag k m = getTag k m |> Maybe.andThen (\tag -> case tag of
    NumberTag n -> Just <| round n
    _           -> Nothing)

getBoolTag : String -> UiTags -> Bool
getBoolTag s t = getTag s t |> Maybe.map (\_ -> True) |> Maybe.withDefault False

uiLevel : MetaData -> Float
uiLevel m = getFloatTag "level" m.uiTags |> Maybe.withDefault
    (if List.member m.key ["enabled", "description", "ui_tags", "get", "set", "subscribe", "stops"] then
        1
     else
        0
    )

splitUpTo : Int -> String -> String -> List String
splitUpTo n sep s =
    let
        parts = String.split sep s
    in let
        left  = List.take (n - 1) parts
        right = List.drop (n - 1) parts
    in
        left ++ (case right of
            [] -> []
            _  -> [String.join sep right]
        )

type alias ValueMeta =
    { min : Maybe Float
    , max : Maybe Float
    , stops : List (Float, String)
    }

emptyValueMeta : ValueMeta
emptyValueMeta =
    { min  = Nothing
    , max  = Nothing
    , stops  = []
    }

hasSetter : MetaData -> Bool
hasSetter { property } = case property of
    Nothing -> False
    Just { setter } -> case setter of
        Just _ -> True
        _      -> False
