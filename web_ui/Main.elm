import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import Api exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)
import Contracts exposing (..)

main =
  Html.program
    { init = init
    , view = view
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
renderContract vc = case vc of
  VStringValue s -> div [class "string_value"] 
    [text s]
  VIntValue i -> div [class "int_value"]
    [text <| toString i]
  VFloatValue f -> div [class "float_value"]
    [text <| toString f]
  VFunction {argument, name, retval, data, pid} -> div [class "function", title ("name: " ++ name ++ ", pid: " ++ (toString pid))]
    [ div [class "argument_type"]
        [ text <| inspectType argument ]
    , div [class "retval_type"]
        [ text <| inspectType retval]
    , renderData data
    ]
  VConnectedDelegate {contract, data, destination} -> div [class "connected_delegate"]
    [ div [class "descriptor", title ("destination: " ++ (toString destination))]
        [ renderData data ]
    , div [class "subcontract"]
        [ renderContract contract]
    ]
  VBrokenDelegate {data, destination} -> div [class "broken_delegate"]
    [ div [class "descriptor", title ("destination: " ++ (toString destination))]
        [ renderData data ]
    ]
  VMapContract d -> div [class "map_contract"] (
    Dict.toList d |> List.map (
      \(name, contract) -> div [class "item"]
        [ div [class "name"] [ text name ]
        , div [class "contract"] [ renderContract contract ]
        ]
    ))
  VListContract l -> div [class "list_contract"] (
    l |> List.map (
      \contract -> div [class "contract"]
        [ renderContract contract ]
    ))

renderData : Data -> Html Msg
renderData d = div [class "data"] (
    Dict.toList d |> List.map (
      \(name, value) -> div [class "data_item"]
        [ div [class "name"] [ text name ]
        , div [class "value"] [ text value ]
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
    , div [class "contract"]
      [ renderContract <| toVisual 0 model.contracts
      ]
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]