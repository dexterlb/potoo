module Contracts exposing (..)
import Dict exposing (Dict)

import Json.Decode exposing (Decoder, decodeString, string, int, float, oneOf, andThen, field, fail, dict, null, succeed)
import Json.Encode

import Result

type alias Data = Dict String String

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
  | Delegate DelegateStruct
  | Function FunctionStruct
  | MapContract (Dict String Contract)
  | ListContract (List Contract)
  | PropertyKey PropertyID Contract

-- need better names for those
type alias FunctionStruct = {
    argument: Type,
    name: String,
    retval: Type,
    data: Data
  }

type alias DelegateStruct = {
    destination : Pid,
    data: Data
  }

type alias Pid = Int
type alias PropertyID = Int
type alias ContractProperties = Dict PropertyID Property
type alias Properties = Dict Pid ContractProperties

type alias Property = {
    getter:         Maybe FunctionStruct,
    setter:         Maybe FunctionStruct,
    subscriber:     Maybe FunctionStruct,
    propertyType:   Type,
    value:          Maybe PropertyValue
  }

type PropertyValue
  = IntProperty Int
  | UnknownProperty Json.Encode.Value

type VisualContract
  = VStringValue String
  | VIntValue Int
  | VFloatValue Float
  | VConnectedDelegate {
    contract: VisualContract,
    destination: Int,
    data: Data
  }
  | VBrokenDelegate {
    destination: Int,
    data: Data
  }
  | VFunction {
    argument: Type,
    name: String,
    retval: Type,
    data: Data,
    pid: Int
  }
  | VMapContract (Dict String VisualContract)
  | VListContract (List VisualContract)
  | VProperty {
    pid: Int,
    propertyID: Int,
    value: Property,
    contract: VisualContract
  }

equivTypes : Type -> Type -> Bool
equivTypes a b = a == b

parseContract : String -> Result String Contract
parseContract s = decodeString contractDecoder s

parseType : String -> Result String Type
parseType s = decodeString typeDecoder s

contractDecoder : Decoder Contract
contractDecoder = oneOf [
    stringValueDecoder,
    intValueDecoder,
    floatValueDecoder,
    objectDecoder,
    Json.Decode.lazy (\_ -> mapDecoder),
    Json.Decode.lazy (\_ -> listDecoder)
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
delegateDecoder = Json.Decode.map2 makeDelegate 
  (field "destination" int)
  (field "data" dataDecoder)

functionDecoder : Decoder Contract
functionDecoder = Json.Decode.map4 makeFunction
  (field "argument" typeDecoder)
  (field "name" string)
  (field "retval" typeDecoder)
  (field "data" dataDecoder)

mapDecoder : Decoder Contract
mapDecoder = Json.Decode.map MapContract <|
  dict (Json.Decode.lazy (\_ -> contractDecoder))

listDecoder : Decoder Contract
listDecoder = Json.Decode.map ListContract <|
  Json.Decode.list (Json.Decode.lazy (\_ -> contractDecoder))

dataDecoder : Decoder Data
dataDecoder = dict string

makeDelegate : Int -> Data -> Contract
makeDelegate destination data = Delegate {
    destination = destination,
    data = data
  }

makeFunction : Type -> String -> Type -> Data -> Contract
makeFunction argument name retval data = Function {
    argument = argument,
    name = name,
    retval = retval,
    data = data
  }

typeDecoder : Decoder Type
typeDecoder = oneOf [
    recursiveTypeDecoder,
    tUnknownDecoder
  ]

recursiveTypeDecoder : Decoder Type
recursiveTypeDecoder = Json.Decode.lazy <| \_ -> oneOf [
    tNilDecoder,
    tSimpleDecoder,
    Json.Decode.lazy <| \_ -> tComplexDecoder
  ]

tNilDecoder : Decoder Type
tNilDecoder = (null TNil)

tSimpleDecoder : Decoder Type
tSimpleDecoder = string
  |> andThen (\t -> case t of
    "int" -> succeed TInt
    "bool" -> succeed TBool
    "float" -> succeed TFloat
    "string" -> succeed TString
    "atom" -> succeed TAtom
    "delegate" -> succeed TDelegate
    _ -> fail <| "type '" ++ t ++ "' is not simple")

tComplexDecoder : Decoder Type
tComplexDecoder = Json.Decode.index 0 string
  |> andThen (\t -> case t of
    "struct"  -> oneOf [tStructDecoder, tTupleDecoder]
    "map"     -> tBinaryDecoder TMap
    "list"    -> tUnaryDecoder  TList
    "union"   -> tBinaryDecoder TUnion
    "channel" -> tUnaryDecoder  TChannel
    "type"    -> tTaggedTypeDecoder
    "literal" -> tLiteralDecoder
    _ -> fail <| "complex type '" ++ t ++ "' is unknown"
  )

tStructDecoder : Decoder Type
tStructDecoder = Json.Decode.index 1 <| Json.Decode.map TStruct <|
  Json.Decode.dict recursiveTypeDecoder

tTupleDecoder : Decoder Type
tTupleDecoder = Json.Decode.index 1 <| Json.Decode.map TTuple <|
  Json.Decode.list recursiveTypeDecoder

tUnaryDecoder : (Type -> Type) -> Decoder Type
tUnaryDecoder f = Json.Decode.map f
  (Json.Decode.index 1 recursiveTypeDecoder)

tBinaryDecoder : (Type -> Type -> Type) -> Decoder Type
tBinaryDecoder f = Json.Decode.map2 f
  (Json.Decode.index 1 recursiveTypeDecoder)
  (Json.Decode.index 2 recursiveTypeDecoder)

tTaggedTypeDecoder : Decoder Type
tTaggedTypeDecoder = Json.Decode.map2 TType
  (Json.Decode.index 1 recursiveTypeDecoder)
  (Json.Decode.index 2 dataDecoder)

tLiteralDecoder : Decoder Type
tLiteralDecoder = Json.Decode.map TLiteral
  (Json.Decode.index 1 <|
    Json.Decode.map (\v -> Json.Encode.encode 0 v) Json.Decode.value
  )


tUnknownDecoder : Decoder Type
tUnknownDecoder = Json.Decode.map 
  (\v -> TUnknown <| Json.Encode.encode 4 v)
  Json.Decode.value

toVisual : Int -> Dict Int Contract -> Properties -> VisualContract
toVisual pid contracts properties  = case Dict.get pid contracts of
  (Just contract) -> toVisual_ contract pid contracts properties
  Nothing -> VBrokenDelegate {
      destination = pid,
      data = Dict.fromList []
    }

toVisual_ : Contract -> Int -> Dict Int Contract -> Properties -> VisualContract
toVisual_ c pid contracts properties = case c of 
  StringValue s -> VStringValue s
  IntValue i -> VIntValue i
  FloatValue f -> VFloatValue f
  Function {argument, name, retval, data}
    -> VFunction {
        argument = argument,
        name = name,
        retval = retval,
        data = data,
        pid = pid
      }
  Delegate {destination, data}
    -> case Dict.get destination contracts of
      (Just contract) -> VConnectedDelegate {
        contract = toVisual_ contract destination contracts properties,
        data = data,
        destination = destination
      }
      Nothing -> VBrokenDelegate {
        data = data,
        destination = destination
      }
  MapContract d
    -> Dict.map (\_ contract -> toVisual_ contract pid contracts properties) d
      |> VMapContract
  ListContract l
    -> List.map (\contract -> toVisual_ contract pid contracts properties) l
      |> VListContract
  PropertyKey propertyID contract
    -> properties |> fetch pid |> fetch propertyID |> \property ->
      VProperty {
        pid = pid,
        propertyID = propertyID,
        value = property,
        contract = toVisual_ contract pid contracts properties
      }

inspectType : Type -> String
inspectType t = case t of
  TStruct d -> d 
    |> Dict.toList 
    |> List.map (\(k, v) -> k ++ ": " ++ (inspectType v))
    |> String.join ", "
    |> (\s -> "{ " ++ s ++ " }")
  TTuple l -> l
    |> List.map inspectType
    |> String.join(", ")
    |> (\s -> "( " ++ s ++ " )")

  TUnion a b -> "(" ++ (inspectType a) ++ " | " ++ (inspectType b) ++ ")"
  TType t d -> (inspectType t) ++ inspectData d
  TLiteral json -> json
  TChannel t -> "channel[" ++ (inspectType t) ++ "]"
  TList t -> "list[" ++ (inspectType t) ++ "]"
  TMap k v -> "map[" ++ (inspectType k) ++ " → " ++ (inspectType v) ++ "]"

  TInt -> "int"
  TFloat -> "float"
  TString -> "string"
  TBool -> "bool"
  TAtom -> "atom"
  TDelegate -> "delegate"
  TNil -> "nil"

  _ -> toString t

inspectData : Data -> String
inspectData d = d
  |> Dict.toList
  |> List.map (\(k, v) -> k ++ ": " ++ v)
  |> String.join ", "
  |> (\s -> "<" ++ s ++ ">")

propertify : Contract -> (Contract, ContractProperties)
propertify contract = 
  let (newContract, (properties, _)) 
    = propertify_ contract ((Dict.fromList []), 1)
  in (newContract, properties)

propertify_ : Contract -> (ContractProperties, Int) -> (Contract, (ContractProperties, Int))
propertify_ contract data = case contract of
  ListContract l -> 
    let (subcontracts, newData) = propertifyList l data in
      (ListContract subcontracts, newData)
  MapContract d ->
    let 
      (subcontractList, newData1) = propertifyMap (Dict.toList d) data
      subcontract = MapContract <| Dict.fromList subcontractList
    in
      case checkProperty d of
        Just prop ->
          let 
            (properties, lastProp) = newData1
            newLastProp = lastProp + 1
            newProperties = Dict.insert newLastProp prop properties
          in
            (PropertyKey newLastProp subcontract, (newProperties, newLastProp))

        Nothing ->
          (subcontract, newData1)

  _ -> (contract, data)

checkProperty : Dict String Contract -> Maybe Property
checkProperty fields = let
    getter      = Dict.get "get"       fields |> Maybe.andThen getFunction 
    setter      = Dict.get "set"       fields |> Maybe.andThen getFunction
    subscriber  = Dict.get "subscribe" fields |> Maybe.andThen getFunction
  in case getter of
    Nothing -> Nothing
    Just { retval } -> checkPropertyConsistency <| {
      getter        = getter,
      setter        = setter,
      subscriber    = subscriber,
      propertyType  = retval,
      value         = Nothing
    }

checkPropertyConsistency : Property -> Maybe Property
checkPropertyConsistency prop = let
    getterType = Maybe.map (\f -> f.retval) prop.getter
    setterType = Maybe.map (\f -> f.argument) prop.setter
    subscriberType = Maybe.andThen (\f -> unChannel f.retval) prop.subscriber

    equiv = (maybeEquivTypes getterType setterType) && (maybeEquivTypes getterType subscriberType)
  in
    case equiv of
      True -> Just prop
      False -> Nothing

getFunction : Contract -> Maybe FunctionStruct
getFunction c = case c of
  Function f -> Just f
  _          -> Nothing

maybeEquivTypes : Maybe Type -> Maybe Type -> Bool
maybeEquivTypes t1 t2 = case (t1, t2) of
  (Nothing, _) -> True
  (_, Nothing) -> True
  (Just t1, Just t2) -> equivTypes t1 t2

unChannel : Type -> Maybe Type
unChannel t = case t of
  -- this needs to be smarter
  TChannel t2 -> Just t2
  _           -> Nothing

propertifyList : List Contract -> (ContractProperties, Int) -> (List Contract, (ContractProperties, Int))
propertifyList l data = case l of
  [] -> ([], data)
  h::t ->
    let (newTail, newData1) = propertifyList t data in 
      let (contract, newData2) = propertify_ h newData1 in
        (contract :: newTail, newData2)

propertifyMap : List (String, Contract) -> (ContractProperties, Int) -> (List (String, Contract), (ContractProperties, Int))
propertifyMap l data = case l of
  [] -> ([], data)
  (hk, hv)::t ->
    let (newTail, newData1) = propertifyMap t data in 
      let (contract, newData2) = propertify_ hv newData1 in
        ((hk, contract) :: newTail, newData2)


-- utils

fetch : comparable -> Dict comparable v -> v
fetch k d = case Dict.get k d of
  Just v -> v
  Nothing -> Debug.crash "the author of this page is a moron"