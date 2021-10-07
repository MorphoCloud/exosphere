module Page.SelectProjects exposing (Model, Msg(..), init, update, view)

import Element
import Element.Input as Input
import Helpers.GetterSetters as GetterSetters
import Helpers.String
import Helpers.Url as UrlHelpers
import OpenStack.Types as OSTypes
import Set
import Style.Helpers as SH
import Types.HelperTypes exposing (ProjectIdentifier, UnscopedProviderProject)
import Types.SharedModel exposing (SharedModel)
import Types.SharedMsg as SharedMsg
import View.Helpers as VH
import View.Types
import Widget


type alias Model =
    { providerKeystoneUrl : OSTypes.KeystoneUrl
    , selectedProjects : Set.Set ProjectIdentifier
    }


type Msg
    = GotBoxChecked ProjectIdentifier Bool
    | GotSubmit


init : OSTypes.KeystoneUrl -> Model
init keystoneUrl =
    { providerKeystoneUrl = keystoneUrl
    , selectedProjects = Set.empty
    }


update : Msg -> SharedModel -> Model -> ( Model, Cmd Msg, SharedMsg.SharedMsg )
update msg _ model =
    case msg of
        GotBoxChecked projectId checked ->
            let
                newSelectedProjects =
                    model.selectedProjects
                        |> (if checked then
                                Set.insert projectId

                            else
                                Set.remove projectId
                           )
            in
            ( { model | selectedProjects = newSelectedProjects }, Cmd.none, SharedMsg.NoOp )

        GotSubmit ->
            ( model
            , Cmd.none
            , SharedMsg.RequestProjectLoginFromProvider model.providerKeystoneUrl model.selectedProjects
            )


view : View.Types.Context -> SharedModel -> Model -> Element.Element Msg
view context sharedModel model =
    case GetterSetters.providerLookup sharedModel model.providerKeystoneUrl of
        Just provider ->
            let
                urlLabel =
                    UrlHelpers.hostnameFromUrl model.providerKeystoneUrl

                renderSuccessCase : List UnscopedProviderProject -> Element.Element Msg
                renderSuccessCase projects =
                    Element.column VH.formContainer <|
                        List.append
                            (List.map
                                (renderProject model.selectedProjects)
                                (VH.sortProjects projects)
                            )
                            [ Widget.textButton
                                (SH.materialStyle context.palette).primaryButton
                                { text = "Choose"
                                , onPress =
                                    Just GotSubmit
                                }
                            ]
            in
            Element.column (VH.exoColumnAttributes ++ [ Element.width Element.fill ])
                [ Element.el (VH.heading2 context.palette)
                    (Element.text <|
                        String.join " "
                            [ "Choose"
                            , context.localization.unitOfTenancy
                                |> Helpers.String.pluralize
                                |> Helpers.String.toTitleCase
                            , "for"
                            , urlLabel
                            ]
                    )
                , VH.renderWebData
                    context
                    provider.projectsAvailable
                    (context.localization.unitOfTenancy
                        |> Helpers.String.pluralize
                    )
                    renderSuccessCase
                ]

        Nothing ->
            Element.text "Provider not found"


renderProject : Set.Set ProjectIdentifier -> UnscopedProviderProject -> Element.Element Msg
renderProject selectedProjects project =
    let
        selected =
            Set.member project.project.uuid selectedProjects

        renderProjectLabel : UnscopedProviderProject -> Element.Element Msg
        renderProjectLabel p =
            let
                disabledMsg =
                    if p.enabled then
                        ""

                    else
                        " (disabled)"

                labelStr =
                    case p.description of
                        "" ->
                            p.project.name ++ disabledMsg

                        _ ->
                            p.project.name ++ " -- " ++ p.description ++ disabledMsg
            in
            Element.text labelStr
    in
    Input.checkbox []
        { checked = selected
        , onChange = GotBoxChecked project.project.uuid
        , icon =
            if project.enabled then
                Input.defaultCheckbox

            else
                \_ -> nullCheckbox
        , label = Input.labelRight [] (renderProjectLabel project)
        }


nullCheckbox : Element.Element msg
nullCheckbox =
    Element.el
        [ Element.width (Element.px 14)
        , Element.height (Element.px 14)
        ]
        Element.none