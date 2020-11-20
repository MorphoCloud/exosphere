module Helpers.Interaction exposing (interactionDetails, interactionStatus, interactionStatusWordColor)

import Element
import FeatherIcons
import Helpers.Helpers as Helpers
import Helpers.RemoteDataPlusPlus as RDPP
import OpenStack.Types as OSTypes
import RemoteData
import Style.Widgets.Icon as Icon
import Time
import Types.Guacamole as GuacTypes
import Types.Interaction as ITypes
import Types.Types exposing (CockpitLoginStatus(..), Server, ServerOrigin(..), UserAppProxyHostname)


interactionStatus : Server -> ITypes.Interaction -> Bool -> Time.Posix -> Maybe UserAppProxyHostname -> ITypes.InteractionStatus
interactionStatus server interaction isElectron currentTime tlsReverseProxyHostname =
    let
        maybeFloatingIp =
            Helpers.getServerFloatingIp server.osProps.details.ipAddresses

        guacTerminal : ITypes.InteractionStatus
        guacTerminal =
            let
                guacUpstreamPort =
                    49528

                fifteenMinMillis =
                    1000 * 60 * 15

                newServer =
                    Helpers.serverLessThanThisOld server currentTime
            in
            case server.exoProps.serverOrigin of
                ServerNotFromExo ->
                    ITypes.Unavailable "Server not launched from Exosphere"

                ServerFromExo exoOriginProps ->
                    case exoOriginProps.guacamoleStatus of
                        GuacTypes.NotLaunchedWithGuacamole ->
                            if exoOriginProps.exoServerVersion < 3 then
                                ITypes.Unavailable "Server was created with an older version of Exosphere"

                            else
                                ITypes.Unavailable "Server was deployed with Guacamole support de-selected"

                        GuacTypes.LaunchedWithGuacamole guacProps ->
                            case guacProps.authToken.data of
                                RDPP.DoHave token _ ->
                                    case ( tlsReverseProxyHostname, maybeFloatingIp ) of
                                        ( Just proxyHostname, Just floatingIp ) ->
                                            ITypes.Ready <|
                                                Helpers.buildProxyUrl
                                                    proxyHostname
                                                    floatingIp
                                                    guacUpstreamPort
                                                    ("/guacamole/#/client/c2hlbGwAYwBkZWZhdWx0?token=" ++ token)
                                                    False

                                        ( Nothing, _ ) ->
                                            ITypes.Unavailable "Cannot find TLS-terminating reverse proxy server"

                                        ( _, Nothing ) ->
                                            ITypes.Unavailable "Server does not have a floating IP address"

                                RDPP.DontHave ->
                                    if newServer fifteenMinMillis then
                                        ITypes.Unavailable "Guacamole is still deploying to this new server, check back in a few minutes"

                                    else
                                        case
                                            ( tlsReverseProxyHostname
                                            , maybeFloatingIp
                                            , Helpers.getServerExouserPassword server.osProps.details
                                            )
                                        of
                                            ( Nothing, _, _ ) ->
                                                ITypes.Error "Cannot find TLS-terminating reverse proxy server"

                                            ( _, Nothing, _ ) ->
                                                ITypes.Error "Server does not have a floating IP address"

                                            ( _, _, Nothing ) ->
                                                ITypes.Error "Cannot find server password to authenticate"

                                            ( Just _, Just _, Just _ ) ->
                                                case guacProps.authToken.refreshStatus of
                                                    RDPP.Loading _ ->
                                                        ITypes.Loading

                                                    RDPP.NotLoading maybeErrorTuple ->
                                                        -- If deployment is complete but we can't get a token, show error to user
                                                        case maybeErrorTuple of
                                                            Nothing ->
                                                                -- This is a slight misrepresentation; we haven't requested
                                                                -- a token yet but orchestration code will make request soon
                                                                ITypes.Loading

                                                            Just ( error, _ ) ->
                                                                ITypes.Error
                                                                    ("Exosphere tried to authenticate to the Guacamole API, and received this error: "
                                                                        ++ Debug.toString error
                                                                    )

        cockpit : CockpitDashboardOrTerminal -> ITypes.InteractionStatus
        cockpit dashboardOrTerminal =
            if isElectron then
                case server.exoProps.serverOrigin of
                    ServerNotFromExo ->
                        ITypes.Unavailable "Server not launched from Exosphere"

                    ServerFromExo serverFromExoProps ->
                        case ( dashboardOrTerminal, serverFromExoProps.guacamoleStatus ) of
                            ( Terminal, GuacTypes.LaunchedWithGuacamole _ ) ->
                                ITypes.Hidden

                            _ ->
                                case ( serverFromExoProps.cockpitStatus, maybeFloatingIp ) of
                                    ( NotChecked, _ ) ->
                                        ITypes.Unavailable "Status of server dashboard and terminal not available yet"

                                    ( CheckedNotReady, _ ) ->
                                        ITypes.Unavailable "Not ready"

                                    ( _, Nothing ) ->
                                        ITypes.Unavailable "Server does not have a floating IP address"

                                    ( _, Just floatingIp ) ->
                                        case dashboardOrTerminal of
                                            Dashboard ->
                                                ITypes.Ready <|
                                                    "https://"
                                                        ++ floatingIp
                                                        ++ ":9090"

                                            Terminal ->
                                                ITypes.Ready <|
                                                    "https://"
                                                        ++ floatingIp
                                                        ++ ":9090/cockpit/@localhost/system/terminal.html"

            else
                ITypes.Hidden
    in
    case server.osProps.details.openstackStatus of
        OSTypes.ServerBuilding ->
            ITypes.Unavailable "Server is still building"

        OSTypes.ServerActive ->
            case interaction of
                ITypes.GuacTerminal ->
                    guacTerminal

                ITypes.GuacDesktop ->
                    -- not implemented yet
                    ITypes.Hidden

                ITypes.CockpitDashboard ->
                    cockpit Dashboard

                ITypes.CockpitTerminal ->
                    cockpit Terminal

                ITypes.NativeSSH ->
                    case maybeFloatingIp of
                        Nothing ->
                            ITypes.Unavailable "Server does not have a floating IP address"

                        Just floatingIp ->
                            ITypes.Ready <| "exouser@" ++ floatingIp

                ITypes.Console ->
                    case server.osProps.consoleUrl of
                        RemoteData.NotAsked ->
                            ITypes.Unavailable "Console URL is not queried yet"

                        RemoteData.Loading ->
                            ITypes.Loading

                        RemoteData.Failure error ->
                            ITypes.Error ("Exosphere requested a console URL and got the following error: " ++ Debug.toString error)

                        RemoteData.Success consoleUrl ->
                            ITypes.Ready consoleUrl

        _ ->
            ITypes.Unavailable "Server is not active"


interactionStatusWordColor : ITypes.InteractionStatus -> ( String, Element.Color )
interactionStatusWordColor status =
    case status of
        ITypes.Unavailable _ ->
            ( "Unavailable", Element.rgb255 122 122 122 )

        ITypes.Loading ->
            ( "Loading", Element.rgb255 255 221 87 )

        ITypes.Ready _ ->
            ( "Ready", Element.rgb255 35 209 96 )

        ITypes.Error _ ->
            ( "Error", Element.rgb255 255 56 96 )

        ITypes.Hidden ->
            ( "Hidden", Element.rgb255 200 200 200 )


interactionDetails : ITypes.Interaction -> ITypes.InteractionDetails msg
interactionDetails interaction =
    case interaction of
        ITypes.GuacTerminal ->
            ITypes.InteractionDetails
                "Web Terminal"
                "Get a terminal session to your server. Pro tip, press Ctrl+Alt+Shift inside the terminal window to show a graphical file upload/download tool!"
                (\_ _ -> FeatherIcons.terminal |> FeatherIcons.toHtml [] |> Element.html)
                ITypes.UrlInteraction

        ITypes.GuacDesktop ->
            ITypes.InteractionDetails
                "Streaming Desktop"
                "Interact with your server's desktop environment"
                (\_ _ -> FeatherIcons.monitor |> FeatherIcons.toHtml [] |> Element.html)
                ITypes.UrlInteraction

        ITypes.CockpitDashboard ->
            ITypes.InteractionDetails
                "Server Dashboard"
                "Deprecated feature"
                Icon.gauge
                ITypes.UrlInteraction

        ITypes.CockpitTerminal ->
            ITypes.InteractionDetails
                "Old Web Terminal"
                "Deprecated feature"
                (\_ _ -> FeatherIcons.terminal |> FeatherIcons.toHtml [] |> Element.html)
                ITypes.UrlInteraction

        ITypes.NativeSSH ->
            ITypes.InteractionDetails
                "Native SSH"
                "Advanced feature: use your computer's native SSH client to get a command-line session with extra capabilities"
                (\_ _ -> FeatherIcons.terminal |> FeatherIcons.toHtml [] |> Element.html)
                ITypes.TextInteraction

        ITypes.Console ->
            ITypes.InteractionDetails
                "Console"
                "Advanced feature: Launching the console is like connecting a screen, mouse, and keyboard to your server (useful for troubleshooting if the Web Terminal isn't working)"
                Icon.console
                ITypes.UrlInteraction


type CockpitDashboardOrTerminal
    = Dashboard
    | Terminal