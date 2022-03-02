module View.View exposing (view)

import Browser
import Element
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import FeatherIcons
import Helpers.GetterSetters as GetterSetters
import Helpers.String
import Html
import Page.FloatingIpAssign
import Page.FloatingIpList
import Page.GetSupport
import Page.HelpAbout
import Page.Home
import Page.ImageList
import Page.InstanceSourcePicker
import Page.KeypairCreate
import Page.KeypairList
import Page.LoginJetstream1
import Page.LoginOpenIdConnect
import Page.LoginOpenstack
import Page.LoginPicker
import Page.MessageLog
import Page.ProjectOverview
import Page.SelectProjectRegions
import Page.SelectProjects
import Page.ServerCreate
import Page.ServerCreateImage
import Page.ServerDetail
import Page.ServerList
import Page.ServerResize
import Page.Settings
import Page.Toast
import Page.VolumeAttach
import Page.VolumeCreate
import Page.VolumeDetail
import Page.VolumeList
import Page.VolumeMountInstructions
import Route
import Style.Helpers as SH exposing (shadowDefaults)
import Style.Toast
import Toasty
import Types.Error exposing (AppError)
import Types.HelperTypes exposing (ProjectIdentifier, WindowSize)
import Types.OuterModel exposing (OuterModel)
import Types.OuterMsg exposing (OuterMsg(..))
import Types.Project exposing (Project)
import Types.SharedModel exposing (SharedModel)
import Types.SharedMsg as SharedMsg exposing (SharedMsg(..))
import Types.View exposing (LoginView(..), NonProjectViewConstructor(..), ProjectViewConstructor(..), ViewState(..))
import View.Breadcrumb
import View.Helpers as VH
import View.Nav
import View.PageTitle
import View.Types
import Widget


view : Result AppError OuterModel -> Browser.Document OuterMsg
view resultModel =
    case resultModel of
        Err appError ->
            viewInvalid appError

        Ok model ->
            viewValid model


viewValid : OuterModel -> Browser.Document OuterMsg
viewValid outerModel =
    { title =
        View.PageTitle.pageTitle outerModel
    , body =
        [ view_ outerModel ]
    }


viewInvalid : AppError -> Browser.Document OuterMsg
viewInvalid appError =
    { title = "Error"
    , body = [ Element.text appError.error |> Element.layout [] ]
    }


view_ : OuterModel -> Html.Html OuterMsg
view_ outerModel =
    let
        { viewContext } =
            outerModel.sharedModel
    in
    Element.layout
        [ Font.size 17
        , Font.family
            [ Font.typeface "Open Sans"
            , Font.sansSerif
            ]
        , Font.color <| SH.toElementColor <| viewContext.palette.on.background
        , Background.color <| SH.toElementColor <| viewContext.palette.background
        ]
        (elementView viewContext.windowSize outerModel viewContext)


elementView : WindowSize -> OuterModel -> View.Types.Context -> Element.Element OuterMsg
elementView windowSize outerModel context =
    let
        mainContentContainerView =
            Element.column
                [ Element.padding 10
                , Element.alignTop
                , Element.width <|
                    Element.px windowSize.width
                , Element.height Element.fill
                , Element.scrollbars
                ]
                [ View.Breadcrumb.breadcrumb outerModel context
                    |> Element.map SharedMsg
                , case outerModel.viewState of
                    NonProjectView viewConstructor ->
                        case viewConstructor of
                            GetSupport pageModel ->
                                Page.GetSupport.view context outerModel.sharedModel pageModel
                                    |> Element.map GetSupportMsg

                            HelpAbout ->
                                Page.HelpAbout.view outerModel.sharedModel context

                            Home pageModel ->
                                Page.Home.view context outerModel.sharedModel pageModel
                                    |> Element.map HomeMsg

                            LoadingUnscopedProjects _ ->
                                -- TODO put a fidget spinner here
                                Element.text <|
                                    String.join " "
                                        [ "Loading"
                                        , context.localization.unitOfTenancy
                                            |> Helpers.String.pluralize
                                            |> Helpers.String.toTitleCase
                                        ]

                            Login loginView ->
                                case loginView of
                                    LoginOpenstack pageModel ->
                                        Page.LoginOpenstack.view context outerModel.sharedModel pageModel
                                            |> Element.map LoginOpenstackMsg

                                    LoginJetstream1 pageModel ->
                                        Page.LoginJetstream1.view context outerModel.sharedModel pageModel
                                            |> Element.map LoginJetstream1Msg

                                    LoginOpenIdConnect pageModel ->
                                        Page.LoginOpenIdConnect.view context outerModel.sharedModel pageModel
                                            |> Element.map SharedMsg

                            LoginPicker ->
                                Page.LoginPicker.view context outerModel.sharedModel
                                    |> Element.map LoginPickerMsg

                            MessageLog pageModel ->
                                Page.MessageLog.view context outerModel.sharedModel pageModel
                                    |> Element.map MessageLogMsg

                            PageNotFound ->
                                Element.text "Error: page not found. Perhaps you are trying to reach an invalid URL."

                            SelectProjectRegions pageModel ->
                                Page.SelectProjectRegions.view context outerModel.sharedModel pageModel
                                    |> Element.map SelectProjectRegionsMsg

                            SelectProjects pageModel ->
                                Page.SelectProjects.view context outerModel.sharedModel pageModel
                                    |> Element.map SelectProjectsMsg

                            Settings pageModel ->
                                Page.Settings.view context outerModel.sharedModel pageModel
                                    |> Element.map SettingsMsg

                    ProjectView projectName projectViewModel viewConstructor ->
                        case GetterSetters.projectLookup outerModel.sharedModel projectName of
                            Nothing ->
                                Element.text <|
                                    String.join " "
                                        [ "Oops!"
                                        , context.localization.unitOfTenancy
                                            |> Helpers.String.toTitleCase
                                        , "not found"
                                        ]

                            Just project_ ->
                                project
                                    outerModel.sharedModel
                                    context
                                    project_
                                    projectViewModel
                                    viewConstructor
                , Element.html
                    (Toasty.view Style.Toast.toastConfig
                        (Page.Toast.view context outerModel.sharedModel)
                        (\m -> SharedMsg <| ToastyMsg m)
                        outerModel.sharedModel.toasties
                    )
                ]
    in
    Element.row
        [ Element.padding 0
        , Element.spacing 0
        , Element.width Element.fill
        , Element.height <|
            Element.px windowSize.height
        ]
        [ Element.column
            [ Element.padding 0
            , Element.spacing 0
            , Element.width Element.fill
            , Element.height <|
                Element.px windowSize.height
            ]
            [ Element.el
                [ Border.shadow shadowDefaults
                , Element.width Element.fill
                ]
                (View.Nav.navBar outerModel context)
            , Element.el
                [ Element.padding 0
                , Element.spacing 0
                , Element.width Element.fill
                , Element.height <|
                    Element.px (windowSize.height - View.Nav.navBarHeight)
                ]
                mainContentContainerView
            ]
        ]


type alias ProjectViewModel =
    { createPopup : Bool
    }


project :
    SharedModel
    -> View.Types.Context
    -> Project
    -> ProjectViewModel
    -> Types.View.ProjectViewConstructor
    -> Element.Element OuterMsg
project model context p projectViewModel viewConstructor =
    let
        v =
            case viewConstructor of
                ProjectOverview pageModel ->
                    Page.ProjectOverview.view context p model.clientCurrentTime pageModel
                        |> Element.map ProjectOverviewMsg

                FloatingIpAssign pageModel ->
                    Page.FloatingIpAssign.view context p pageModel
                        |> Element.map FloatingIpAssignMsg

                FloatingIpList pageModel ->
                    Page.FloatingIpList.view context p pageModel
                        |> Element.map FloatingIpListMsg

                ImageList pageModel ->
                    Page.ImageList.view context p pageModel
                        |> Element.map ImageListMsg

                InstanceSourcePicker pageModel ->
                    Page.InstanceSourcePicker.view context p pageModel
                        |> Element.map InstanceSourcePickerMsg

                KeypairCreate pageModel ->
                    Page.KeypairCreate.view context pageModel
                        |> Element.map KeypairCreateMsg

                KeypairList pageModel ->
                    Page.KeypairList.view context p pageModel
                        |> Element.map KeypairListMsg

                ServerCreate pageModel ->
                    Page.ServerCreate.view context p pageModel
                        |> Element.map ServerCreateMsg

                ServerCreateImage pageModel ->
                    Page.ServerCreateImage.view context pageModel
                        |> Element.map ServerCreateImageMsg

                ServerDetail pageModel ->
                    Page.ServerDetail.view context p ( model.clientCurrentTime, model.timeZone ) pageModel
                        |> Element.map ServerDetailMsg

                ServerList pageModel ->
                    Page.ServerList.view context p model.clientCurrentTime pageModel
                        |> Element.map ServerListMsg

                ServerResize pageModel ->
                    Page.ServerResize.view context p pageModel
                        |> Element.map ServerResizeMsg

                VolumeAttach pageModel ->
                    Page.VolumeAttach.view context p pageModel
                        |> Element.map VolumeAttachMsg

                VolumeCreate pageModel ->
                    Page.VolumeCreate.view context p pageModel
                        |> Element.map VolumeCreateMsg

                VolumeDetail pageModel ->
                    Page.VolumeDetail.view context p pageModel
                        |> Element.map VolumeDetailMsg

                VolumeList pageModel ->
                    Page.VolumeList.view context p model.clientCurrentTime pageModel
                        |> Element.map VolumeListMsg

                VolumeMountInstructions pageModel ->
                    Page.VolumeMountInstructions.view context p pageModel
                        |> Element.map VolumeMountInstructionsMsg
    in
    Element.column
        (Element.width Element.fill
            :: VH.exoColumnAttributes
        )
        [ projectNav context p projectViewModel
        , v
        ]


projectNav : View.Types.Context -> Project -> ProjectViewModel -> Element.Element OuterMsg
projectNav context p projectViewModel =
    let
        edges =
            VH.edges

        removeText =
            String.join " "
                [ "Remove"
                , Helpers.String.toTitleCase context.localization.unitOfTenancy
                ]
    in
    Element.row [ Element.width Element.fill, Element.spacing 10, Element.paddingEach { edges | bottom = 10 } ]
        [ Element.el
            (VH.heading2 context.palette
                -- Removing bottom border from this heading because it runs into buttons to the right and looks weird
                -- Removing bottom padding to vertically align it with butttons
                -- Shrink heading width so that username can be shown right next to it
                ++ [ Border.width 0
                   , Element.padding 0
                   , Element.width Element.shrink
                   ]
            )
          <|
            Element.text <|
                VH.friendlyCloudName context p
                    ++ " - "
                    ++ p.auth.project.name
        , Element.paragraph
            [ Font.size 15
            , Element.alpha 0.75
            , Element.paddingEach { left = 5, top = 0, bottom = 0, right = 0 }
            ]
            [ Element.text "(logged in as "
            , Element.el [ Font.bold ] (Element.text p.auth.user.name)
            , Element.text ")"
            ]
        , Element.el
            [ Element.alignRight ]
          <|
            Widget.iconButton
                (SH.materialStyle context.palette).button
                { icon =
                    Element.row [ Element.spacing 10 ]
                        [ Element.text removeText
                        , FeatherIcons.logOut |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] |> Element.html |> Element.el []
                        ]
                , text = removeText
                , onPress =
                    Just <| SharedMsg <| SharedMsg.ProjectMsg (GetterSetters.projectIdentifier p) SharedMsg.RemoveProject
                }
        , Element.el
            [ Element.alignRight
            , Element.paddingEach
                { top = 0
                , right = 15
                , bottom = 0
                , left = 0
                }
            ]
            (createButton context (GetterSetters.projectIdentifier p) projectViewModel.createPopup)
        ]


createButton : View.Types.Context -> ProjectIdentifier -> Bool -> Element.Element OuterMsg
createButton context projectId expanded =
    let
        materialStyle =
            (SH.materialStyle context.palette).button

        buttonStyle =
            { materialStyle
                | container = Element.width Element.fill :: materialStyle.container
            }

        renderButton : Element.Element Never -> String -> Route.Route -> Element.Element OuterMsg
        renderButton icon_ text route =
            Element.link
                [ Element.width Element.fill
                ]
                { url = Route.toUrl context.urlPathPrefix route
                , label =
                    Widget.iconButton
                        buttonStyle
                        { icon =
                            Element.row
                                [ Element.spacing 10
                                , Element.width Element.fill
                                ]
                                [ Element.el [] icon_
                                , Element.text text
                                ]
                        , text =
                            text
                        , onPress =
                            Just <| SharedMsg <| SharedMsg.NoOp
                        }
                }

        dropdown =
            Element.column
                (VH.dropdownAttributes context)
                [ renderButton
                    (FeatherIcons.server |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] |> Element.html)
                    (context.localization.virtualComputer
                        |> Helpers.String.toTitleCase
                    )
                    (Route.ProjectRoute projectId <| Route.InstanceSourcePicker)
                , renderButton
                    (FeatherIcons.hardDrive |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] |> Element.html)
                    (context.localization.blockDevice
                        |> Helpers.String.toTitleCase
                    )
                    (Route.ProjectRoute projectId <| Route.VolumeCreate)
                , renderButton
                    (FeatherIcons.key |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] |> Element.html)
                    (context.localization.pkiPublicKeyForSsh
                        |> Helpers.String.toTitleCase
                    )
                    (Route.ProjectRoute projectId <| Route.KeypairCreate)
                ]

        ( attribs, icon ) =
            if expanded then
                ( [ Element.below dropdown ]
                , FeatherIcons.chevronUp
                )

            else
                ( []
                , FeatherIcons.chevronDown
                )
    in
    Element.column
        attribs
        [ Widget.iconButton
            (SH.materialStyle context.palette).primaryButton
            { text = "Create"
            , icon =
                Element.row
                    [ Element.spacing 5 ]
                    [ Element.text "Create"
                    , Element.el []
                        (icon
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml []
                            |> Element.html
                        )
                    ]
            , onPress =
                Just <|
                    SharedMsg <|
                        SharedMsg.ProjectMsg projectId <|
                            SharedMsg.ToggleCreatePopup
            }
        ]
