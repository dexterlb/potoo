import Css exposing (..)
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled, class, title)
import Html.Styled.Events exposing (onClick, onInput)

import Api exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)
import Json.Encode
import Json.Decode
import Random
import Random.String
import Random.Char


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
  , fetchingContracts: Set Int
  , toCall : Maybe VisualContract
  , callToken : Maybe String
  , callArgument : Maybe Json.Encode.Value
  , callResult : Maybe Json.Encode.Value
  }


init : (Model, Cmd Msg)
init =
  (Model "" [] Dict.empty Set.empty Nothing Nothing Nothing Nothing, Cmd.none)


-- UPDATE

type Msg
  = Input String
  | Send
  | SocketMessage String
  | Begin
  | AskCall VisualContract
  | CallArgumentInput String
  | PerformCall { pid: Int, name: String, argument: Json.Encode.Value }
  | PerformCallWithToken { pid: Int, name: String, argument: Json.Encode.Value } String
  | CancelCall


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Input newInput ->
      ({model | input = newInput}, Cmd.none)

    Send ->
      ({model | input = ""}, Api.sendRaw model.input)

    SocketMessage str ->
      case parseResponse str of
        Ok resp -> handleResponse model resp
        Err err -> ({model | messages = err :: model.messages}, Cmd.none)
    
    AskCall f -> ({model | toCall = Just f, callToken = Nothing, callArgument = Nothing, callResult = Nothing}, Cmd.none)

    CallArgumentInput input -> ({model | callArgument = checkCallInput input}, Cmd.none)

    PerformCall data -> (model, 
        Random.generate 
          (PerformCallWithToken data)
          (Random.String.string 64 Random.Char.english)
      )
    PerformCallWithToken data token -> ({model | callToken = Just token}, Api.unsafeCall data token)

    CancelCall -> ({ model |
        toCall = Nothing,
        callToken = Nothing,
        callArgument = Nothing,
        callResult = Nothing
      }, Cmd.none)

    Begin ->
      (model, Api.getContract 0)

handleResponse : Model -> Response -> (Model, Cmd Msg)
handleResponse m resp = case resp of
  GotContract pid contract
    -> checkMissing contract {m | 
        contracts = Dict.insert pid contract m.contracts,
        fetchingContracts = Set.remove pid m.fetchingContracts
      }
  UnsafeCallResult token value
    -> case m.callToken of
      Just actualToken -> case token of
        actualToken -> ({m | callResult = Just value}, Cmd.none)
      _ -> (m, Cmd.none)

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
    , button [ Styles.functionCallButton, onClick (AskCall vc) ] [ text "call" ]
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

renderData : Data -> Html Msg
renderData d = div [ Styles.dataBlock ] (
    Dict.toList d |> List.map (
      \(name, value) -> div [ Styles.dataItem ]
        [ div [ Styles.dataName ] [ text name ]
        , div [ Styles.dataValue ] [ text value ]
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


view : Model -> Html Msg
view model =
  div []
    [ button [onClick Begin] [text "Woo"]
    , div []
        [ div [] (List.map viewMessage model.messages)
        , input [onInput Input] []
        , button [onClick Send] [text "Send"]
        ]
    , renderContract <| toVisual 0 model.contracts
    , renderAskCallWindow model.toCall model.callArgument model.callToken model.callResult
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]