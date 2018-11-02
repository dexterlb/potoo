import Html
import Html.Styled.Keyed
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled, class, title)
import Html.Styled.Attributes as Attrs
import Html.Styled.Events exposing (onClick, onInput)
import Navigation
import Navigation exposing (Location)

import UrlParser exposing ((</>), s, string, parseHash)

import Api exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)
import Json.Encode
import Json.Decode
import Random
import Random.String
import Random.Char
import Delay
import Time

import Debug exposing (log)

import Contracts exposing (..)
import Styles

import Modes exposing (..)

main =
  Navigation.program
    (\loc -> NewLocation loc)
    { init = init
    , view = view >> toUnstyled
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , conn : Conn
  , mode : Mode
  , location: Location
  , contracts: Dict Int Contract
  , allProperties : Properties
  , fetchingContracts: Set Int
  , toCall : Maybe VisualContract
  , callToken : Maybe String
  , callArgument : Maybe Json.Encode.Value
  , callResult : Maybe Json.Encode.Value
  }

init : Location -> (Model, Cmd Msg)
init loc =
  (emptyModel loc, startCommand)

startCommand : Cmd Msg
startCommand = Cmd.batch
  [ nextPing
  ]

emptyModel : Location -> Model
emptyModel loc = Model "" [] (connectWithLocation loc) (parseMode loc) loc Dict.empty Dict.empty Set.empty Nothing Nothing Nothing Nothing

parseMode : Location -> Mode
parseMode l = case parseHash (UrlParser.s "mode" </> string) l of
  Just "advanced" -> Advanced
  _               -> Basic

connectWithLocation : Location -> Conn
connectWithLocation { host } = Api.connect ("ws://" ++ host ++ "/ws")


-- UPDATE

type Msg
  = SocketMessage String
  | AskCall VisualContract
  | AskInstantCall VisualContract
  | CallArgumentInput String
  | PerformCall { target: DelegateStruct, name: String, argument: Json.Encode.Value }
  | PerformCallWithToken { target: DelegateStruct, name: String, argument: Json.Encode.Value } String
  | CancelCall
  | CallGetter (Pid, PropertyID) FunctionStruct
  | CallSetter (Pid, PropertyID) FunctionStruct Json.Encode.Value
  | SendPing
  | NewLocation Location


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    SocketMessage str ->
      case parseResponse str of
        Ok resp -> handleResponse model resp
        Err err -> let msg = "unable to parse response >> " ++ str ++ " << : " ++ err
          in ({model | messages = msg :: model.messages}, Cmd.none)

    AskCall f -> ({model | toCall = Just f, callToken = Nothing, callArgument = Nothing, callResult = Nothing}, Cmd.none)

    AskInstantCall f -> ({model | toCall = Just f, callArgument = Just Json.Encode.null}, instantCall f)

    CallArgumentInput input -> ({model | callArgument = checkCallInput input}, Cmd.none)

    PerformCall data -> (model, performCall data)

    PerformCallWithToken data token -> ({model | callToken = Just token}, Api.unsafeCall model.conn data token)

    CancelCall -> ({ model |
        toCall = Nothing,
        callToken = Nothing,
        callArgument = Nothing,
        callResult = Nothing
      }, Cmd.none)

    CallGetter (pid, id) { name } -> (
        model,
        Api.getterCall model.conn
          {target = delegate pid, name = name, argument = Json.Encode.null}
          (pid, id)
      )

    CallSetter (pid, id) { name } value -> (
        model,
        Api.setterCall model.conn
          {target = delegate pid, name = name, argument = value}
          (pid, id)
      )

    SendPing -> (model, sendPing model.conn)

    NewLocation loc -> (emptyModel loc, Cmd.none)

nextPing : Cmd Msg
nextPing = Delay.after 5 Time.second SendPing

instantCall : VisualContract -> Cmd Msg
instantCall vc = case vc of
  (VFunction {argument, name, retval, data, pid}) ->
    performCall {target = delegate pid, name = name, argument = Json.Encode.null}
  _ -> Cmd.none

performCall : {target: DelegateStruct, name: String, argument: Json.Encode.Value} -> Cmd Msg
performCall data = Random.generate
  (PerformCallWithToken data)
  (Random.String.string 64 Random.Char.english)

handleResponse : Model -> Response -> (Model, Cmd Msg)
handleResponse m resp = case resp of
  GotContract pid contract
    ->
      let
        (newContract, properties) = propertify contract
        (newModel, newCommand) = checkMissing newContract {m |
          allProperties = Dict.insert pid properties m.allProperties,
          contracts = Dict.insert pid newContract m.contracts,
          fetchingContracts = Set.remove pid m.fetchingContracts
        }
      in
        (newModel, Cmd.batch [ subscribeProperties m.conn pid properties,
                               newCommand ])

  UnsafeCallResult token value
    -> case m.callToken of
      Just actualToken -> case token of
        actualToken -> ({m | callResult = Just value}, Cmd.none)
      _ -> (m, Cmd.none)
  PropertyValueResult (pid, propertyID) value
    -> (
      { m | allProperties = m.allProperties |>
        Dict.update pid (Maybe.map <|
          Dict.update propertyID (Maybe.map <|
            setPropertyValue value
          )
        )
      },
      Cmd.none
    )
  ChannelResult token chan
    -> (m, subscribe m.conn chan token)
  SubscribedChannel token
    -> (Debug.log (Json.Encode.encode 0 token) m, Cmd.none)
  PropertySetterStatus _ status
    -> (Debug.log ("property setter status: " ++ (Json.Encode.encode 0 status)) m, Cmd.none)

  Pong -> (m, nextPing)

  Hello -> (emptyModel m.location, Api.getContract m.conn (delegate 0))


subscribeProperties : Conn -> Pid -> ContractProperties -> Cmd Msg
subscribeProperties conn pid properties
   = Dict.toList properties
  |> List.map (foo conn pid)
  |> Cmd.batch

foo : Conn -> Pid -> (PropertyID, Property) -> Cmd Msg
foo conn pid (id, prop) = case prop.subscriber of
  Nothing -> Cmd.none
  Just { name } -> Cmd.batch
    [ subscriberCall conn
        { target = delegate pid, name = name, argument = Json.Encode.null }
        (pid, id)
    , case prop.getter of
        Nothing -> Cmd.none
        Just { name } -> getterCall conn
          { target = delegate pid, name = name, argument = Json.Encode.null }
          (pid, id)
    ]

setPropertyValue : Json.Encode.Value -> Property -> Property
setPropertyValue v prop = case decodePropertyValue v prop of
  Ok value -> { prop | value = Just value }
  Err _    -> { prop | value = Just <| UnknownProperty v }

decodePropertyValue : Json.Encode.Value -> Property -> Result String PropertyValue
decodePropertyValue v prop = case (stripType prop.propertyType) of
    TFloat -> Json.Decode.decodeValue (Json.Decode.float
           |> Json.Decode.map FloatProperty) v
    TBool  -> Json.Decode.decodeValue (Json.Decode.bool
           |> Json.Decode.map BoolProperty) v
    TInt   -> Json.Decode.decodeValue (Json.Decode.int
           |> Json.Decode.map IntProperty) v
    _      -> Err "unknown property type"


checkMissing : Contract -> Model -> (Model, Cmd Msg)
checkMissing c m = let
    missing = Set.diff (delegatePids c |> Set.fromList) m.fetchingContracts
    newModel = {m | fetchingContracts = Set.union m.fetchingContracts missing}
    command = missing |> Set.toList |> List.map delegate |> List.map (Api.getContract m.conn) |> Cmd.batch
  in (newModel, command)

delegatePids : Contract -> List Int
delegatePids contract = case contract of
  (MapContract d)
    -> Dict.values d
    |> List.concatMap delegatePids
  (ListContract l)
    -> l |> List.concatMap delegatePids
  (Delegate {destination})
    -> [destination]
  _ -> []

checkCallInput : String -> Maybe Json.Encode.Value
checkCallInput s = case Json.Decode.decodeString Json.Decode.value s of
  Ok v -> Just v
  _    -> Nothing


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Api.listenRaw model.conn SocketMessage


-- VIEW

type alias MetaData =
  { uiLevel     : Int
  , description : String
  }

metaData : VisualContract -> String -> MetaData
metaData vc name = case vc of
  VFunction             {data} -> dataMetaData data
  VConnectedDelegate    {data} -> dataMetaData data
  VBrokenDelegate       {data} -> dataMetaData data
  VMapContract d               -> MetaData
    (Dict.get "ui_level"    d |> Maybe.andThen getIntValue    |> Maybe.withDefault 0)
    (Dict.get "description" d |> Maybe.andThen getStringValue |> Maybe.withDefault name)
  VStringValue _               -> case name of
    "description" -> MetaData 1 name
    "ui_level"    -> MetaData 1 name
    _             -> MetaData 0 name
  _                            -> MetaData 0 name

dataMetaData : Data -> MetaData
dataMetaData d = MetaData
  (  Dict.get "ui_level" d
  |> Maybe.withDefault (Json.Encode.int 0)
  |> Json.Decode.decodeValue Json.Decode.int
  |> Result.withDefault 0)
  (  Dict.get "description" d
  |> Maybe.withDefault (Json.Encode.string "")
  |> Json.Decode.decodeValue Json.Decode.string
  |> Result.withDefault "")


renderContract : Mode -> VisualContract -> Html Msg
renderContract mode vc = div [ Styles.contract mode, Styles.contractContent mode (metaData vc "") ]
  [ renderHeader mode (metaData vc "")
  , renderContractContent mode vc ]

renderContractContent : Mode -> VisualContract -> Html Msg
renderContractContent mode vc = case vc of
  VStringValue s -> div [ Styles.stringValue mode ]
    [text s]
  VIntValue i -> div [ Styles.intValue mode ]
    [text <| toString i]
  VFloatValue f -> div [ Styles.floatValue mode ]
    [text <| toString f]
  VFunction {argument, name, retval, data, pid} -> div [Styles.function mode, title ("name: " ++ name ++ ", pid: " ++ (toString pid))]
    [ div [ Styles.functionArgumentType mode ]
        [ text <| inspectType argument ]
    , div [ Styles.functionRetvalType mode ]
        [ text <| inspectType retval]
    , case argument of
        TNil -> button [ Styles.instantCallButton mode, onClick (AskInstantCall vc) ] [ text "instant call" ]
        _ -> button [ Styles.functionCallButton mode, onClick (AskCall vc) ] [ text "call" ]
    , renderData mode data
    ]
  VConnectedDelegate {contract, data, destination} -> div [ Styles.connectedDelegate mode ]
    [ div [ Styles.delegateDescriptor mode, title ("destination: " ++ (toString destination))]
        [ renderData mode data ]
    , div [ Styles.delegateSubContract mode ]
        [ renderContract mode contract]
    ]
  VBrokenDelegate {data, destination} -> div [ Styles.brokenDelegate mode ]
    [ div [ Styles.delegateDescriptor mode, title ("destination: " ++ (toString destination))]
        [ renderData mode data ]
    ]
  VMapContract d -> div [ Styles.mapContract mode ] (
    Dict.toList d |> List.map (
      \(name, contract) -> div [ Styles.mapContractItem mode, Styles.contractContent mode (metaData contract name)  ]
        [ renderHeader mode (metaData contract name)
        , div [Styles.mapContractName mode] [ text name ]
        , renderContractContent mode contract
        ]
    ))
  VListContract l -> div [ Styles.listContract mode ] (
    l |> List.map (
      \contract -> div [ Styles.listContractItem mode, Styles.contractContent mode (metaData contract "") ]
        [ renderHeader mode (metaData contract "")
        , renderContractContent mode contract ]
    ))
  VProperty {pid, propertyID, value, contract} -> div [ Styles.propertyBlock mode ]
    [ renderHeader mode (metaData contract "")
    , renderProperty mode pid propertyID value
    , div [ Styles.propertySubContract mode ] [ renderContractContent mode contract ]
    ]

renderHeader : Mode -> MetaData -> Html Msg
renderHeader mode { description } = div [ Styles.contractHeader mode ]
  [ text description ]

renderData : Mode -> Data -> Html Msg
renderData mode d = div [ Styles.dataBlock mode ] (
    Dict.toList d |> List.map (
      \(name, value) -> div [ Styles.dataItem mode ]
        [ div [ Styles.dataName mode ] [ text name ]
        , div [ Styles.dataValue mode ] [ text (Json.Encode.encode 0 value) ]
        ]
    ))

renderAskCallWindow : Mode -> Maybe VisualContract -> Maybe Json.Encode.Value -> Maybe String -> Maybe Json.Encode.Value -> Html Msg
renderAskCallWindow mode mf callArgument callToken callResult = case mf of
  Just (VFunction {argument, name, retval, data, pid}) ->
    div [Styles.callWindow mode]
      [ button [onClick CancelCall, Styles.callCancel mode] [text "cancel"]
      , div [Styles.callFunctionName mode]         [text name]
      , div [Styles.callFunctionArgumentType mode] [text <| inspectType argument]
      , div [Styles.callFunctionRetvalType mode]   [text <| inspectType retval]
      , case callArgument of
          Nothing -> div [Styles.callFunctionEntry mode]
            [ input [onInput CallArgumentInput] []
            ]
          Just jsonArg -> case callToken of
            Nothing -> div [Styles.callFunctionEntry mode]
              [ input [onInput CallArgumentInput] []
              , button
                  [ onClick (PerformCall {target = delegate pid, name = name, argument = jsonArg})
                  ] [text "call"]
              ]
            Just _ -> div []
              [ div [Styles.callFunctionInput mode] [text <| Json.Encode.encode 0 jsonArg]
              , case callResult of
                  Nothing -> div [Styles.callFunctionOutputWaiting mode] []
                  Just data -> div [Styles.callFunctionOutput mode] [text <| Json.Encode.encode 0 data]
              ]
      ]

  _ -> div [] []

renderProperty : Mode -> Pid -> PropertyID -> Property -> Html Msg
renderProperty mode pid propID prop = div [Styles.propertyContainer mode] <| justs
  [ Maybe.map (renderPropertyValue mode (propValueStyle mode prop)) prop.value
  , renderPropertyControl mode pid propID prop
  , renderPropertyGetButton mode pid propID prop
  ]

propValueStyle : Mode -> Property -> Attribute Msg
propValueStyle mode prop = case prop.setter of
  Nothing -> Styles.readOnlyPropertyValue mode
  Just _  -> Styles.propertyValue         mode

renderPropertyValue : Mode -> Attribute Msg -> PropertyValue -> Html Msg
renderPropertyValue mode style v = (case v of
    IntProperty i -> [ text (toString i) ]
    FloatProperty f -> [ text (toString f) ]
    BoolProperty b -> [ text (toString b) ]
    UnknownProperty v -> [ text <| Json.Encode.encode 0 v]
  ) |> div [style]

renderPropertyGetButton : Mode -> Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyGetButton mode pid propID prop = case prop.getter of
  Nothing -> Nothing
  Just getter ->
    Just <| button
      [ onClick (CallGetter (pid, propID) getter), Styles.propertyGet mode ]
      [ text "↺" ]

renderPropertyControl : Mode -> Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyControl mode pid propID prop = case prop.setter of
  Nothing -> Nothing
  Just setter ->
    case prop.value of
      Just (FloatProperty value) ->
        case getMinMax prop of
          Just minmax -> Just <| renderFloatSliderControl mode pid propID minmax setter value
          Nothing -> Nothing
      Just (BoolProperty value) ->
        Just <| renderBoolCheckboxControl mode pid propID setter value
      _ -> Nothing

getMinMax : Property -> Maybe (Float, Float)
getMinMax prop = case prop.meta.min of
  Nothing -> Nothing
  Just min ->
    case prop.meta.max of
      Nothing -> Nothing
      Just max -> Just (min, max)

renderFloatSliderControl : Mode -> Pid -> PropertyID -> (Float, Float) -> FunctionStruct -> Float -> Html Msg
renderFloatSliderControl mode pid propID (min, max) setter value = input
  [ Attrs.type_ "range"
  , Attrs.min (min |> toString)
  , Attrs.max (max |> toString)
  , Attrs.step "0.01"   -- fixme!
  , Attrs.value <| toString value
  , onInput (\s -> s
      |> String.toFloat
      |> Result.withDefault -1
      |> Json.Encode.float
      |> (CallSetter (pid, propID) setter)
    )
  , Styles.propertyFloatSlider
  mode ] []

renderBoolCheckboxControl : Mode -> Pid -> PropertyID -> FunctionStruct -> Bool -> Html Msg
renderBoolCheckboxControl mode pid propID setter value =
  Html.Styled.Keyed.node "span" [] [
    ((toString value), renderBoolCheckbox mode pid propID setter value)
  ]

renderBoolCheckbox : Mode -> Pid -> PropertyID -> FunctionStruct -> Bool -> Html Msg
renderBoolCheckbox mode pid propID setter value = input
  [ Attrs.type_ "checkbox"
  , Attrs.checked value
  , onClick (CallSetter (pid, propID) setter (Json.Encode.bool <| not value))
  , Styles.propertyBoolCheckbox
  mode ] []

justs : List (Maybe a) -> List a
justs l = case l of
  [] -> []
  (Just h)::t -> h :: (justs t)
  Nothing::t -> justs t

view : Model -> Html Msg
view model =
  div []
    [ renderContract model.mode <| toVisual 0 model.contracts model.allProperties
    , renderAskCallWindow model.mode model.toCall model.callArgument model.callToken model.callResult
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]
