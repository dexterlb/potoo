module Ui exposing (..)

import Ui.Tree      exposing (..)
import Ui.Builder   exposing (..)
import Ui.Renderer  exposing (..)
import Ui.Action

import Contracts
import Contracts    exposing (Contract, Properties, fetch)


import Dict
import Dict         exposing (Dict)
import Html         exposing (Html)

type alias Model =
  { tree: Tree
  , widgets: Widgets
  }

type alias Msg      = WidgetsMsg
type alias Action   = Ui.Action.Action

build : Int -> Dict Int Contract -> Properties -> Model
-- todo: remove properties from here, move setters getters etc inside the contracts
build pid contracts properties = let (tree, widgets) = toTree pid contracts properties
  in { tree = tree, widgets = widgets }

blank : Model
blank = build 0 Dict.empty Dict.empty

update : (Action -> Cmd m) -> (Msg -> m) -> Msg -> Model -> (Model, Cmd m)
update liftAction liftMsg msg m = let
    (widgets, cmd) = updateWidgets liftAction liftMsg msg m.widgets
  in
    ({ m | widgets = widgets }, cmd)

view : Properties -> Model -> Html Msg
view properties { tree, widgets } = renderUi tree widgets properties
