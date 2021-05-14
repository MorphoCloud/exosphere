module View.FloatingIps exposing (assignFloatingIp, floatingIps)

import Element
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Helpers.GetterSetters as GetterSetters
import Helpers.RemoteDataPlusPlus as RDPP
import Helpers.String
import OpenStack.Types as OSTypes
import RemoteData
import Style.Helpers as SH
import Style.Widgets.Button
import Style.Widgets.Card
import Style.Widgets.CopyableText
import Style.Widgets.IconButton
import Types.Defaults as Defaults
import Types.Types
    exposing
        ( AssignFloatingIpViewParams
        , FloatingIpListViewParams
        , Msg(..)
        , Project
        , ProjectSpecificMsgConstructor(..)
        , ProjectViewConstructor(..)
        )
import View.Helpers as VH
import View.QuotaUsage
import View.Types
import Widget
import Widget.Style.Material


floatingIps : View.Types.Context -> Bool -> Project -> FloatingIpListViewParams -> (FloatingIpListViewParams -> Msg) -> Element.Element Msg
floatingIps context showHeading project viewParams toMsg =
    let
        renderFloatingIps : List OSTypes.IpAddress -> Element.Element Msg
        renderFloatingIps ips =
            let
                ipAssignedToServersWeKnowAbout ip =
                    case GetterSetters.getFloatingIpServer project ip.address of
                        Just _ ->
                            True

                        Nothing ->
                            False

                ( ipsAssignedToServers, ipsNotAssignedToServers ) =
                    List.partition ipAssignedToServersWeKnowAbout ips
            in
            if List.isEmpty ips then
                Element.column
                    (VH.exoColumnAttributes ++ [ Element.paddingXY 10 0 ])
                    [ Element.text <|
                        String.concat
                            [ "You don't have any "
                            , context.localization.floatingIpAddress
                                |> Helpers.String.pluralize
                            , " yet. They will be created when you launch "
                            , context.localization.virtualComputer
                                |> Helpers.String.indefiniteArticle
                            , " "
                            , context.localization.virtualComputer
                            , "."
                            ]
                    ]

            else
                Element.column
                    (VH.exoColumnAttributes
                        ++ [ Element.paddingXY 10 0, Element.width Element.fill ]
                    )
                <|
                    List.concat
                        [ List.map
                            (renderFloatingIpCard context project viewParams toMsg)
                            ipsNotAssignedToServers
                        , [ ipsAssignedToServersExpander context viewParams toMsg ipsAssignedToServers ]
                        , if viewParams.hideAssignedIps then
                            []

                          else
                            List.map (renderFloatingIpCard context project viewParams toMsg) ipsAssignedToServers
                        ]

        floatingIpsUsedCount =
            project.floatingIps
                -- Defaulting to 0 if not loaded yet, not the greatest factoring
                |> RemoteData.withDefault []
                |> List.length
    in
    Element.column
        [ Element.spacing 20, Element.width Element.fill ]
        [ if showHeading then
            Element.el VH.heading2 <|
                Element.text
                    (context.localization.floatingIpAddress
                        |> Helpers.String.pluralize
                        |> Helpers.String.toTitleCase
                    )

          else
            Element.none
        , View.QuotaUsage.floatingIpQuotaDetails context project.computeQuota floatingIpsUsedCount
        , VH.renderWebData
            context
            project.floatingIps
            (Helpers.String.pluralize context.localization.floatingIpAddress)
            renderFloatingIps
        ]


renderFloatingIpCard :
    View.Types.Context
    -> Project
    -> FloatingIpListViewParams
    -> (FloatingIpListViewParams -> Msg)
    -> OSTypes.IpAddress
    -> Element.Element Msg
renderFloatingIpCard context project viewParams toMsg ip =
    let
        subtitle =
            actionButtons context project toMsg viewParams ip

        cardBody =
            case GetterSetters.getFloatingIpServer project ip.address of
                Just server ->
                    Element.row [ Element.spacing 5 ]
                        [ Element.text <|
                            String.join " "
                                [ "Assigned to"
                                , context.localization.virtualComputer
                                , server.osProps.name
                                ]
                        , Style.Widgets.IconButton.goToButton
                            context.palette
                            (Just
                                (ProjectMsg project.auth.project.uuid <|
                                    SetProjectView <|
                                        ServerDetail server.osProps.uuid Defaults.serverDetailViewParams
                                )
                            )
                        ]

                Nothing ->
                    case ip.status of
                        Just OSTypes.IpAddressActive ->
                            Element.text "Active"

                        Just OSTypes.IpAddressDown ->
                            Element.text "Unassigned"

                        Just OSTypes.IpAddressError ->
                            Element.text "Status: Error"

                        Nothing ->
                            Element.none
    in
    Style.Widgets.Card.exoCard
        context.palette
        (Style.Widgets.CopyableText.copyableText
            context.palette
            [ Font.family [ Font.monospace ] ]
            ip.address
        )
        subtitle
        cardBody


actionButtons : View.Types.Context -> Project -> (FloatingIpListViewParams -> Msg) -> FloatingIpListViewParams -> OSTypes.IpAddress -> Element.Element Msg
actionButtons context project toMsg viewParams ip =
    let
        assignUnassignButton =
            let
                ( text, onPress ) =
                    case ( GetterSetters.getFloatingIpServer project ip.address, ip.uuid ) of
                        ( Nothing, Just ipUuid ) ->
                            ( "Assign"
                            , Just <|
                                ProjectMsg project.auth.project.uuid <|
                                    SetProjectView <|
                                        AssignFloatingIp (AssignFloatingIpViewParams (Just ipUuid) Nothing)
                            )

                        ( Nothing, Nothing ) ->
                            ( "Assign", Nothing )

                        ( Just _, Just ipUuid ) ->
                            ( "Unassign", Just <| ProjectMsg project.auth.project.uuid <| RequestUnassignFloatingIp ipUuid )

                        ( Just _, Nothing ) ->
                            ( "Unassign", Nothing )
            in
            Widget.textButton
                (Widget.Style.Material.outlinedButton (SH.toMaterialPalette context.palette))
                { text = text
                , onPress =
                    onPress
                }

        confirmationNeeded =
            List.member ip.address viewParams.deleteConfirmations

        deleteButton =
            if confirmationNeeded then
                Element.row [ Element.spacing 10 ]
                    [ Element.text "Confirm delete?"
                    , Widget.textButton
                        (Style.Widgets.Button.dangerButton context.palette)
                        { text = "Delete"
                        , onPress =
                            ip.uuid
                                |> Maybe.map
                                    (\uuid ->
                                        ProjectMsg
                                            project.auth.project.uuid
                                            (RequestDeleteFloatingIp uuid)
                                    )
                        }
                    , Widget.textButton
                        (Widget.Style.Material.outlinedButton (SH.toMaterialPalette context.palette))
                        { text = "Cancel"
                        , onPress =
                            Just <|
                                toMsg
                                    { viewParams
                                        | deleteConfirmations =
                                            List.filter
                                                ((/=) ip.address)
                                                viewParams.deleteConfirmations
                                    }
                        }
                    ]

            else
                Widget.textButton
                    (Style.Widgets.Button.dangerButton context.palette)
                    { text = "Delete"
                    , onPress =
                        Just <|
                            toMsg
                                { viewParams
                                    | deleteConfirmations =
                                        ip.address
                                            :: viewParams.deleteConfirmations
                                }
                    }
    in
    Element.row
        [ Element.width Element.fill ]
        [ Element.row [ Element.alignRight, Element.spacing 10 ] [ assignUnassignButton, deleteButton ] ]



-- TODO factor this out with onlyOwnExpander in ServerList.elm


ipsAssignedToServersExpander :
    View.Types.Context
    -> FloatingIpListViewParams
    -> (FloatingIpListViewParams -> Msg)
    -> List OSTypes.IpAddress
    -> Element.Element Msg
ipsAssignedToServersExpander context viewParams toMsg ipsAssignedToServers =
    let
        numIpsAssignedToServers =
            List.length ipsAssignedToServers

        statusText =
            let
                ( ipsPluralization, serversPluralization ) =
                    if numIpsAssignedToServers == 1 then
                        ( context.localization.floatingIpAddress
                        , String.join " "
                            [ context.localization.virtualComputer
                                |> Helpers.String.indefiniteArticle
                            , context.localization.virtualComputer
                            ]
                        )

                    else
                        ( Helpers.String.pluralize context.localization.floatingIpAddress
                        , Helpers.String.pluralize context.localization.virtualComputer
                        )
            in
            if viewParams.hideAssignedIps then
                String.concat
                    [ "Hiding "
                    , String.fromInt numIpsAssignedToServers
                    , " "
                    , ipsPluralization
                    , " assigned to "
                    , serversPluralization
                    ]

            else
                String.join " "
                    [ context.localization.floatingIpAddress
                        |> Helpers.String.pluralize
                        |> Helpers.String.toTitleCase
                    , "assigned to"
                    , context.localization.virtualComputer
                        |> Helpers.String.pluralize
                    ]

        ( ( changeActionVerb, changeActionIcon ), newServerListViewParams ) =
            if viewParams.hideAssignedIps then
                ( ( "Show", FeatherIcons.chevronDown )
                , { viewParams
                    | hideAssignedIps = False
                  }
                )

            else
                ( ( "Hide", FeatherIcons.chevronUp )
                , { viewParams
                    | hideAssignedIps = True
                  }
                )

        changeOnlyOwnMsg : Msg
        changeOnlyOwnMsg =
            toMsg newServerListViewParams

        changeButton =
            Widget.button
                (Widget.Style.Material.textButton (SH.toMaterialPalette context.palette))
                { onPress = Just changeOnlyOwnMsg
                , icon =
                    changeActionIcon
                        |> FeatherIcons.toHtml []
                        |> Element.html
                        |> Element.el []
                , text = changeActionVerb
                }
    in
    if numIpsAssignedToServers == 0 then
        Element.none

    else
        Element.column [ Element.spacing 3, Element.padding 0, Element.width Element.fill ]
            [ Element.el
                [ Element.centerX, Font.size 14 ]
                (Element.text statusText)
            , Element.el
                [ Element.centerX ]
                changeButton
            ]


assignFloatingIp : View.Types.Context -> Project -> AssignFloatingIpViewParams -> Element.Element Msg
assignFloatingIp context project viewParams =
    let
        serverChoices =
            project.servers
                |> RDPP.withDefault []
                |> List.filter
                    (\s ->
                        not <|
                            List.member s.osProps.details.openstackStatus
                                [ OSTypes.ServerSoftDeleted
                                , OSTypes.ServerError
                                , OSTypes.ServerBuilding
                                , OSTypes.ServerDeleted
                                ]
                    )
                |> List.map
                    (\s ->
                        Input.option s.osProps.uuid
                            (Element.text <| VH.possiblyUntitledResource s.osProps.name context.localization.virtualComputer)
                    )

        ipChoices =
            -- Show only un-assigned IP addresses for which we have a UUID
            project.floatingIps
                |> RemoteData.withDefault []
                |> List.filter (\ip -> ip.status == Just OSTypes.IpAddressDown)
                |> List.filter (\ip -> GetterSetters.getFloatingIpServer project ip.address == Nothing)
                |> List.filterMap
                    (\ip ->
                        ip.uuid |> Maybe.map (\uuid -> ( uuid, ip.address ))
                    )
                |> List.map
                    (\uuidAddressTuple ->
                        Input.option (Tuple.first uuidAddressTuple)
                            (Element.el [ Font.family [ Font.monospace ] ] <|
                                Element.text (Tuple.second uuidAddressTuple)
                            )
                    )
    in
    Element.column VH.exoColumnAttributes
        [ Element.el VH.heading2 <|
            Element.text <|
                String.join " "
                    [ "Assign"
                    , context.localization.floatingIpAddress
                        |> Helpers.String.toTitleCase
                    ]
        , Input.radio []
            { label =
                Input.labelAbove
                    [ Element.paddingXY 0 12 ]
                    (Element.text <|
                        String.join " "
                            [ "Select"
                            , Helpers.String.indefiniteArticle context.localization.virtualComputer
                            , context.localization.virtualComputer
                            ]
                    )
            , onChange =
                \new ->
                    ProjectMsg project.auth.project.uuid (SetProjectView (AssignFloatingIp { viewParams | serverUuid = Just new }))
            , options = serverChoices
            , selected = viewParams.serverUuid
            }
        , Input.radio []
            -- TODO if no floating IPs in list, suggest user create a floating IP and provide link to that view (once we build it)
            { label =
                Input.labelAbove [ Element.paddingXY 0 12 ]
                    (Element.text
                        (String.join " "
                            [ "Select"
                            , Helpers.String.indefiniteArticle context.localization.floatingIpAddress
                            , context.localization.floatingIpAddress
                            ]
                        )
                    )
            , onChange =
                \new ->
                    ProjectMsg project.auth.project.uuid (SetProjectView (AssignFloatingIp { viewParams | ipUuid = Just new }))
            , options = ipChoices
            , selected = viewParams.ipUuid
            }
        , let
            params =
                case ( viewParams.serverUuid, viewParams.ipUuid ) of
                    ( Just serverUuid, Just ipUuid ) ->
                        case ( GetterSetters.serverLookup project serverUuid, GetterSetters.floatingIpLookup project ipUuid ) of
                            ( Just server, Just floatingIp ) ->
                                let
                                    ipAssignedToServer =
                                        case GetterSetters.getServerFloatingIp server.osProps.details.ipAddresses of
                                            Just serverFloatingIp ->
                                                serverFloatingIp == floatingIp.address

                                            _ ->
                                                False

                                    maybePort =
                                        GetterSetters.getServerPort project server
                                in
                                case ( ipAssignedToServer, maybePort ) of
                                    ( True, _ ) ->
                                        { onPress = Nothing
                                        , warnText =
                                            Just <|
                                                String.join " "
                                                    [ "This"
                                                    , context.localization.floatingIpAddress
                                                    , "is already assigned to this"
                                                    , context.localization.virtualComputer
                                                    ]
                                        }

                                    ( _, Nothing ) ->
                                        { onPress = Nothing
                                        , warnText = Just <| "Error: cannot resolve port"
                                        }

                                    ( False, Just port_ ) ->
                                        -- Conditions are perfect
                                        { onPress =
                                            Just <|
                                                ProjectMsg project.auth.project.uuid (RequestAssignFloatingIp port_ ipUuid)
                                        , warnText = Nothing
                                        }

                            _ ->
                                {- Either server or floating IP cannot be resolved in the model -}
                                { onPress = Nothing
                                , warnText =
                                    Just <|
                                        String.join " "
                                            [ "Error: cannot resolve", context.localization.virtualComputer, "or", context.localization.floatingIpAddress ]
                                }

                    _ ->
                        {- User hasn't selected a server or floating IP yet so we keep the button disabled but don't yell at them -}
                        { onPress = Nothing
                        , warnText = Nothing
                        }

            button =
                Element.el [ Element.alignRight ] <|
                    Widget.textButton
                        (Widget.Style.Material.containedButton (SH.toMaterialPalette context.palette))
                        { text = "Assign"
                        , onPress = params.onPress
                        }
          in
          Element.row [ Element.width Element.fill ]
            [ case params.warnText of
                Just warnText ->
                    Element.el [ Font.color <| SH.toElementColor context.palette.error ] <| Element.text warnText

                Nothing ->
                    Element.none
            , button
            ]
        ]
