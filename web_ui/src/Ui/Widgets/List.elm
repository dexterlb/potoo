module Ui.Widgets.List exposing (Model, Msg, init, update, updateMetaData, view)

import Ui.Widgets.Simple exposing (metaAttributes, label, renderHeaderWithChildren)

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

type Mode
    = Normal
    | Tab Int

type alias Model =
    { metaData        : MetaData
    , mode            : Mode
    }


type Msg
    = Bla


init : MetaData -> Model
init meta =
    { metaData = meta
    , mode = makeMode meta
    }

update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg model = case msg of
    Bla -> ( model, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta, mode = makeMode meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children = case m.mode of
    Normal ->
        renderHeaderWithChildren [ class "list" ] m.metaData children []
    Tab n ->
        renderHeaderWithChildren [ class "list-tabbed" ] m.metaData
            (selectTab n children) (renderTabs lift m children)

renderTabs : (Msg -> msg) -> Model -> List (Html msg) -> List (Html msg)
renderTabs lift m children = List.map (renderTab lift m) children

renderTab : (Msg -> msg) -> Model -> Html msg -> Html msg
renderTab lift m child = div [ class "tab" ] [ child ]

selectTab : Int -> List (Html msg) -> List (Html msg)
selectTab n l = List.take 1 <| List.drop n l

makeMode : MetaData -> Mode
makeMode meta = case getBoolTag "tabbed" meta.uiTags of
    True    -> Tab 0
    False   -> Normal
