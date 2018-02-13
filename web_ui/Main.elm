import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled, class, title)
import Html.Styled.Attributes as Attrs
import Html.Styled.Events exposing (onClick, onInput)

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

main =
  Html.program
    { init = init
    , view = view >> toUnstyled
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , contracts: Dict Int Contract
  , allProperties : Properties
  , fetchingContracts: Set Int
  , toCall : Maybe VisualContract
  , callToken : Maybe String
  , callArgument : Maybe Json.Encode.Value
  , callResult : Maybe Json.Encode.Value
  }


init : (Model, Cmd Msg)
init =
  (emptyModel, startCommand)

startCommand : Cmd Msg
startCommand = Cmd.batch
  [ nextPing
  ]

emptyModel : Model
emptyModel = Model "" [] Dict.empty Dict.empty Set.empty Nothing Nothing Nothing Nothing


-- UPDATE

type Msg
  = SocketMessage String
  | AskCall VisualContract
  | AskInstantCall VisualContract
  | CallArgumentInput String
  | PerformCall { pid: Int, name: String, argument: Json.Encode.Value }
  | PerformCallWithToken { pid: Int, name: String, argument: Json.Encode.Value } String
  | CancelCall
  | CallGetter (Pid, PropertyID) FunctionStruct
  | CallSetter (Pid, PropertyID) FunctionStruct Json.Encode.Value
  | SendPing


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

    PerformCallWithToken data token -> ({model | callToken = Just token}, Api.unsafeCall data token)

    CancelCall -> ({ model |
        toCall = Nothing,
        callToken = Nothing,
        callArgument = Nothing,
        callResult = Nothing
      }, Cmd.none)

    CallGetter (pid, id) { name } -> (
        model,
        Api.getterCall
          {pid = pid, name = name, argument = Json.Encode.null}
          (pid, id)
      )

    CallSetter (pid, id) { name } value -> (
        model,
        Api.setterCall
          {pid = pid, name = name, argument = value}
          (pid, id)
      )

    SendPing -> (model, sendPing)

nextPing : Cmd Msg
nextPing = Delay.after 5 Time.second SendPing

instantCall : VisualContract -> Cmd Msg
instantCall vc = case vc of
  (VFunction {argument, name, retval, data, pid}) ->
    performCall {pid = pid, name = name, argument = Json.Encode.null}
  _ -> Cmd.none

performCall : {pid: Int, name: String, argument: Json.Encode.Value} -> Cmd Msg
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
        (newModel, Cmd.batch [ subscribeProperties pid properties,
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
    -> (m, subscribe chan token)
  SubscribedChannel token
    -> (Debug.log (Json.Encode.encode 0 token) m, Cmd.none)
  PropertySetterStatus _ status
    -> (Debug.log ("property setter status: " ++ (Json.Encode.encode 0 status)) m, Cmd.none)

  Pong -> (m, nextPing)

  Hello -> (emptyModel, Api.getContract 0)

subscribeProperties : Pid -> ContractProperties -> Cmd Msg
subscribeProperties pid properties
   = Dict.toList properties
  |> List.map (foo pid)
  |> Cmd.batch

foo : Pid -> (PropertyID, Property) -> Cmd Msg
foo pid (id, prop) = case prop.subscriber of
  Nothing -> Cmd.none
  Just { name } -> Cmd.batch
    [ subscriberCall
        { pid = pid, name = name, argument = Json.Encode.null }
        (pid, id)
    , case prop.getter of
        Nothing -> Cmd.none
        Just { name } -> getterCall
          { pid = pid, name = name, argument = Json.Encode.null }
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
    command = missing |> Set.toList |> List.map Api.getContract |> Cmd.batch
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
  Api.listenRaw SocketMessage


-- VIEW

renderContract : VisualContract -> Html Msg
renderContract vc = div [ Styles.contract ] [ renderContractContent vc ]

renderContractContent : VisualContract -> Html Msg
renderContractContent vc = case vc of
  VStringValue s -> div [ Styles.stringValue ]
    [text s]
  VIntValue i -> div [ Styles.intValue ]
    [text <| toString i]
  VFloatValue f -> div [ Styles.floatValue ]
    [text <| toString f]
  VFunction {argument, name, retval, data, pid} -> div [Styles.function, title ("name: " ++ name ++ ", pid: " ++ (toString pid))]
    [ div [ Styles.functionArgumentType ]
        [ text <| inspectType argument ]
    , div [ Styles.functionRetvalType ]
        [ text <| inspectType retval]
    , case argument of
        TNil -> button [ Styles.instantCallButton, onClick (AskInstantCall vc) ] [ text "instant call" ]
        _ -> button [ Styles.functionCallButton, onClick (AskCall vc) ] [ text "call" ]
    , renderData data
    ]
  VConnectedDelegate {contract, data, destination} -> div [ Styles.connectedDelegate ]
    [ div [ Styles.delegateDescriptor, title ("destination: " ++ (toString destination))]
        [ renderData data ]
    , div [ Styles.delegateSubContract ]
        [ renderContract contract]
    ]
  VBrokenDelegate {data, destination} -> div [ Styles.brokenDelegate ]
    [ div [ Styles.delegateDescriptor, title ("destination: " ++ (toString destination))]
        [ renderData data ]
    ]
  VMapContract d -> div [ Styles.mapContract ] (
    Dict.toList d |> List.map (
      \(name, contract) -> div [ Styles.mapContractItem ]
        [ div [Styles.mapContractName] [ text name ]
        , renderContractContent contract
        ]
    ))
  VListContract l -> div [ Styles.listContract ] (
    l |> List.map (
      \contract -> renderContractContent contract
    ))
  VProperty {pid, propertyID, value, contract} -> div [ Styles.propertyBlock ]
    [ renderProperty pid propertyID value
    , div [ Styles.propertySubContract ] [ renderContractContent contract ]
    ]

renderData : Data -> Html Msg
renderData d = div [ Styles.dataBlock ] (
    Dict.toList d |> List.map (
      \(name, value) -> div [ Styles.dataItem ]
        [ div [ Styles.dataName ] [ text name ]
        , div [ Styles.dataValue ] [ text (Json.Encode.encode 0 value) ]
        ]
    ))

renderAskCallWindow : Maybe VisualContract -> Maybe Json.Encode.Value -> Maybe String -> Maybe Json.Encode.Value -> Html Msg
renderAskCallWindow mf callArgument callToken callResult = case mf of
  Just (VFunction {argument, name, retval, data, pid}) ->
    div [Styles.callWindow]
      [ button [onClick CancelCall, Styles.callCancel] [text "cancel"]
      , div [Styles.callFunctionName]         [text name]
      , div [Styles.callFunctionArgumentType] [text <| inspectType argument]
      , div [Styles.callFunctionRetvalType]   [text <| inspectType retval]
      , case callArgument of
          Nothing -> div [Styles.callFunctionEntry]
            [ input [onInput CallArgumentInput] []
            ]
          Just jsonArg -> case callToken of
            Nothing -> div [Styles.callFunctionEntry]
              [ input [onInput CallArgumentInput] []
              , button
                  [ onClick (PerformCall {pid = pid, name = name, argument = jsonArg})
                  ] [text "call"]
              ]
            Just _ -> div []
              [ div [Styles.callFunctionInput] [text <| Json.Encode.encode 0 jsonArg]
              , case callResult of
                  Nothing -> div [Styles.callFunctionOutputWaiting] []
                  Just data -> div [Styles.callFunctionOutput] [text <| Json.Encode.encode 0 data]
              ]
      ]

  _ -> div [] []

renderProperty : Pid -> PropertyID -> Property -> Html Msg
renderProperty pid propID prop = div [Styles.propertyContainer] <| justs
  [ Maybe.map renderPropertyValue prop.value
  , renderPropertyControl pid propID prop
  , renderPropertyGetButton pid propID prop
  ]

renderPropertyValue : PropertyValue -> Html Msg
renderPropertyValue v = (case v of
    IntProperty i -> [ text (toString i) ]
    FloatProperty f -> [ text (toString f) ]
    BoolProperty b -> [ text (toString b) ]
    UnknownProperty v -> [ text <| Json.Encode.encode 0 v]
  ) |> div [Styles.propertyValue]

renderPropertyGetButton : Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyGetButton pid propID prop = case prop.getter of
  Nothing -> Nothing
  Just getter ->
    Just <| button
      [ onClick (CallGetter (pid, propID) getter), Styles.propertyGet ]
      [ text "↺" ]

renderPropertyControl : Pid -> PropertyID -> Property -> Maybe (Html Msg)
renderPropertyControl pid propID prop = case prop.setter of
  Nothing -> Nothing
  Just setter ->
    case prop.value of
      Just (FloatProperty value) ->
        case getMinMax prop of
          Just minmax -> Just <| renderFloatSliderControl pid propID minmax setter value
          Nothing -> Nothing
      Just (BoolProperty value) ->
        Just <| renderBoolCheckboxControl pid propID setter value
      _ -> Nothing

getMinMax : Property -> Maybe (Float, Float)
getMinMax prop = case prop.meta.min of
  Nothing -> Nothing
  Just min ->
    case prop.meta.max of
      Nothing -> Nothing
      Just max -> Just (min, max)

renderFloatSliderControl : Pid -> PropertyID -> (Float, Float) -> FunctionStruct -> Float -> Html Msg
renderFloatSliderControl pid propID (min, max) setter value = input
  [ Attrs.type_ "range"
  , Attrs.min (min |> toString)
  , Attrs.max (max |> toString)
  , Attrs.value <| toString value
  , onInput (\s -> s
      |> String.toFloat
      |> Result.withDefault -1
      |> Json.Encode.float
      |> (CallSetter (pid, propID) setter)
    )
  , Styles.propertyFloatSlider
  ] []

renderBoolCheckboxControl : Pid -> PropertyID -> FunctionStruct -> Bool -> Html Msg
renderBoolCheckboxControl pid propID setter value = input
  [ Attrs.type_ "checkbox"
  , Attrs.value <| toString value
  , onClick (CallSetter (pid, propID) setter (Json.Encode.bool <| not value))
  , Styles.propertyBoolCheckbox
  ] []


justs : List (Maybe a) -> List a
justs l = case l of
  [] -> []
  (Just h)::t -> h :: (justs t)
  Nothing::t -> justs t

view : Model -> Html Msg
view model =
  div []
    [ renderContract <| toVisual 0 model.contracts model.allProperties
    , renderAskCallWindow model.toCall model.callArgument model.callToken model.callResult
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]