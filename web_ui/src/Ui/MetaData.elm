module Ui.MetaData exposing (..)

import Contracts exposing (Contract, Data, Pid, Properties, PropertyID, emptyData, fetch, getTypeFields)
import Dict exposing (Dict)
import Json.Decode as JD
import Json.Encode as JE


type alias MetaData =
    { key : String
    , propData : PropData
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


type alias PropData =
    { hasGetter : Bool
    , hasSetter : Bool
    , hasSubscriber : Bool
    , property : ( Pid, PropertyID )
    }


noMetaData : MetaData
noMetaData =
    { key = ""
    , description = ""
    , enabled = True
    , extra = emptyData
    , uiTags = Dict.empty
    , propData = noPropData
    , valueMeta = emptyValueMeta
    }


noPropData : PropData
noPropData =
    { hasGetter = False
    , hasSetter = False
    , hasSubscriber = False
    , property = ( -1, -1 )
    }


getMetaData : String -> Contract -> Pid -> Properties -> MetaData
getMetaData key c pid properties =
    case c of
        Contracts.PropertyKey propertyID _ ->
            let
                { getter, setter, subscriber } =
                    properties |> fetch pid |> fetch propertyID

                priorData =
                    extractData c pid properties |> dataMetaData key
            in
            let
                propData =
                    { hasGetter = getter /= Nothing
                    , hasSetter = setter /= Nothing
                    , hasSubscriber = subscriber /= Nothing
                    , property = ( pid, propertyID )
                    }
            in
            { priorData | propData = propData }

        _ ->
            extractData c pid properties |> dataMetaData key


dataMetaData : String -> Data -> MetaData
dataMetaData key d =
    { key = key
    , description =
        Dict.get "description" d
            |> Maybe.withDefault (JE.string "")
            |> JD.decodeValue JD.string
            |> Result.withDefault ""
    , enabled =
        Dict.get "enabled" d
            |> Maybe.withDefault (JE.bool True)
            |> JD.decodeValue JD.bool
            |> Result.withDefault True
    , uiTags =
        Dict.get "ui_tags" d
            |> Maybe.withDefault (JE.string "")
            |> JD.decodeValue JD.string
            |> Result.withDefault ""
            |> String.split ","
            |> List.filter (\x -> x /= "")
            |> List.map parseUiTag
            |> Dict.fromList

    , extra = d
    , valueMeta =
        { min = Dict.get "min" d |> Maybe.andThen (parseValue JD.float)
        , max = Dict.get "max" d |> Maybe.andThen (parseValue JD.float)
        , stops = Dict.get "stops" d
            |> Maybe.andThen (parseValue (JD.dict JD.string))
            |> Maybe.map Dict.toList
            |> Maybe.map (List.map (\(k, v) -> (String.toFloat k |> Maybe.withDefault 0, v)))
            |> Maybe.map List.sort
            |> Maybe.map List.reverse
            |> Maybe.withDefault []
        , oneOf = Dict.get "one_of" d
            |> Maybe.andThen (parseValue (JD.list JD.value))
        }
    , propData = noPropData
    }

parseValue : JD.Decoder v -> JD.Value -> Maybe v
parseValue dec v =
    JD.decodeValue dec v
        |> Result.toMaybe

extractData : Contract -> Int -> Properties -> Data
extractData c pid properties =
    case c of
        Contracts.MapContract d ->
            Dict.map (\_ value -> extractValue properties pid value) d

        Contracts.Function { data } ->
            data

        Contracts.Delegate { data } ->
            data

        Contracts.PropertyKey propertyID contract ->
            let
                prop = properties |> fetch pid |> fetch propertyID
                contractData = extractData contract pid properties
                typeData = getTypeFields prop.propertyType
            in
                Dict.union contractData typeData

        _ ->
            emptyData


extractValue : Properties -> Int -> Contract -> JE.Value
extractValue properties pid c =
    case c of
        Contracts.StringValue x ->
            JE.string x

        Contracts.IntValue x ->
            JE.int x

        Contracts.FloatValue x ->
            JE.float x

        Contracts.BoolValue x ->
            JE.bool x

        Contracts.PropertyKey propertyID _ ->
            let
                { value } =
                    properties |> fetch pid |> fetch propertyID
            in
            case value of
                Just (Contracts.SimpleInt x) ->
                    JE.int x

                Just (Contracts.SimpleString x) ->
                    JE.string x

                Just (Contracts.SimpleFloat x) ->
                    JE.float x

                Just (Contracts.SimpleBool x) ->
                    JE.bool x

                _ ->
                    JE.null

        Contracts.ListContract subcontracts ->
            JE.list (extractValue properties pid) subcontracts

        Contracts.MapContract subcontracts ->
            JE.dict (\k -> k) (extractValue properties pid) subcontracts

        _ -> JE.null

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
    (if List.member m.key ["enabled", "description", "ui_tags", "get", "set", "subscribe", "stops", "one_of"] then
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
    , oneOf : Maybe Choices
    }

emptyValueMeta : ValueMeta
emptyValueMeta =
    { min  = Nothing
    , max  = Nothing
    , stops  = []
    , oneOf = Nothing
    }

type alias Choices = List (JE.Value)
