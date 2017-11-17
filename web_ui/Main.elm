import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import Api exposing (..)

import Dict exposing (Dict)
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
  }


init : (Model, Cmd Msg)
init =
  (Model "" [] Dict.empty, Cmd.none)


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
handleResponse m (GotContract pid contract)  =
  checkMissing {m | contracts = Dict.insert pid contract m.contracts }

checkMissing : Model -> (Model, Cmd Msg)
checkMissing m = (m, Cmd.none) -- todo: implement this

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Api.listenRaw SocketMessage


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ button [onClick Begin] [text "Woo"],
      div []
        [ div [] (List.map viewMessage model.messages)
        , input [onInput Input] []
        , button [onClick Send] [text "Send"]
        ]
    ]


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]