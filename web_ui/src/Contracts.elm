module Contracts exposing (..)

import Dict exposing (Dict)
import Json.Decode exposing (Decoder, andThen, bool, decodeString, dict, fail, field, float, int, null, oneOf, string, succeed, list, value)
import Json.Encode
import Json.Encode as JE
import Result
import Set


type alias Data =
    Dict String Json.Encode.Value


type Type
    = TNil
    | TInt
    | TFloat
    | TAtom
    | TString
    | TBool
    | TLiteral String
    | TType Type Data
    | TDelegate
    | TChannel Type
    | TUnion Type Type
    | TList Type
    | TMap Type Type
    | TTuple (List Type)
    | TStruct (Dict String Type)
    | TUnknown String


type Contract
    = StringValue String
    | IntValue Int
    | FloatValue Float
    | BoolValue Bool
    | Delegate DelegateStruct
    | Function FunctionStruct
    | MapContract (Dict String Contract)
    | ListContract (List Contract)
    | PropertyKey PropertyID Contract



-- need better names for those


type alias FunctionStruct =
    { argument : Type
    , name : String
    , retval : Type
    , data : Data
    }


type alias Callee =
    { argument : Type
    , name : String
    , retval : Type
    , pid : Int
    }


makeCallee : Int -> FunctionStruct -> Callee
makeCallee pid { argument, retval, name } =
    { argument = argument
    , name = name
    , retval = retval
    , pid = pid
    }


type alias DelegateStruct =
    { destination : Pid
    , data : Data
    }


type alias Channel =
    Int


type alias Pid =
    Int


type alias PropertyID =
    Int


type alias ContractProperties =
    Dict PropertyID Property


type alias Properties =
    Dict Pid ContractProperties


type alias Property =
    { getter : Maybe FunctionStruct
    , setter : Maybe FunctionStruct
    , subscriber : Maybe FunctionStruct
    , propertyType : Type
    , value : Maybe Value
    }


type Value
    = SimpleInt Int
    | SimpleString String
    | SimpleFloat Float
    | SimpleBool Bool
    | Complex Json.Encode.Value
    | Loading


delegate : Pid -> DelegateStruct
delegate p =
    { destination = p, data = Dict.empty }


equivTypes : Type -> Type -> Bool
equivTypes a b =
    a == b


parseContract : String -> Result String Contract
parseContract s =
    decodeString contractDecoder s
        |> Result.mapError Json.Decode.errorToString


parseType : String -> Result String Type
parseType s =
    decodeString typeDecoder s
        |> Result.mapError Json.Decode.errorToString


contractDecoder : Decoder Contract
contractDecoder =
    oneOf
        [ stringValueDecoder
        , intValueDecoder
        , boolValueDecoder
        , floatValueDecoder
        , objectDecoder
        , Json.Decode.lazy (\_ -> mapDecoder)
        , Json.Decode.lazy (\_ -> listDecoder)
        ]


stringValueDecoder : Decoder Contract
stringValueDecoder =
    Json.Decode.map StringValue string


intValueDecoder : Decoder Contract
intValueDecoder =
    Json.Decode.map IntValue int


boolValueDecoder : Decoder Contract
boolValueDecoder =
    Json.Decode.map BoolValue bool


floatValueDecoder : Decoder Contract
floatValueDecoder =
    Json.Decode.map FloatValue float


objectDecoder : Decoder Contract
objectDecoder =
    field "__type__" string
        |> andThen
            (\t ->
                case t of
                    "delegate" ->
                        delegateDecoder

                    "function" ->
                        functionDecoder

                    _ ->
                        fail <| "object type `" ++ t ++ "' is unknown"
            )


delegateDecoder : Decoder Contract
delegateDecoder =
    Json.Decode.map2 makeDelegate
        (field "destination" int)
        (field "data" dataDecoder)


functionDecoder : Decoder Contract
functionDecoder =
    Json.Decode.map4 makeFunction
        (field "argument" typeDecoder)
        (field "name" string)
        (field "retval" typeDecoder)
        (field "data" dataDecoder)


mapDecoder : Decoder Contract
mapDecoder =
    Json.Decode.map MapContract <|
        dict (Json.Decode.lazy (\_ -> contractDecoder))


listDecoder : Decoder Contract
listDecoder =
    Json.Decode.map ListContract <|
        Json.Decode.list (Json.Decode.lazy (\_ -> contractDecoder))


dataDecoder : Decoder Data
dataDecoder =
    dict Json.Decode.value


makeDelegate : Int -> Data -> Contract
makeDelegate destination data =
    Delegate
        { destination = destination
        , data = data
        }


makeFunction : Type -> String -> Type -> Data -> Contract
makeFunction argument name retval data =
    Function
        { argument = argument
        , name = name
        , retval = retval
        , data = data
        }


channelDecoder : Decoder Channel
channelDecoder =
    field "__type__" string
        |> andThen
            (\t ->
                case t of
                    "channel" ->
                        field "id" int

                    _ ->
                        fail "not a channel"
            )


dataEncoder : Data -> Json.Encode.Value
dataEncoder d =
    Json.Encode.object (Dict.toList d)


delegateEncoder : DelegateStruct -> Json.Encode.Value
delegateEncoder { destination, data } =
    Json.Encode.object
        [ ( "destination", Json.Encode.int destination )
        , ( "data", dataEncoder data )
        , ( "__type__", Json.Encode.string "delegate" )
        ]


channelEncoder : Channel -> Json.Encode.Value
channelEncoder id =
    Json.Encode.object
        [ ( "id", Json.Encode.int id )
        , ( "__type__", Json.Encode.string "channel" )
        ]


typeDecoder : Decoder Type
typeDecoder =
    oneOf
        [ recursiveTypeDecoder
        , tUnknownDecoder
        ]


recursiveTypeDecoder : Decoder Type
recursiveTypeDecoder =
    Json.Decode.lazy <|
        \_ ->
            oneOf
                [ tNilDecoder
                , tSimpleDecoder
                , Json.Decode.lazy <| \_ -> tComplexDecoder
                ]


tNilDecoder : Decoder Type
tNilDecoder =
    null TNil


tSimpleDecoder : Decoder Type
tSimpleDecoder =
    string
        |> andThen
            (\t ->
                case t of
                    "int" ->
                        succeed TInt

                    "bool" ->
                        succeed TBool

                    "float" ->
                        succeed TFloat

                    "string" ->
                        succeed TString

                    "atom" ->
                        succeed TAtom

                    "delegate" ->
                        succeed TDelegate

                    _ ->
                        fail <| "type '" ++ t ++ "' is not simple"
            )


tComplexDecoder : Decoder Type
tComplexDecoder =
    Json.Decode.index 0 string
        |> andThen
            (\t ->
                case t of
                    "struct" ->
                        oneOf [ tStructDecoder, tTupleDecoder ]

                    "map" ->
                        tBinaryDecoder TMap

                    "list" ->
                        tUnaryDecoder TList

                    "union" ->
                        tBinaryDecoder TUnion

                    "channel" ->
                        tUnaryDecoder TChannel

                    "type" ->
                        tTaggedTypeDecoder

                    "literal" ->
                        tLiteralDecoder

                    _ ->
                        fail <| "complex type '" ++ t ++ "' is unknown"
            )


tStructDecoder : Decoder Type
tStructDecoder =
    Json.Decode.index 1 <|
        Json.Decode.map TStruct <|
            Json.Decode.dict recursiveTypeDecoder


tTupleDecoder : Decoder Type
tTupleDecoder =
    Json.Decode.index 1 <|
        Json.Decode.map TTuple <|
            Json.Decode.list recursiveTypeDecoder


tUnaryDecoder : (Type -> Type) -> Decoder Type
tUnaryDecoder f =
    Json.Decode.map f
        (Json.Decode.index 1 recursiveTypeDecoder)


tBinaryDecoder : (Type -> Type -> Type) -> Decoder Type
tBinaryDecoder f =
    Json.Decode.map2 f
        (Json.Decode.index 1 recursiveTypeDecoder)
        (Json.Decode.index 2 recursiveTypeDecoder)


tTaggedTypeDecoder : Decoder Type
tTaggedTypeDecoder =
    Json.Decode.map2 TType
        (Json.Decode.index 1 recursiveTypeDecoder)
        (Json.Decode.index 2 dataDecoder)


tLiteralDecoder : Decoder Type
tLiteralDecoder =
    Json.Decode.map TLiteral
        (Json.Decode.index 1 <|
            Json.Decode.map (\v -> Json.Encode.encode 0 v) Json.Decode.value
        )


tUnknownDecoder : Decoder Type
tUnknownDecoder =
    Json.Decode.map
        (\v -> TUnknown <| Json.Encode.encode 4 v)
        Json.Decode.value


inspectType : Type -> String
inspectType givenType =
    case givenType of
        TStruct d ->
            d
                |> Dict.toList
                |> List.map (\( k, v ) -> k ++ ": " ++ inspectType v)
                |> String.join ", "
                |> (\s -> "{ " ++ s ++ " }")

        TTuple l ->
            l
                |> List.map inspectType
                |> String.join ", "
                |> (\s -> "( " ++ s ++ " )")

        TUnion a b ->
            "(" ++ inspectType a ++ " | " ++ inspectType b ++ ")"

        TType t d ->
            inspectType t ++ inspectData d

        TLiteral json ->
            json

        TChannel t ->
            "channel[" ++ inspectType t ++ "]"

        TList t ->
            "list[" ++ inspectType t ++ "]"

        TMap k v ->
            "map[" ++ inspectType k ++ " → " ++ inspectType v ++ "]"

        TInt ->
            "int"

        TFloat ->
            "float"

        TString ->
            "string"

        TBool ->
            "bool"

        TAtom ->
            "atom"

        TDelegate ->
            "delegate"

        TNil ->
            "nil"

        TUnknown v ->
            v


inspectData : Data -> String
inspectData d =
    d
        |> Dict.toList
        |> List.map (\( k, v ) -> k ++ ": " ++ Json.Encode.encode 0 v)
        |> String.join ", "
        |> (\s -> "<" ++ s ++ ">")


propertify : Contract -> ( Contract, ContractProperties )
propertify contract =
    let
        ( newContract, ( properties, _ ) ) =
            propertify_ contract ( Dict.fromList [], 1 )
    in
    ( newContract, properties )


propertify_ : Contract -> ( ContractProperties, Int ) -> ( Contract, ( ContractProperties, Int ) )
propertify_ contract data =
    case contract of
        ListContract l ->
            let
                ( subcontracts, newData ) =
                    propertifyList l data
            in
            ( ListContract subcontracts, newData )

        MapContract d ->
            let
                ( subcontractList, newData1 ) =
                    propertifyMap (Dict.toList d) data

                subcontract =
                    MapContract <| Dict.fromList subcontractList
            in
            case checkProperty d of
                Just prop ->
                    let
                        ( properties, lastProp ) =
                            newData1

                        newLastProp =
                            lastProp + 1

                        newProperties =
                            Dict.insert newLastProp prop properties
                    in
                    ( PropertyKey newLastProp subcontract, ( newProperties, newLastProp ) )

                Nothing ->
                    ( subcontract, newData1 )

        _ ->
            ( contract, data )


checkProperty : Dict String Contract -> Maybe Property
checkProperty fields =
    let
        getter =
            Dict.get "get" fields |> Maybe.andThen getFunction

        setter =
            Dict.get "set" fields |> Maybe.andThen getFunction

        subscriber =
            Dict.get "subscribe" fields |> Maybe.andThen getFunction
    in
    case getter of
        Nothing ->
            Nothing

        Just { retval } ->
            checkPropertyConsistency <|
                { getter = getter
                , setter = setter
                , subscriber = subscriber
                , propertyType = retval
                , value = Nothing
                }


checkPropertyConsistency : Property -> Maybe Property
checkPropertyConsistency prop =
    let
        getterType =
            Maybe.map (\f -> f.retval) prop.getter

        setterType =
            Maybe.map (\f -> f.argument) prop.setter

        subscriberType =
            Maybe.andThen (\f -> unChannel f.retval) prop.subscriber

        equiv =
            maybeEquivTypes getterType setterType && maybeEquivTypes getterType subscriberType
    in
    case equiv of
        True ->
            Just prop

        False ->
            Nothing

numericContract : Contract -> Maybe Float
numericContract c =
    case c of
        FloatValue f ->
            Just f

        IntValue i ->
            Just <| toFloat i

        _ ->
            Nothing


numericValue : Json.Encode.Value -> Maybe Float
numericValue v =
    Json.Decode.decodeValue Json.Decode.float v
        |> Result.toMaybe

intValue : Json.Encode.Value -> Maybe Int
intValue v =
    Json.Decode.decodeValue Json.Decode.int v
        |> Result.toMaybe

floatListValue : Json.Encode.Value -> Maybe (List Float)
floatListValue v =
    Json.Decode.decodeValue (Json.Decode.list Json.Decode.float) v
        |> Result.toMaybe


getFunction : Contract -> Maybe FunctionStruct
getFunction c =
    case c of
        Function f ->
            Just f

        _ ->
            Nothing


maybeEquivTypes : Maybe Type -> Maybe Type -> Bool
maybeEquivTypes t1 t2 =
    case ( t1, t2 ) of
        ( Nothing, _ ) ->
            True

        ( _, Nothing ) ->
            True

        ( Just it1, Just it2 ) ->
            equivTypes it1 it2


unChannel : Type -> Maybe Type
unChannel t =
    case t of
        -- this needs to be smarter
        TChannel t2 ->
            Just t2

        _ ->
            Nothing


propertifyList : List Contract -> ( ContractProperties, Int ) -> ( List Contract, ( ContractProperties, Int ) )
propertifyList l data =
    case l of
        [] ->
            ( [], data )

        h :: t ->
            let
                ( newTail, newData1 ) =
                    propertifyList t data
            in
            let
                ( contract, newData2 ) =
                    propertify_ h newData1
            in
            ( contract :: newTail, newData2 )


propertifyMap : List ( String, Contract ) -> ( ContractProperties, Int ) -> ( List ( String, Contract ), ( ContractProperties, Int ) )
propertifyMap l data =
    case l of
        [] ->
            ( [], data )

        ( hk, hv ) :: t ->
            let
                ( newTail, newData1 ) =
                    propertifyMap t data
            in
            let
                ( contract, newData2 ) =
                    propertify_ hv newData1
            in
            ( ( hk, contract ) :: newTail, newData2 )


-- todo: make those work on deep types


getTypeFields : Type -> Dict String Json.Encode.Value
getTypeFields t =
    case t of
        TType _ data ->
            data

        _ ->
            Dict.empty


stripType : Type -> Type
stripType t =
    case t of
        TType t1 data ->
            t1

        t2 ->
            t2



-- utils


fetch : comparable -> Dict comparable v -> v
fetch k d =
    case Dict.get k d of
        Just v ->
            v

        Nothing ->
            Debug.todo "the author of this page is a moron"


firstJust : List (Maybe a) -> Maybe a
firstJust l =
    case l of
        [] ->
            Nothing

        (Just x) :: _ ->
            Just x

        Nothing :: t ->
            firstJust t


emptyData : Data
emptyData =
    Dict.empty

type TypeError
    = NoError
    | CannotCoerce JE.Value Type
    | NotSupported String
    | KeysDiffer (List String) (List String)

typeErrorToString : TypeError -> String
typeErrorToString err = case err of
    NoError          -> "no error"
    CannotCoerce v t -> "cannot coerce '" ++ (JE.encode 0 v) ++ "' to type " ++ (inspectType t)
    NotSupported s   -> s
    KeysDiffer a b   -> "keys differ: " ++ (String.join "," a) ++ " ≠ " ++ (String.join "," b)

typeCheck : Type -> Json.Encode.Value -> TypeError
typeCheck t v = Json.Decode.decodeValue (typeChecker t) v
    |> Result.withDefault (CannotCoerce v t)

typeChecker : Type -> Decoder TypeError
typeChecker t_ =
    let
        ok = andThen (\_ -> succeed NoError)
        reduce = andThen (succeed << (List.foldl typeErrorPlus NoError))
    in case t_ of
        TNil        -> null     NoError
        TInt        -> int      |> ok
        TFloat      -> float    |> ok
        TAtom       -> string   |> ok
        TString     -> string   |> ok
        TBool       -> bool     |> ok
        TLiteral _  -> succeed  <| NotSupported "literal types not supported yet"
        TType t _   -> typeChecker t
        TDelegate   -> succeed  <| NotSupported "delegate types not supported yet"
        TChannel _  -> succeed  <| NotSupported "channel types not supported yet"
        TUnion a b  -> oneOf [ typeChecker a, typeChecker b ]
        TList t     -> list (typeChecker t) |> reduce
        TMap TString t -> dict (typeChecker t) |> andThen (succeed << Dict.values) |> reduce
        TMap _ _    -> succeed  <| NotSupported "maps with non-string keys not supported yet"
        TTuple _    -> succeed  <| NotSupported "tuples not supported yet"
        TStruct d   -> dict value |> andThen (structChecker d)
        _           -> value    |> andThen (\v -> succeed <| CannotCoerce v t_)

structChecker : Dict String Type -> Dict String JE.Value -> Decoder TypeError
structChecker td vd = succeed <| case sameKeys td vd of
    False -> KeysDiffer (Dict.keys td) (Dict.keys vd)
    True  -> Dict.toList td
        |> List.map (\(k, t) -> typeCheck t (fetch k vd))
        |> List.foldl typeErrorPlus NoError

typeErrorPlus : TypeError -> TypeError -> TypeError
typeErrorPlus e1 e2 = case (e1, e2) of
    (NoError, NoError) -> NoError
    (NoError, _      ) -> e2
    (_      , _      ) -> e1

sameKeys : Dict comparable v1 -> Dict comparable v2 -> Bool
sameKeys a b = (a |> Dict.keys |> Set.fromList) == (b |> Dict.keys |> Set.fromList)
