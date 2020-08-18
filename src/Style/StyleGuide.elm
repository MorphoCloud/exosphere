module Style.StyleGuide exposing (main)

import Browser
import Color
import Element
import Element.Font as Font
import Element.Region as Region
import Set exposing (Set)
import Style.Theme exposing (Style)
import Style.Widgets.Button exposing (dangerButton, warningButton)
import Style.Widgets.Card exposing (badge, exoCard)
import Style.Widgets.ChipsFilter exposing (chipsFilter)
import Style.Widgets.CopyableText exposing (copyableText)
import Style.Widgets.Icon exposing (bell, question, remove, roundRect, timesCircle)
import Style.Widgets.IconButton exposing (chip)
import Style.Widgets.MenuItem exposing (MenuItemState(..), menuItem)
import Widget



{- When you create a new widget, add example usages to the `widgets` list here! -}


type Msg
    = ChipsFilterMsg Style.Widgets.ChipsFilter.ChipsFilterMsg
    | NoOp


widgets : (Msg -> msg) -> Style style msg -> Model -> List (Element.Element msg)
widgets msgMapper style model =
    [ Element.text "Style.Widgets.MenuItem.menuItem"
    , menuItem Active "Active menu item" Nothing
    , menuItem Inactive "Inactive menu item" Nothing
    , Element.text "Style.Widgets.Icon.roundRect"
    , roundRect (Element.rgb255 10 10 10) 40
    , Element.text "Style.Widgets.Icon.bell"
    , bell (Element.rgb255 10 10 10) 40
    , Element.text "Style.Widgets.Icon.question"
    , question (Element.rgb255 10 10 10) 40
    , Element.text "Style.Widgets.Icon.remove"
    , remove (Element.rgb255 10 10 10) 40
    , Element.text "Style.Widgets.Icon.timesCircle (black)"
    , timesCircle (Element.rgb255 10 10 10) 40
    , Element.text "Style.Widgets.Icon.timesCircle (white)"
    , timesCircle (Element.rgb255 255 255 255) 40
    , Element.text "Style.Widgets.Card.exoCard"
    , exoCard "Title" "Subtitle" (Element.text "Lorem ipsum dolor sit amet.")
    , Element.text "Style.Widgets.Card.badge"
    , badge "belongs to this project"
    , Element.text "Style.Widgets.Button.dangerButton"
    , Widget.textButton
        (dangerButton Style.Theme.exoPalette)
        { text = "Danger button", onPress = Just (msgMapper NoOp) }
    , Element.text "Style.Widgets.Button.warningButton"
    , Widget.textButton
        (warningButton Style.Theme.exoPalette (Color.rgb255 255 221 87))
        { text = "Warning button", onPress = Just (msgMapper NoOp) }
    , Element.text "Style.Widgets.CopyableText.CopyableText"
    , copyableText "foobar"
    , Element.text "Style.Widgets.IconButton.chip"
    , chip Nothing (Element.text "chip label")
    , Element.text "Style.Widgets.IconButton.chip (with badge)"
    , chip Nothing (Element.row [ Element.spacing 5 ] [ Element.text "ubuntu", badge "10" ])
    , Element.text "chipsFilter"
    , chipsFilter (ChipsFilterMsg >> msgMapper) style model.chipFilterModel
    ]


intro : List (Element.Element a)
intro =
    [ Element.el
        [ Region.heading 2, Font.size 22, Font.bold ]
        (Element.text "Exosphere Style Guide")
    , Element.paragraph
        []
        [ Element.text "This page demonstrates usage of Exosphere's UI widgets. "
        , Element.text "See also the style guide for elm-style-framework (TODO link to demo style guide)"
        ]
    ]



-- Playing with elm-ui-widgets below


options : List String
options =
    [ "Apple"
    , "Kiwi"
    , "Strawberry"
    , "Pineapple"
    , "Mango"
    , "Grapes"
    , "Watermelon"
    , "Orange"
    , "Lemon"
    , "Blueberry"
    , "Grapefruit"
    , "Coconut"
    , "Cherry"
    , "Banana"
    ]


type alias ChipFilterModel =
    { selected : Set String
    , textInput : String
    , options : List String
    }


type alias Model =
    { chipFilterModel : ChipFilterModel
    }


init : ( Model, Cmd Msg )
init =
    ( { chipFilterModel =
            { selected = Set.empty
            , textInput = ""
            , options = options
            }
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChipsFilterMsg (Style.Widgets.ChipsFilter.ToggleSelection string) ->
            let
                cfm =
                    model.chipFilterModel
            in
            ( { model
                | chipFilterModel =
                    { cfm
                        | selected =
                            model.chipFilterModel.selected
                                |> (if model.chipFilterModel.selected |> Set.member string then
                                        Set.remove string

                                    else
                                        Set.insert string
                                   )
                    }
              }
            , Cmd.none
            )

        ChipsFilterMsg (Style.Widgets.ChipsFilter.SetTextInput string) ->
            let
                cfm =
                    model.chipFilterModel
            in
            ( { model
                | chipFilterModel =
                    { cfm | textInput = string }
              }
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : (Msg -> msg) -> Style style msg -> Model -> Element.Element msg
view msgMapper style model =
    intro
        ++ widgets msgMapper style model
        |> Element.column
            [ Element.padding 10
            , Element.spacing 20
            ]


main : Program () Model Msg
main =
    Browser.element
        { init = always init
        , view = view identity Style.Theme.materialStyle >> Element.layout []
        , update = update
        , subscriptions = subscriptions
        }
