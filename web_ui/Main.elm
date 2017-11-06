import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import Api exposing (..)

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
  }


init : (Model, Cmd Msg)
init =
  (Model "" [], Cmd.none)


-- UPDATE

type Msg
  = Input String
  | Send
  | SocketMessage String
  | Begin


update : Msg -> Model -> (Model, Cmd Msg)
update msg {input, messages} =
  case msg of
    Input newInput ->
      (Model newInput messages, Cmd.none)

    Send ->
      (Model "" messages, Api.sendRaw input)

    SocketMessage str ->
      (Model input (str :: messages), Cmd.none)
    
    Begin ->
      (Model "" messages, Api.getContract)


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