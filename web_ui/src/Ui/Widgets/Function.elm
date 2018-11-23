module Ui.Widgets.Function exposing (Model, Msg, init, update, updateMetaData, view, pushResult)

import Ui.Widgets.Simple exposing (renderHeaderWithChildren)

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
    , currentArgument : Result String JE.Value
    , token           : Maybe String
    , result          : Maybe JE.Value
    , expanded        : Bool
    }


type Msg
    = ArgumentInput String
    | Call
    | Clear
    | NewToken String
    | ExpandCollapse


init : MetaData -> Callee -> Model
init meta c =
    { metaData = meta
    , callee = c
    , currentArgument = checkArgument c ""
    , token = Nothing
    , result = Nothing
    , expanded = False
    }


update : Msg -> Model -> ( Model, Cmd Msg, List Action )
update msg ({ currentArgument, callee, metaData } as model) = case msg of
    ArgumentInput s ->
        ({ model | currentArgument = checkArgument callee s }, Cmd.none, [])
    Call ->
        ( model, Random.generate NewToken (Random.String.string 64 Random.Char.english), [] )
    NewToken token ->
        case currentArgument of
            Ok argument ->
                ( { model | token = Just token }, Cmd.none, [ RequestCall callee argument token ])
            Err _ ->
                (init metaData callee, Cmd.none, [])
    Clear ->
        ( init metaData callee, Cmd.none, [] )
    ExpandCollapse ->
        ( { model | expanded = not model.expanded }, Cmd.none, [] )

pushResult : ActionResult -> Model -> ( Model, Cmd Msg, List Action )
pushResult result model = case result of
    CallResult v token -> case (Just token) == model.token of
        False -> ( model, Cmd.none, [] )
        True  -> ( { model | result = Just v }, Cmd.none, [] )

updateMetaData : MetaData -> Model -> ( Model, Cmd Msg, List Action )
updateMetaData meta model =
    ( { model | metaData = meta }, Cmd.none, [] )

view : (Msg -> msg) -> Model -> List (Html msg) -> Html msg
view lift m children =
    renderHeaderWithChildren [ class "function" ] m.metaData children <|
    [ div [ class "function-type" ]
        [ div [ class "argument" ] [ text <| inspectType m.callee.argument ]
        , div [ class "retval"   ] [ text <| inspectType m.callee.retval   ]
        ]
    , button [ class "expand-collapse", onClick (lift ExpandCollapse) ] [ text "<>" ]
    , div [ class "function-callbox", expandedClass m ]
        (case m.token of
            Nothing ->
                [ input  [ class "argument-input", onInput (lift << ArgumentInput) ] []
                , (case m.currentArgument of
                    Err msg -> div    [ class "argument-info" ] [ text msg ]
                    Ok  arg -> button [ onClick (lift Call) ] [ text "call" ]
                )
                ]
            Just _ ->
                [ div [ class "argument-box" ] [ text (argumentString m) ]
                ] ++ (case m.result of
                Nothing ->
                    [ div [ class "result-loading" ] []
                    , button [ onClick (lift Clear) ] [ text "cancel" ]
                    ]
                Just result ->
                    [ div [ class "result-box" ] [ text <| JE.encode 0 result ]
                    , button [ onClick (lift Clear) ] [ text "clear" ]
                    ]
                )
        )
    ]

expandedClass { expanded } = case expanded of
    True    -> class "expanded"
    False   -> class "collapsed"

checkArgument : Callee -> String -> Result String JE.Value
checkArgument { argument } s = case s of
    "" -> Err ("please enter a value of type '" ++ (inspectType argument) ++ "'")
    _  -> case JD.decodeString JD.value s of
        Err _ -> Err "please enter valid json"
        Ok v  -> case typeCheck argument v of
            NoError -> Ok v
            err     -> Err (typeErrorToString err)

argumentString : Model -> String
argumentString { currentArgument } = case currentArgument of
    Ok val  -> JE.encode 0 val
    Err err -> "<" ++ err ++ ">"
