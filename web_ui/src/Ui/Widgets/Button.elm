module Ui.Widgets.Button exposing (Model, Msg, init, update, updateMetaData, view, pushResult)

import Ui.Widgets.Simple exposing (metaAttributes, label)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value, inspectType, typeErrorToString, TypeError(..), typeCheck)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text, button, input)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Json.Decode as JD

import Random
import Random.Char
import Random.String


type alias Model =
    { metaData        : MetaData
    , callee          : Callee
    , token           : Maybe String
    }


type Msg
    = Call
    | NewToken String


init : MetaData -> Callee -> Model
init meta c =
    { metaData = meta
    , callee = c
    , token = Nothing
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg ({ callee, metaData } as model) = case msg of
    Call ->
        ( model, Random.generate NewToken (Random.String.string 64 Random.Char.english), [] )
    NewToken token ->
        ( { model | token = Just token }, Cmd.none, [ RequestCall callee JE.null token ])

pushResult : ActionResult -> Model -> ( Model, Cmd Msg, List Action )
pushResult result model = case result of
    CallResult v token -> case (Just token) == model.token of
        False -> ( model, Cmd.none, [] )
        True  -> ( model, Cmd.none, [] )    -- probably do something here?

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    div ((metaAttributes m.metaData) ++ [ class "button" ]) <|
        [ button [ onClick (lift Call) ] [ text <| label m.metaData ]
        ]
