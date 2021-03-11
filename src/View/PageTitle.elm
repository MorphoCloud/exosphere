module View.PageTitle exposing (pageTitle)

import Helpers.GetterSetters as GetterSetters
import Helpers.String
import Helpers.Url as UrlHelpers
import OpenStack.Types as OSTypes
import Types.Types
    exposing
        ( LoginView(..)
        , Model
        , NonProjectViewConstructor(..)
        , Project
        , ProjectViewConstructor(..)
        , ViewState(..)
        )
import View.Helpers as VH
import View.Types


pageTitle : Model -> View.Types.Context -> String
pageTitle model context =
    case model.viewState of
        NonProjectView nonProjectViewConstructor ->
            case nonProjectViewConstructor of
                LoginPicker ->
                    "Log in"

                Login loginView ->
                    case loginView of
                        LoginOpenstack _ ->
                            "OpenStack Login"

                        LoginJetstream _ ->
                            "Jetstream Cloud Login"

                LoadingUnscopedProjects _ ->
                    String.join " "
                        [ "Loading"
                        , Helpers.String.pluralize context.localization.unitOfTenancy
                        ]

                SelectProjects keystoneUrl _ ->
                    let
                        providerTitle =
                            keystoneUrl
                                |> UrlHelpers.hostnameFromUrl
                                |> VH.titleFromHostname
                    in
                    String.join " "
                        [ "Select"
                        , context.localization.unitOfTenancy
                            |> Helpers.String.pluralize
                            |> Helpers.String.toTitleCase
                        , "for"
                        , providerTitle
                        ]

                MessageLog ->
                    "Message Log"

                Settings ->
                    "Settings"

                GetSupport _ _ _ ->
                    "Get Support"

                HelpAbout ->
                    "About " ++ model.style.appTitle

                PageNotFound ->
                    "Error: page not found"

        ProjectView projectIdentifier _ projectViewConstructor ->
            let
                maybeProject =
                    GetterSetters.projectLookup model projectIdentifier

                projectName =
                    maybeProject
                        |> Maybe.map (\p -> p.auth.project.name)
                        |> Maybe.withDefault
                            (String.join " "
                                [ "could not find"
                                , context.localization.unitOfTenancy
                                , "name"
                                ]
                            )
            in
            case projectViewConstructor of
                ListImages _ _ ->
                    String.join " "
                        [ context.localization.staticRepresentationOfBlockDeviceContents
                            |> Helpers.String.pluralize
                            |> Helpers.String.toTitleCase
                        , "for"
                        , projectName
                        ]

                ListProjectServers _ ->
                    String.join " "
                        [ context.localization.virtualComputer
                            |> Helpers.String.pluralize
                            |> Helpers.String.toTitleCase
                        , "for"
                        , projectName
                        ]

                ListProjectVolumes _ ->
                    String.join " "
                        [ context.localization.blockDevice
                            |> Helpers.String.pluralize
                            |> Helpers.String.toTitleCase
                        , "for"
                        , projectName
                        ]

                ListQuotaUsage ->
                    String.join " "
                        [ context.localization.maxResourcesPerProject
                            |> Helpers.String.toTitleCase
                        , "Usage for"
                        , projectName
                        ]

                ServerDetail serverUuid _ ->
                    String.join " "
                        [ context.localization.virtualComputer
                            |> Helpers.String.toTitleCase
                        , serverName maybeProject serverUuid
                        ]

                CreateServerImage serverUuid _ ->
                    String.join " "
                        [ "Create"
                        , context.localization.staticRepresentationOfBlockDeviceContents
                            |> Helpers.String.toTitleCase
                        , "for"
                        , serverName maybeProject serverUuid
                        ]

                VolumeDetail volumeUuid _ ->
                    String.join " "
                        [ context.localization.blockDevice
                            |> Helpers.String.toTitleCase
                        , volumeName maybeProject volumeUuid
                        ]

                CreateServer _ ->
                    String.join " "
                        [ "Create"
                        , context.localization.virtualComputer
                            |> Helpers.String.toTitleCase
                        ]

                CreateVolume _ _ ->
                    String.join " "
                        [ "Create"
                        , context.localization.blockDevice
                            |> Helpers.String.toTitleCase
                        ]

                AttachVolumeModal _ _ ->
                    String.join " "
                        [ "Attach"
                        , context.localization.blockDevice
                            |> Helpers.String.toTitleCase
                        ]

                MountVolInstructions _ ->
                    String.join " "
                        [ "Mount"
                        , context.localization.blockDevice
                            |> Helpers.String.toTitleCase
                        ]


serverName : Maybe Project -> OSTypes.ServerUuid -> String
serverName maybeProject serverUuid =
    maybeProject
        |> Maybe.andThen (\proj -> GetterSetters.serverLookup proj serverUuid)
        |> Maybe.map (\server -> server.osProps.name)
        |> Maybe.withDefault serverUuid


volumeName : Maybe Project -> OSTypes.VolumeUuid -> String
volumeName maybeProject volumeUuid =
    maybeProject
        |> Maybe.andThen (\proj -> GetterSetters.volumeLookup proj volumeUuid)
        |> Maybe.map (\vol -> vol.name)
        |> Maybe.withDefault volumeUuid
