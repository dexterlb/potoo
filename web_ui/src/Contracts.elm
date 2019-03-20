module Contracts exposing (..)

import Dict exposing (Dict)
import Json.Decode exposing (Decoder, andThen, bool, decodeString, dict, fail, field, float, int, null, oneOf, string, succeed, list, value)
import Json.Encode
import Json.Encode as JE
import Result
import Set


type alias Data =
    Dict String Json.Encode.Value


type alias Type = { t: TypeDescr, meta: Data }

type TypeDescr
    = TVoid
    | TNil
    | TInt
    | TFloat
    | TString
    | TBool
    | TLiteral JE.Value
    | TUnion (List Type)
    | TMap Type Type
    | TList Type
    | TTuple (List Type)
    | TStruct (Dict String Type)
    | TUnknown String


type Contract
    = Constant Value
    | MapContract (Dict String Contract)
    | Function Callee Contract
    | PropertyKey Property Contract



-- need better names for those

type alias Topic = String

type alias Callee =
    { argument : Type
    , path : Topic
    , retval : Type
    }


type alias PropertyID =
    Topic


type alias ContractProperties =
    Dict PropertyID Value


type alias Property =
    { setter : Maybe Callee
    , propertyType : Type
    , path : PropertyID
    }


type Value
    = SimpleInt Int
    | SimpleString String
    | SimpleFloat Float
    | SimpleBool Bool
    | Complex Json.Encode.Value
    | Loading


equivTypes : Type -> Type -> Bool
equivTypes a b =
    a == b  -- fixme


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
        ]


stringValueDecoder : Decoder Contract
stringValueDecoder =
    Json.Decode.map (Constant << SimpleString) string


intValueDecoder : Decoder Contract
intValueDecoder =
    Json.Decode.map (Constant << SimpleInt) int


boolValueDecoder : Decoder Contract
boolValueDecoder =
    Json.Decode.map (Constant << SimpleBool) bool


floatValueDecoder : Decoder Contract
floatValueDecoder =
    Json.Decode.map (Constant << SimpleFloat) float


objectDecoder : Decoder Contract
objectDecoder =
    field "_t" string
        |> andThen
            (\t ->
                case t of
                    "value" ->
                        propertyDecoder

                    "callable" ->
                        functionDecoder

                    _ ->
                        fail <| "object type `" ++ t ++ "' is unknown"
            )


propertyDecoder : Decoder Contract
propertyDecoder =
    Json.Decode.map2 makeProperty
        (field "type" typeDecoder)
        (field "subcontract" contractDecoder)

functionDecoder : Decoder Contract
functionDecoder =
    Json.Decode.map3 makeFunction
        (field "argument" typeDecoder)
        (field "retval" typeDecoder)
        (field "subcontract" contractDecoder)


mapDecoder : Decoder Contract
mapDecoder =
    Json.Decode.map MapContract <|
        dict (Json.Decode.lazy (\_ -> contractDecoder))


dataDecoder : Decoder Data
dataDecoder =
    dict Json.Decode.value


makeProperty : Type -> Contract -> Contract
makeProperty t subcontract = PropertyKey
    { path = "", propertyType = t, setter = Nothing }
    subcontract

makeFunction : Type -> Type -> Contract -> Contract
makeFunction argument retval subcontract =
    Function
        { argument = argument
        , path = ""
        , retval = retval
        }
        subcontract


dataEncoder : Data -> Json.Encode.Value
dataEncoder d =
    Json.Encode.object (Dict.toList d)



typeDecoder : Decoder Type
typeDecoder =
    (oneOf
        [ Json.Decode.field "_meta" dataDecoder
        , Json.Decode.succeed Dict.empty ]
    ) |> andThen
        (\meta ->
            Json.Decode.map (\t ->
                { meta = meta, t = t }
            ) typeDescrDecoder
        )

recursiveTypeDecoder : Decoder Type
recursiveTypeDecoder = Json.Decode.lazy <| \_ -> typeDecoder

typeDescrDecoder : Decoder TypeDescr
typeDescrDecoder =
    oneOf
        [ recursiveTypeDescrDecoder
        , tUnknownDecoder
        ]


recursiveTypeDescrDecoder : Decoder TypeDescr
recursiveTypeDescrDecoder =
    Json.Decode.lazy <|
        \_ ->
            oneOf
                [ tBasicDecoder
                , Json.Decode.lazy <| \_ -> tComplexDecoder
                ]


tNilDecoder : Decoder TypeDescr
tNilDecoder =
    null TNil


tBasicDecoder : Decoder TypeDescr
tBasicDecoder =
    string
        |> andThen
            (\name ->
                case name of
                    "void" ->
                        succeed TVoid

                    "null" ->
                        succeed TNil

                    "int" ->
                        succeed TInt

                    "bool" ->
                        succeed TBool

                    "float" ->
                        succeed TFloat

                    "string" ->
                        succeed TString

                    _ ->
                        fail <| "type '" ++ name ++ "' is not a basic type"
            )


tComplexDecoder : Decoder TypeDescr
tComplexDecoder =
    Json.Decode.field "_t" string
        |> andThen
            (\t ->
                case t of
                    "type-basic" ->
                        Json.Decode.field "name" tBasicDecoder

                    "type-literal" ->
                        tLiteralDecoder

                    "type-map" ->
                        tMapDecoder

                    "type-union" ->
                        tUnionDecoder

                    "type-list" ->
                        tListDecoder

                    "type-tuple" ->
                        tTupleDecoder

                    "type-struct" ->
                        tStructDecoder

                    _ ->
                        fail <| "complex type '" ++ t ++ "' is unknown"
            )


tStructDecoder : Decoder TypeDescr
tStructDecoder =
    Json.Decode.field "fields" <|
        Json.Decode.map TStruct <|
            Json.Decode.dict recursiveTypeDecoder


tTupleDecoder : Decoder TypeDescr
tTupleDecoder =
    Json.Decode.field "fields" <|
        Json.Decode.map TTuple <|
            Json.Decode.list recursiveTypeDecoder


tListDecoder : Decoder TypeDescr
tListDecoder =
    Json.Decode.map TList
        (Json.Decode.field "value" recursiveTypeDecoder)


tMapDecoder : Decoder TypeDescr
tMapDecoder =
    Json.Decode.map2 TMap
        (Json.Decode.field "key" recursiveTypeDecoder)
        (Json.Decode.field "value" recursiveTypeDecoder)


tLiteralDecoder : Decoder TypeDescr
tLiteralDecoder =
    Json.Decode.map TLiteral
        (Json.Decode.field "value" <| Json.Decode.value
        )

tUnionDecoder : Decoder TypeDescr
tUnionDecoder =
    Json.Decode.map TUnion
        (Json.Decode.field "alts" <| Json.Decode.list
        <| recursiveTypeDecoder)


tUnknownDecoder : Decoder TypeDescr
tUnknownDecoder =
    Json.Decode.map
        (\v -> TUnknown <| Json.Encode.encode 4 v)
        Json.Decode.value


inspectType : Type -> String
inspectType { t, meta } = inspectTypeDescr t ++ inspectData meta

inspectTypeDescr : TypeDescr -> String
inspectTypeDescr givenType =
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

        TUnion l ->
            "(" ++ (String.join " | " (List.map inspectType l)) ++ ")"

        TLiteral json ->
            JE.encode 0 json

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

        TNil ->
            "nil"

        TVoid ->
            "void"

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
        ( newContract, properties ) =
            propertify_ "" contract ( Dict.fromList [] )
    in
        ( newContract, properties )


propertify_ : Topic -> Contract -> ContractProperties -> ( Contract, ContractProperties )
propertify_ path contract properties =
    case contract of
        MapContract d ->
            let
                ( subcontractList, newProperties1 ) =
                    propertifyMap path (Dict.toList d) properties

                subcontract =
                    MapContract <| Dict.fromList subcontractList
            in
                ( subcontract, newProperties1 )

        Function f subcontract ->
            let
                ( newSubcontract, newProperties ) = propertify_ path subcontract properties
            in
                ( Function { f | path = path } newSubcontract, newProperties )


        PropertyKey prop subcontract ->
            let
                (newSubcontract, newProperties) = propertify_ path subcontract properties
                newerProperties =
                    Dict.insert path Loading newProperties
            in
                ( PropertyKey
                    { prop | path = path, setter = makeSetter prop newSubcontract }
                    newSubcontract
                , newProperties )

        Constant c -> ( Constant c, properties )



makeSetter : Property -> Contract -> Maybe Callee
makeSetter { propertyType } subcontract = case subcontract of
    MapContract d ->
        Dict.get "set" d |> Maybe.andThen getFunction
        |> Maybe.andThen (checkSetterType propertyType)
    _ -> Nothing


checkSetterType : Type -> Callee -> Maybe Callee
checkSetterType t f = case equivTypes f.argument t of
    True  -> Just f
    False -> Nothing

numericContract : Contract -> Maybe Float
numericContract c =
    case c of
        Constant (SimpleFloat f) ->
            Just f

        Constant (SimpleInt i) ->
            Just <| toFloat i

        _ ->
            Nothing


getFunction : Contract -> Maybe Callee
getFunction c =
    case c of
        Function f _ ->
            Just f

        _ ->
            Nothing


propertifyMap : Topic -> List ( String, Contract ) -> ContractProperties -> ( List ( String, Contract ), ContractProperties )
propertifyMap path l data =
    case l of
        [] ->
            ( [], data )

        ( hk, hv ) :: t ->
            let
                ( newTail, newData1 ) =
                    propertifyMap path t data
            in
            let
                ( contract, newData2 ) =
                    propertify_ (path ++ "/" ++ hk) hv newData1
            in
            ( ( hk, contract ) :: newTail, newData2 )


-- todo: make those work on deep types

getTypeFields : Type -> Dict String Json.Encode.Value
getTypeFields { meta } = meta



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
typeChecker typ =  -- todo: use the metadata
    let
        ok = andThen (\_ -> succeed NoError)
        reduce = andThen (succeed << (List.foldl typeErrorPlus NoError))
        { t } = typ
    in case t of
        TNil        -> null     NoError
        TInt        -> int      |> ok
        TFloat      -> float    |> ok
        TString     -> string   |> ok
        TBool       -> bool     |> ok
        TLiteral _  -> succeed  <| NotSupported "literal types not supported yet"
        TUnion l    -> oneOf    <| List.map typeChecker l
        TList t_     -> list (typeChecker t_) |> reduce
        TMap keyType t_ -> case keyType.t of
            TString -> dict (typeChecker t_) |> andThen (succeed << Dict.values) |> reduce
            _       -> succeed  <| NotSupported "maps with non-string keys not supported yet"
        TTuple _    -> succeed  <| NotSupported "tuples not supported yet"
        TStruct d   -> dict value |> andThen (structChecker d)
        _           -> value    |> andThen (\v -> succeed <| CannotCoerce v typ)

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
