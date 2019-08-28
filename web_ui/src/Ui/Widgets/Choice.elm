module Ui.Widgets.Choice exposing (Model, Msg, init, update, updateMetaData, updateValue, view)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

import Ui.MetaData exposing (MetaData, noMetaData)
import Contracts exposing (Callee, Value(..), inspectType, typeErrorToString, TypeError(..), typeCheck)
import Ui.Action exposing (..)
import Ui.MetaData exposing (..)

import Html exposing (Html, div, text, button, input, Attribute, fieldset, label)
import Html.Attributes exposing (class, checked, type_)
import Html.Events exposing (onClick, onInput)

import Json.Encode as JE
import Json.Decode as JD

import Random
import Random.Char
import Random.String

type alias Model =
    { metaData:      MetaData
    , value:         Maybe JE.Value
    , wantValue:     Maybe JE.Value
    }


type Msg
    = Set JE.Value


init : MetaData -> Maybe JE.Value -> Model
init meta v =
    { metaData = meta
    , value = v
    , wantValue = Nothing
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case msg of
    Set v ->
        case model.metaData.property of
            Just prop ->
                ( { model | wantValue = Just v },
                    Cmd.none, [ RequestSet prop v ] )
            Nothing -> ( model, Cmd.none, [] )


updateValue : Maybe JE.Value -> Model -> ( Model, Cmd Msg, List Action )
updateValue v model =
    ( { model | value = v, wantValue = Nothing }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children = case m.metaData.valueMeta.oneOf of
    Nothing -> text "<no options>"
    Just opts ->
        renderHeaderWithChildren [ class "choice" ] m.metaData children <|
            [ fieldset [] <| List.map (renderChoice lift m) opts
            ]

renderChoice : (Msg -> msg) -> Model -> JE.Value -> Html msg
renderChoice lift m v = label []
    [ input
        [ type_ "radio"
        , checked (Just v == m.value)
        , wanted  (Just v == m.wantValue)
        , onClick (lift <| Set v)
        ] []
    , text <| stringify v
    ]

wanted : Bool -> Attribute msg
wanted b = case b of
    True  -> class "wanted"
    False -> class "not-wanted"

stringify : JE.Value -> String
stringify v = case JD.decodeValue sdecoder v of
    Ok s -> s
    _    -> "error"

sdecoder : JD.Decoder String
sdecoder = JD.oneOf [ JD.string, JD.map String.fromInt JD.int, JD.map String.fromFloat JD.float
                    , JD.map (JE.encode 0) JD.value ]
