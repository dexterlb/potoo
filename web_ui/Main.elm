import Css exposing (..)
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, styled, class, title)
import Html.Styled.Events exposing (onClick, onInput)

import Api exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)


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
  }


init : (Model, Cmd Msg)
init =
  (Model "" [] Dict.empty Set.empty, Cmd.none)


-- UPDATE

type Msg
  = Input String
  | Send
  | SocketMessage String
  | Begin


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
      
    Begin ->
      (model, Api.getContract 0)

handleResponse : Model -> Response -> (Model, Cmd Msg)
handleResponse m resp = case resp of
  (GotContract pid contract)
    -> checkMissing contract {m | 
        contracts = Dict.insert pid contract m.contracts,
        fetchingContracts = Set.remove pid m.fetchingContracts
      }

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
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]