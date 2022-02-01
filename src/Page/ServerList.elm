module Page.ServerList exposing (Model, Msg, init, update, view)

import DateFormat.Relative
import Element
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import FeatherIcons
import Helpers.GetterSetters as GetterSetters
import Helpers.Helpers as Helpers
import Helpers.RemoteDataPlusPlus as RDPP
import Helpers.String
import OpenStack.Types as OSTypes
import Page.QuotaUsage
import Route
import Set
import Style.Helpers as SH
import Style.Widgets.DataList as DataList
import Style.Widgets.Icon as Icon
import Style.Widgets.StatusBadge as StatusBadge
import Time
import Types.Project exposing (Project)
import Types.Server exposing (Server, ServerOrigin(..))
import Types.SharedMsg as SharedMsg
import View.Helpers as VH
import View.Types
import Widget


type alias Model =
    { showHeading : Bool
    , dataListModel : DataList.Model
    }


type alias DeleteConfirmation =
    OSTypes.ServerUuid


type Msg
    = GotDeleteConfirm DeleteConfirmation
    | DataListMsg DataList.Msg
    | SharedMsg SharedMsg.SharedMsg
    | NoOp


init : Project -> Bool -> Model
init project showHeading =
    Model showHeading
        (DataList.init <| DataList.getDefaultFilterOptions (filters project.auth.user.name))


update : Msg -> Project -> Model -> ( Model, Cmd Msg, SharedMsg.SharedMsg )
update msg project model =
    case msg of
        GotDeleteConfirm serverId ->
            ( model
            , Cmd.none
            , SharedMsg.ProjectMsg (GetterSetters.projectIdentifier project) <|
                SharedMsg.ServerMsg serverId <|
                    SharedMsg.RequestDeleteServer False
            )

        DataListMsg dataListMsg ->
            ( { model
                | dataListModel =
                    DataList.update dataListMsg model.dataListModel
              }
            , Cmd.none
            , SharedMsg.NoOp
            )

        SharedMsg sharedMsg ->
            ( model, Cmd.none, sharedMsg )

        NoOp ->
            ( model, Cmd.none, SharedMsg.NoOp )


view : View.Types.Context -> Project -> Time.Posix -> Model -> Element.Element Msg
view context project currentTime model =
    let
        serverListContents =
            {- Resolve whether we have a loaded list of servers to display; if so, call rendering function serverList_ -}
            case ( project.servers.data, project.servers.refreshStatus ) of
                ( RDPP.DontHave, RDPP.NotLoading Nothing ) ->
                    Element.row [ Element.spacing 15 ]
                        [ Widget.circularProgressIndicator
                            (SH.materialStyle context.palette).progressIndicator
                            Nothing
                        , Element.text "Please wait..."
                        ]

                ( RDPP.DontHave, RDPP.NotLoading (Just ( httpErrorWithBody, _ )) ) ->
                    Element.paragraph
                        []
                        [ Element.text <|
                            String.concat
                                [ "Cannot display"
                                , context.localization.virtualComputer
                                    |> Helpers.String.pluralize
                                , ". Error message: " ++ Helpers.httpErrorToString httpErrorWithBody.error
                                ]
                        ]

                ( RDPP.DontHave, RDPP.Loading ) ->
                    Element.row [ Element.spacing 15 ]
                        [ Widget.circularProgressIndicator
                            (SH.materialStyle context.palette).progressIndicator
                            Nothing
                        , Element.text "Loading..."
                        ]

                ( RDPP.DoHave servers _, _ ) ->
                    if List.isEmpty servers then
                        Element.paragraph
                            []
                            [ Element.text <|
                                String.join " "
                                    [ "You don't have any"
                                    , context.localization.virtualComputer
                                        |> Helpers.String.pluralize
                                    , "yet, go create one!"
                                    ]
                            ]

                    else
                        let
                            deletionAction : Set.Set String -> Element.Element Msg
                            deletionAction =
                                \serverIds ->
                                    Element.el [ Element.alignRight ]
                                        (Widget.iconButton
                                            (SH.materialStyle context.palette).dangerButton
                                            { icon = Icon.remove (SH.toElementColor context.palette.on.error) 16
                                            , text = "Delete"
                                            , onPress =
                                                Just <|
                                                    SharedMsg
                                                        (SharedMsg.ProjectMsg (GetterSetters.projectIdentifier project)
                                                            (SharedMsg.RequestDeleteServers
                                                                (List.map stringToUuid
                                                                    (Set.toList serverIds)
                                                                )
                                                            )
                                                        )
                                            }
                                        )

                            serversList =
                                serverRecords context currentTime project servers
                        in
                        DataList.view
                            model.dataListModel
                            DataListMsg
                            context.palette
                            []
                            (serverView context project)
                            serversList
                            [ deletionAction ]
                            (filters project.auth.user.name)
    in
    Element.column [ Element.width Element.fill ]
        [ if model.showHeading then
            Element.row (VH.heading2 context.palette ++ [ Element.spacing 15 ])
                [ FeatherIcons.server |> FeatherIcons.toHtml [] |> Element.html |> Element.el []
                , Element.text <|
                    (context.localization.virtualComputer
                        |> Helpers.String.pluralize
                        |> Helpers.String.toTitleCase
                    )
                ]

          else
            Element.none
        , Element.column VH.contentContainer
            [ Page.QuotaUsage.view context Page.QuotaUsage.Full (Page.QuotaUsage.Compute project.computeQuota)
            , serverListContents
            ]
        ]


stringToUuid : String -> OSTypes.ServerUuid
stringToUuid =
    identity


type alias ServerRecord =
    DataList.DataRecord
        { name : String
        , statusColor : Element.Color
        , size : String
        , floatingIpAddress : Maybe String
        , creationTime : String
        , creator : String
        }


serverRecords :
    View.Types.Context
    -> Time.Posix
    -> Project
    -> List Server
    -> List ServerRecord
serverRecords context currentTime project servers =
    let
        serverStatusColors server =
            server
                |> VH.getServerUiStatus
                |> VH.getServerUiStatusBadgeState
                |> StatusBadge.toColors context.palette

        creatorName server =
            case server.exoProps.serverOrigin of
                ServerFromExo exoOriginProps ->
                    case exoOriginProps.exoCreatorUsername of
                        Just creatorUsername ->
                            creatorUsername

                        Nothing ->
                            "unknown user"

                _ ->
                    "unknown user"

        creationTimeStr server =
            DateFormat.Relative.relativeTime currentTime
                server.osProps.details.created

        floatingIpAddress server =
            List.head (GetterSetters.getServerFloatingIps project server.osProps.uuid)
                |> Maybe.map .address

        flavor server =
            GetterSetters.flavorLookup project server.osProps.details.flavorId
                |> Maybe.map .name
                |> Maybe.withDefault ("unknown " ++ context.localization.virtualComputerHardwareConfig)
    in
    List.map
        (\server ->
            { id = server.osProps.uuid
            , selectable = server.osProps.details.lockStatus == OSTypes.ServerUnlocked
            , name = server.osProps.name
            , statusColor = Tuple.first <| serverStatusColors server
            , size = flavor server
            , floatingIpAddress = floatingIpAddress server
            , creationTime = creationTimeStr server
            , creator = creatorName server
            }
        )
        servers


serverView : View.Types.Context -> Project -> ServerRecord -> Element.Element Msg
serverView context project serverRecord =
    let
        serverLink =
            Element.link []
                { url =
                    Route.toUrl context.urlPathPrefix
                        (Route.ProjectRoute (GetterSetters.projectIdentifier project) <|
                            Route.ServerDetail serverRecord.id
                        )
                , label =
                    Element.el
                        [ Font.size 18
                        , Font.color (SH.toElementColor context.palette.primary)
                        ]
                        (Element.text serverRecord.name)
                }

        interactionButton =
            Widget.iconButton
                (SH.materialStyle context.palette).button
                { text = "Connect to"
                , icon =
                    Element.row
                        [ Element.spacing 5 ]
                        [ Element.text "Connect to"
                        , Element.el []
                            (FeatherIcons.chevronDown
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                                |> Element.html
                            )
                        ]
                , onPress = Just NoOp
                }

        deleteServerButton =
            Widget.iconButton
                (SH.materialStyle context.palette).dangerButton
                { icon = Icon.remove (SH.toElementColor context.palette.on.error) 16
                , text = "Delete"
                , onPress =
                    if serverRecord.selectable then
                        Just <| GotDeleteConfirm serverRecord.id

                    else
                        -- to disable it
                        Nothing
                }

        floatingIpView =
            case serverRecord.floatingIpAddress of
                Just floatingIpAddress ->
                    Element.row [ Element.spacing 8 ]
                        [ Icon.ipAddress
                            (SH.toElementColorWithOpacity
                                context.palette.on.background
                                0.62
                            )
                            16
                        , Element.el [] (Element.text floatingIpAddress)
                        ]

                Nothing ->
                    Element.none
    in
    Element.column
        [ Element.spacing 12
        , Element.width Element.fill
        ]
        [ Element.row [ Element.spacing 10, Element.width Element.fill ]
            [ serverLink
            , Element.el
                [ Element.width (Element.px 12)
                , Element.height (Element.px 12)
                , Border.rounded 6
                , Background.color serverRecord.statusColor
                ]
                Element.none
            , Element.el [ Element.alignRight ] interactionButton
            , Element.el [ Element.alignRight ] deleteServerButton
            ]
        , Element.row
            [ Element.spacing 8
            , Element.width Element.fill
            , Font.color (SH.toElementColorWithOpacity context.palette.on.background 0.62)
            ]
            [ Element.el [] (Element.text serverRecord.size)
            , Element.text "·"
            , Element.paragraph []
                [ Element.text "created "
                , Element.el [ Font.color (SH.toElementColor context.palette.on.background) ]
                    (Element.text serverRecord.creationTime)
                , Element.text " by "
                , Element.el [ Font.color (SH.toElementColor context.palette.on.background) ]
                    (Element.text serverRecord.creator)
                ]
            , floatingIpView
            ]
        ]


filters :
    String
    ->
        List
            (DataList.Filter
                { record
                    | creator : String
                    , creationTime : String
                }
            )
filters currentUser =
    [ { id = "creator"
      , label = "Creator"
      , chipPrefix = "Created by "
      , filterOptions =
            \serversList ->
                List.map
                    (\creator ->
                        { text =
                            if creator == currentUser then
                                "me (" ++ creator ++ ")"

                            else
                                creator
                        , value = creator
                        }
                    )
                    (List.map .creator serversList |> Set.fromList |> Set.toList)
      , defaultFilterOptionValue = DataList.MultiselectOption <| Set.fromList [ currentUser ]
      , onFilter =
            \optionValue server ->
                server.creator == optionValue
      }
    ]
