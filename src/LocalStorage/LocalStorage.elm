module LocalStorage.LocalStorage exposing
    ( decodeStoredState
    , generateStoredState
    , hydrateModelFromStoredState
    )

import Helpers.Helpers as Helpers
import Json.Decode as Decode
import Json.Encode as Encode
import LocalStorage.Types exposing (StoredProject, StoredProject1, StoredState)
import OpenStack.Types as OSTypes
import RemoteData
import Time
import Types.Types as Types


generateStoredState : Types.Model -> Encode.Value
generateStoredState model =
    let
        strippedProjects =
            List.map generateStoredProject model.projects
    in
    encodeStoredState
        { projects = strippedProjects
        , unscopedProviders = model.unscopedProviders
        }


generateStoredProject : Types.Project -> StoredProject
generateStoredProject project =
    { secret = project.secret
    , auth = project.auth
    }


hydrateModelFromStoredState : Types.Model -> StoredState -> Types.Model
hydrateModelFromStoredState model storedState =
    let
        projects =
            List.map hydrateProjectFromStoredProject storedState.projects

        viewState =
            case projects of
                [] ->
                    Types.NonProjectView Types.LoginPicker

                firstProject :: _ ->
                    Types.ProjectView (Helpers.getProjectId firstProject) Types.ListProjectServers
    in
    { model | projects = projects, viewState = viewState }


hydrateProjectFromStoredProject : StoredProject -> Types.Project
hydrateProjectFromStoredProject storedProject =
    { secret = storedProject.secret
    , auth = storedProject.auth
    , endpoints = Helpers.serviceCatalogToEndpoints storedProject.auth.catalog
    , images = []
    , servers = RemoteData.NotAsked
    , flavors = []
    , keypairs = []
    , volumes = RemoteData.NotAsked
    , networks = []
    , floatingIps = []
    , ports = []
    , securityGroups = []
    , pendingCredentialedRequests = []
    }



-- Encoders


encodeStoredState : StoredState -> Encode.Value
encodeStoredState storedState =
    let
        secretEncode : Types.ProjectSecret -> Encode.Value
        secretEncode secret =
            case secret of
                Types.OpenstackPassword p ->
                    Encode.object
                        [ ( "secretType", Encode.string "password" )
                        , ( "password", Encode.string p )
                        ]

                Types.ApplicationCredential appCred ->
                    Encode.object
                        [ ( "secretType", Encode.string "applicationCredential" )
                        , ( "appCredentialId", Encode.string appCred.uuid )
                        , ( "appCredentialSecret", Encode.string appCred.secret )
                        ]

        storedProjectEncode : StoredProject -> Encode.Value
        storedProjectEncode storedProject =
            Encode.object
                [ ( "secret", secretEncode storedProject.secret )
                , ( "auth", encodeAuthToken storedProject.auth )
                ]

        storedUnscopedProviderEncode : Types.UnscopedProvider -> Encode.Value
        storedUnscopedProviderEncode p =
            let
                unscopedAuthTokenEncode : OSTypes.UnscopedAuthToken -> Encode.Value
                unscopedAuthTokenEncode token =
                    Encode.object
                        [ ( "user", encodeNameAndUuid token.user )
                        , ( "userDomain", encodeNameAndUuid token.userDomain )
                        , ( "expiresAt", Encode.int (Time.posixToMillis token.expiresAt) )
                        , ( "tokenValue", Encode.string token.tokenValue )
                        ]

                unscopedProviderProjectEncode : Types.UnscopedProviderProject -> Encode.Value
                unscopedProviderProjectEncode project =
                    Encode.object
                        [ ( "name", Encode.string project.name )
                        , ( "description", Encode.string project.description )
                        , ( "domainId", Encode.string project.domainId )
                        ]
            in
            Encode.object
                [ ( "authUrl", Encode.string p.authUrl )
                , ( "token", unscopedAuthTokenEncode p.token )
                , ( "secret"
                  , case p.secret of
                        Just secret ->
                            Encode.string secret

                        Nothing ->
                            Encode.null
                  )
                , ( "projectsAvailable", Encode.list unscopedProviderProjectEncode p.projectsAvailable )
                ]
    in
    Encode.object
        [ ( "3"
          , Encode.object
                [ ( "projects", Encode.list storedProjectEncode storedState.projects )
                , ( "unscopedProviders", Encode.list storedUnscopedProviderEncode storedState.unscopedProviders )
                ]
          )
        ]


encodeAuthToken : OSTypes.ScopedAuthToken -> Encode.Value
encodeAuthToken authToken =
    Encode.object
        [ ( "catalog", encodeCatalog authToken.catalog )
        , ( "project"
          , Encode.object
                [ ( "name", Encode.string authToken.project.name )
                , ( "uuid", Encode.string authToken.project.uuid )
                ]
          )
        , ( "projectDomain"
          , Encode.object
                [ ( "name", Encode.string authToken.projectDomain.name )
                , ( "uuid", Encode.string authToken.projectDomain.uuid )
                ]
          )
        , ( "user"
          , Encode.object
                [ ( "name", Encode.string authToken.user.name )
                , ( "uuid", Encode.string authToken.user.uuid )
                ]
          )
        , ( "userDomain"
          , Encode.object
                [ ( "name", Encode.string authToken.userDomain.name )
                , ( "uuid", Encode.string authToken.userDomain.uuid )
                ]
          )
        , ( "expiresAt", Encode.int (Time.posixToMillis authToken.expiresAt) )
        , ( "tokenValue", Encode.string authToken.tokenValue )
        ]


encodeCatalog : OSTypes.ServiceCatalog -> Encode.Value
encodeCatalog serviceCatalog =
    Encode.list encodeService serviceCatalog


encodeService : OSTypes.Service -> Encode.Value
encodeService service =
    Encode.object
        [ ( "name", Encode.string service.name )
        , ( "type_", Encode.string service.type_ )
        , ( "endpoints", Encode.list encodeEndpoint service.endpoints )
        ]


encodeEndpoint : OSTypes.Endpoint -> Encode.Value
encodeEndpoint endpoint =
    Encode.object
        [ ( "interface", encodeEndpointInterface endpoint.interface )
        , ( "url", Encode.string endpoint.url )
        ]


encodeEndpointInterface : OSTypes.EndpointInterface -> Encode.Value
encodeEndpointInterface endpointInterface =
    let
        interfaceString =
            case endpointInterface of
                OSTypes.Public ->
                    "public"

                OSTypes.Admin ->
                    "admin"

                OSTypes.Internal ->
                    "internal"
    in
    Encode.string interfaceString


encodeNameAndUuid : OSTypes.NameAndUuid -> Encode.Value
encodeNameAndUuid x =
    Encode.object
        [ ( "name", Encode.string x.name )
        , ( "uuid", Encode.string x.uuid )
        ]



-- Decoders


decodeStoredState : Decode.Decoder StoredState
decodeStoredState =
    Decode.map2
        StoredState
        (Decode.oneOf
            [ Decode.at [ "0", "providers" ] (Decode.list storedProjectDecode1)
            , Decode.at [ "1", "projects" ] (Decode.list storedProjectDecode1)

            -- Added ApplicationCredential
            , Decode.at [ "2", "projects" ] (Decode.list storedProjectDecode)
            ]
        )
        (Decode.oneOf
            [ Decode.at [ "2", "unscopedProviders" ] (Decode.list unscopedProviderDecoder)
            , Decode.succeed []
            ]
        )


strToNameAndUuid : String -> OSTypes.NameAndUuid
strToNameAndUuid s =
    if Helpers.stringIsUuidOrDefault s then
        OSTypes.NameAndUuid "" s

    else
        OSTypes.NameAndUuid s ""


storedProject1ToStoredProject : StoredProject1 -> StoredProject
storedProject1ToStoredProject sp =
    let
        authToken =
            OSTypes.ScopedAuthToken
                sp.auth.catalog
                sp.auth.project
                sp.projDomain
                sp.auth.user
                sp.userDomain
                sp.auth.expiresAt
                sp.auth.tokenValue
    in
    StoredProject
        (Types.OpenstackPassword sp.password)
        authToken


storedProjectDecode1 : Decode.Decoder StoredProject
storedProjectDecode1 =
    Decode.map4 StoredProject1
        (Decode.at [ "creds", "password" ] Decode.string)
        (Decode.field "auth" decodeStoredAuthTokenDetails1)
        (Decode.map strToNameAndUuid <|
            Decode.at [ "creds", "projectDomain" ] Decode.string
        )
        (Decode.map strToNameAndUuid <|
            Decode.at [ "creds", "userDomain" ] Decode.string
        )
        |> Decode.map storedProject1ToStoredProject


storedProjectDecode : Decode.Decoder StoredProject
storedProjectDecode =
    Decode.map2 StoredProject
        (Decode.field "secret" decodeProjectSecret)
        (Decode.field "auth" decodeStoredAuthTokenDetails)


decodeProjectSecret : Decode.Decoder Types.ProjectSecret
decodeProjectSecret =
    let
        -- https://thoughtbot.com/blog/5-common-json-decoders#5---conditional-decoding-based-on-a-field
        projectSecretFromType : String -> Decode.Decoder Types.ProjectSecret
        projectSecretFromType typeStr =
            case typeStr of
                "password" ->
                    Decode.field "password" Decode.string |> Decode.map Types.OpenstackPassword

                "applicationCredential" ->
                    Decode.map2
                        OSTypes.ApplicationCredential
                        (Decode.field "appCredentialId" Decode.string)
                        (Decode.field "appCredentialSecret" Decode.string)
                        |> Decode.map Types.ApplicationCredential

                _ ->
                    Decode.fail <| "Invalid user type \"" ++ typeStr ++ "\". Must be either password or applicationCredential."
    in
    Decode.field "secretType" Decode.string |> Decode.andThen projectSecretFromType


decodeStoredAuthTokenDetails1 : Decode.Decoder OSTypes.ScopedAuthToken
decodeStoredAuthTokenDetails1 =
    Decode.map7 OSTypes.ScopedAuthToken
        (Decode.field "catalog" (Decode.list openstackStoredServiceDecoder))
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.field "projectName" Decode.string)
            (Decode.field "projectUuid" Decode.string)
        )
        -- Can't determine project domain name/uuid here so we populate empty
        (Decode.succeed <| OSTypes.NameAndUuid "" "")
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.field "username" Decode.string)
            (Decode.field "userUuid" Decode.string)
        )
        -- Can't determine user domain name/uuid here so we populate empty
        (Decode.succeed <| OSTypes.NameAndUuid "" "")
        (Decode.field "expiresAt" Decode.int
            |> Decode.map Time.millisToPosix
        )
        (Decode.field "tokenValue" Decode.string)


decodeStoredAuthTokenDetails : Decode.Decoder OSTypes.ScopedAuthToken
decodeStoredAuthTokenDetails =
    Decode.map7 OSTypes.ScopedAuthToken
        (Decode.field "catalog" (Decode.list openstackStoredServiceDecoder))
        (Decode.field "project" decodeNameAndId)
        (Decode.field "projectDomain" decodeNameAndId)
        (Decode.field "user" decodeNameAndId)
        (Decode.field "userDomain" decodeNameAndId)
        (Decode.field "expiresAt" Decode.int
            |> Decode.map Time.millisToPosix
        )
        (Decode.field "tokenValue" Decode.string)


openstackStoredServiceDecoder : Decode.Decoder OSTypes.Service
openstackStoredServiceDecoder =
    Decode.map3 OSTypes.Service
        (Decode.field "name" Decode.string)
        (Decode.field "type_" Decode.string)
        (Decode.field "endpoints" (Decode.list openstackStoredEndpointDecoder))


openstackStoredEndpointDecoder : Decode.Decoder OSTypes.Endpoint
openstackStoredEndpointDecoder =
    Decode.map2 OSTypes.Endpoint
        (Decode.field "interface" Decode.string
            |> Decode.andThen openstackStoredEndpointInterfaceDecoder
        )
        (Decode.field "url" Decode.string)


openstackStoredEndpointInterfaceDecoder : String -> Decode.Decoder OSTypes.EndpointInterface
openstackStoredEndpointInterfaceDecoder interface =
    case interface of
        "public" ->
            Decode.succeed OSTypes.Public

        "admin" ->
            Decode.succeed OSTypes.Admin

        "internal" ->
            Decode.succeed OSTypes.Internal

        _ ->
            Decode.fail "unrecognized interface type"


unscopedProviderDecoder : Decode.Decoder Types.UnscopedProvider
unscopedProviderDecoder =
    Decode.map4 Types.UnscopedProvider
        (Decode.field "authUrl" Decode.string)
        (Decode.field "token" unscopedAuthTokenDecoder)
        (Decode.field "secret" <| Decode.nullable Decode.string)
        (Decode.field "projectsAvailable" <| Decode.list unscopedProviderProjectDecoder)


unscopedAuthTokenDecoder : Decode.Decoder OSTypes.UnscopedAuthToken
unscopedAuthTokenDecoder =
    Decode.map4 OSTypes.UnscopedAuthToken
        (Decode.field "user" decodeNameAndId)
        (Decode.field "userDomain" decodeNameAndId)
        (Decode.field "expiresAt" Decode.int
            |> Decode.map Time.millisToPosix
        )
        (Decode.field "tokenValue" Decode.string)


unscopedProviderProjectDecoder : Decode.Decoder Types.UnscopedProviderProject
unscopedProviderProjectDecoder =
    Decode.map3 Types.UnscopedProviderProject
        (Decode.field "name" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "domainId" Decode.string)


decodeNameAndId : Decode.Decoder OSTypes.NameAndUuid
decodeNameAndId =
    Decode.map2 OSTypes.NameAndUuid
        (Decode.field "name" Decode.string)
        (Decode.field "uuid" Decode.string)
