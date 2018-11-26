module Main exposing (main)

import Api exposing (..)
import Browser exposing (UrlRequest)
import Contracts exposing (..)
import Debug exposing (log)
import Delay
import Dict exposing (Dict)
import Json.Decode
import Json.Encode
import Modes exposing (..)
import Random
import Random.Char
import Random.String
import Set exposing (Set)
import Html exposing (Html, text, div)
import Html.Attributes exposing (class)
import Ui
import Ui.Action
import Ui.MetaData exposing (..)
import Animation
import Url exposing (Url)
import Url.Parser as UP
import Url.Parser exposing ((</>))
import Browser
import Browser exposing (UrlRequest, Document)
import Browser.Navigation exposing (Key)


main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- MODEL


type alias Model =
    { messages : List String
    , conn : Conn
    , mode : Mode
    , url : Url
    , contracts : Dict Int Contract
    , allProperties : Properties
    , fetchingContracts : Set Int
    , status : Status
    , ui : Ui.Model
    , key: Key
    , animationTime: Float
    }


init : Json.Encode.Value -> Url -> Key -> ( Model, Cmd Msg )
init _ url key = let model = emptyModel url key Connecting
    in (model , startCommand model)


startCommand : Model -> Cmd Msg
startCommand model =
    Cmd.batch
        [ nextPing
        , Api.connect "main" <| connectionUrl model.url
        ]


emptyModel : Url -> Key -> Status -> Model
emptyModel url key status =
    { messages = []
    , conn = "main"
    , mode = parseMode url
    , url = url
    , key = key
    , status = status
    , contracts = Dict.empty
    , allProperties = Dict.empty
    , fetchingContracts = Set.empty
    , ui = Ui.blank
    , animationTime = 0
    }

type Status
  = Connecting
  | Reconnecting
  | JollyGood

parseMode : Url -> Mode
parseMode url = UP.parse modeParser url |> Maybe.withDefault Basic

modeParser : UP.Parser (Mode -> a) a
modeParser = UP.fragment fragmentParser

fragmentParser : Maybe String -> Mode
fragmentParser s = case s of
    Just "advanced" -> Advanced
    _               -> Basic

connectionUrl : Url -> Conn
connectionUrl { host, port_ } =
    let authority = (case port_ of
            Nothing -> host
            (Just p)  -> host ++ ":" ++ (String.fromInt p))
    in
        ("ws://" ++ authority ++ "/ws")



-- UPDATE


type Msg
    = SocketMessage Api.Msg
    | SendPing
    | UrlChanged Url
    | UrlRequested UrlRequest
    | UiMsg Ui.Msg
    | Animate Float


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SocketMessage (Ok (_, resp)) ->
            handleResponse model resp
        SocketMessage (Err err) ->
            let
                errMsg = Debug.log "error" <|
                    "unable to parse response: " ++ err
            in
            ( { model | messages = errMsg :: model.messages }, Cmd.none )

        SendPing ->
            ( model, Cmd.batch [ sendPing model.conn, nextPing ] )

        UrlChanged url -> let newModel = emptyModel url model.key Connecting in
            ( newModel, startCommand newModel )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Browser.Navigation.pushUrl model.key (Url.toString url)
                    )

                Browser.External url ->
                    ( model
                    , Browser.Navigation.load url
                    )

        UiMsg uiMsg ->
            let
                ( newUi, cmd ) =
                    Ui.update (handleUiAction model) UiMsg uiMsg model.ui
            in
            ( { model | ui = newUi }, cmd )

        Animate time -> let diff = time - model.animationTime in
            ( { model | ui = Ui.animate (time, diff) model.ui, animationTime = time } , Cmd.none )


nextPing : Cmd Msg
nextPing =
    Delay.after 5 Delay.Second SendPing


handleUiAction : Model -> Int -> Ui.Action -> Cmd Msg
handleUiAction m id action =
    case action of
        Ui.Action.RequestCall { name, pid } argument token ->
            Api.unsafeCall m.conn
                { target = { destination = pid, data = emptyData }
                , name = name
                , argument = argument
                } (String.fromInt id ++ ":" ++ token)
        Ui.Action.RequestSet (pid, propertyID) value ->
            case m.allProperties |> fetch pid |> fetch propertyID |> (\x -> x.setter) of
                Just { name } ->
                    Api.setterCall m.conn
                        { target = delegate pid
                        , name = name
                        , argument = value
                        } (pid, propertyID)
                Nothing -> Cmd.none
        Ui.Action.RequestGet (pid, propertyID) value ->
            case m.allProperties |> fetch pid |> fetch propertyID |> (\x -> x.getter) of
                Just { name } ->
                    Api.getterCall m.conn
                        { target = delegate pid
                        , name = name
                        , argument = value
                        } (pid, propertyID)
                Nothing -> Cmd.none

handleResponse : Model -> Response -> ( Model, Cmd Msg )
handleResponse m resp =
    case resp of
        GotContract pid contract ->
            updateUiCmd <|
                let
                    ( newContract, properties ) =
                        propertify contract

                    ( newModel, newCommand ) =
                        checkMissing newContract
                            { m
                                | allProperties = Dict.insert pid properties m.allProperties
                                , contracts = Dict.insert pid newContract m.contracts
                                , fetchingContracts = Set.remove pid m.fetchingContracts
                            }
                in
                ( newModel
                , Cmd.batch
                    [ subscribeProperties m.conn pid properties
                    , newCommand
                    ]
                )

        UnsafeCallResult token value ->
            case String.split ":" token of
                [ h, t ] -> case String.toInt h of
                    Just id -> pushUiResult id (Ui.Action.CallResult value t) m
                    _ -> ( m, Cmd.none )
                _ -> ( m, Cmd.none )

        ValueResult ( pid, propertyID ) value ->
            updateUiProperty ( pid, propertyID ) <|
                ( { m
                    | allProperties =
                        m.allProperties
                            |> Dict.update pid
                                (Maybe.map <|
                                    Dict.update propertyID
                                        (Maybe.map <|
                                            setValue value
                                        )
                                )
                  }
                , Cmd.none
                )

        ChannelResult token chan ->
            ( m, subscribe m.conn chan token )

        SubscribedChannel token ->
            ( Debug.log (Json.Encode.encode 0 token) m, Cmd.none )

        PropertySetterStatus _ status ->
            ( Debug.log ("property setter status: " ++ Json.Encode.encode 0 status) m, Cmd.none )

        Pong ->
            ( m, Cmd.none )

        Hello ->
            ( emptyModel m.url m.key JollyGood, Api.getContract m.conn (delegate 0) )

        Connected ->
            ( emptyModel m.url m.key JollyGood, Cmd.none )

        Disconnected ->
            ( { m | status = Reconnecting }, Cmd.none )


subscribeProperties : Conn -> Pid -> ContractProperties -> Cmd Msg
subscribeProperties conn pid properties =
    Dict.toList properties
        |> List.map (subscribeProperty conn pid)
        |> Cmd.batch


subscribeProperty : Conn -> Pid -> ( PropertyID, Property ) -> Cmd Msg
subscribeProperty conn pid ( id, prop ) =
    case prop.subscriber of
        Nothing ->
            Cmd.none

        Just setter ->
            Cmd.batch
                [ subscriberCall conn
                    { target = delegate pid, name = setter.name, argument = Json.Encode.null }
                    ( pid, id )
                , case prop.getter of
                    Nothing ->
                        Cmd.none

                    Just getter ->
                        getterCall conn
                            { target = delegate pid, name = getter.name, argument = Json.Encode.null }
                            ( pid, id )
                ]


setValue : Json.Encode.Value -> Property -> Property
setValue v prop =
    case decodeValue v prop of
        Ok value ->
            { prop | value = Just value }

        Err _ ->
            { prop | value = Just <| Complex v }


decodeValue : Json.Encode.Value -> Property -> Result Json.Decode.Error Value
decodeValue v prop = Json.Decode.decodeValue
    (case stripType prop.propertyType of
        TFloat ->
            Json.Decode.float
                |> Json.Decode.map SimpleFloat
        TBool ->
            Json.Decode.bool
                |> Json.Decode.map SimpleBool
        TInt ->
            Json.Decode.int
                |> Json.Decode.map SimpleInt
        TString ->
            Json.Decode.string
                |> Json.Decode.map SimpleString
        _ ->
            Json.Decode.fail "unknown property type"
    ) v


checkMissing : Contract -> Model -> ( Model, Cmd Msg )
checkMissing c m =
    let
        missing =
            Set.diff (delegatePids c |> Set.fromList) m.fetchingContracts

        newModel =
            { m | fetchingContracts = Set.union m.fetchingContracts missing }

        command =
            missing |> Set.toList |> List.map delegate |> List.map (Api.getContract m.conn) |> Cmd.batch
    in
    ( newModel, command )


delegatePids : Contract -> List Int
delegatePids contract =
    case contract of
        MapContract d ->
            Dict.values d
                |> List.concatMap delegatePids

        ListContract l ->
            l |> List.concatMap delegatePids

        Delegate { destination } ->
            [ destination ]

        _ ->
            []


checkCallInput : String -> Maybe Json.Encode.Value
checkCallInput s =
    case Json.Decode.decodeString Json.Decode.value s of
        Ok v ->
            Just v

        _ ->
            Nothing


updateUi : Model -> Model
updateUi m =
    { m | ui = Ui.build 0 m.contracts m.allProperties }


updateUiCmd : ( Model, a ) -> ( Model, a )
updateUiCmd ( m, x ) =
    ( updateUi m, x )

pushUiResult : Int -> Ui.Action.ActionResult -> Model -> (Model, Cmd Msg)
pushUiResult id result m =
    let
        (uiModel, cmd) = Ui.pushResult (handleUiAction m) UiMsg id result m.ui
    in
        ( { m | ui = uiModel }, cmd )



updateUiProperty : ( Pid, PropertyID ) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updateUiProperty prop ( m, x ) =
    let
        ( uiModel, cmd ) =
            Ui.updateProperty (handleUiAction m) UiMsg prop m.allProperties m.ui
    in
    ( { m | ui = uiModel }, Cmd.batch [ x, cmd ] )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ = Sub.batch
    [ Api.subscriptions SocketMessage
    , Animation.times   Animate
    ]




-- VIEW

view : Model -> Document Msg
view model = Document
    "nice title"
    [ bodyView model ]

bodyView : Model -> Html Msg
bodyView model = case model.status of
    JollyGood ->
        let mode = case model.mode of
                Advanced -> "advanced"
                Basic    -> "basic"
        in
            div [ class ("mode-" ++ mode) ]
                [ Html.map UiMsg <| Ui.view model.ui
                ]
    Connecting ->
        div [] [ text "connecting" ]
    Reconnecting ->
        div [] [ text "reconnecting" ]

-- UTILS

justs : List (Maybe a) -> List a
justs l =
    case l of
        [] ->
            []

        (Just h) :: t ->
            h :: justs t

        Nothing :: t ->
            justs t



viewMessage : String -> Html msg
viewMessage msg =
    div [] [ text msg ]

stringFromBool : Bool -> String
stringFromBool b = case b of
    True -> "true"
    False -> "false"
