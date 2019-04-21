module Ui.Widgets.Text exposing (Model, Msg, init, update, updateMetaData, updateValue, view)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value(..), inspectType, typeErrorToString, TypeError(..), typeCheck)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text, button, input, Attribute, fieldset, label)
import Html.Attributes exposing (class, checked, type_, value)
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Json.Decode as JD

import Random
import Random.Char
import Random.String

type alias Model =
    { metaData:      MetaData
    , text:          Maybe String
    , dirty:         Maybe String
    }


type Msg
    = Update String
    | Set
    | Clear


init : MetaData -> Maybe String -> Model
init meta v =
    { metaData = meta
    , text = v
    , dirty = Nothing
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case msg of
    Update s ->
        ( { model | dirty = Just s },
            Cmd.none, [ ] )
    Clear ->
        ( { model | dirty = Nothing },
            Cmd.none, [ ] )
    Set -> case model.dirty of
        Nothing -> ( model, Cmd.none, [] )
        Just s ->
            ( { model | text = Nothing, dirty = Nothing },
                Cmd.none, [ RequestSet model.metaData.propData.property (JE.string s) ] )


updateValue : Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model = case v of
    SimpleString s ->
        ( { model | text = Just s }, Cmd.none, [] )
    _ ->
        ( { model | text = Nothing }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children = case (uiText m) of
    Nothing -> text "<loading text field>"
    Just content ->
        renderHeaderWithChildren [ class "text" ] m.metaData children <|
            [ input [ type_ "text", value content, onInput (lift << Update) ] []
            ] ++ case m.dirty of
                Nothing -> []
                Just _  ->
                    [ button [ onClick (lift Set)   ] [ text "✓" ]
                    , button [ onClick (lift Clear) ] [ text "✗" ]
                    ]

uiText : Model -> Maybe String
uiText m = case m.dirty of
    Just d -> Just d
    Nothing -> m.text
