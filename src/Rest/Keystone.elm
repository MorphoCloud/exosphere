module Rest.Keystone exposing
    ( authTokenFromHeader
    , decodeAppCredential
    , decodeAuthTokenHelper
    , decodeScopedAuthToken
    , decodeScopedAuthTokenDetails
    , decodeUnscopedAuthToken
    , decodeUnscopedAuthTokenDetails
    , openstackEndpointDecoder
    , openstackEndpointInterfaceDecoder
    , openstackServiceDecoder
    , requestAppCredential
    , requestAuthTokenHelper
    , requestScopedAuthToken
    , requestUnscopedAuthToken
    , requestUnscopedProjects
    )

import Dict
import Error exposing (ErrorContext, ErrorLevel(..))
import Helpers.Helpers as Helpers
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import OpenStack.Types as OSTypes
import Rest.Helpers exposing (idOrName, iso8601StringToPosixDecodeError, keystoneUrlWithVersion, openstackCredentialedRequest, proxyifyRequest, resultToMsg)
import Time
import Types.HelperTypes as HelperTypes
import Types.Types
    exposing
        ( CockpitLoginStatus(..)
        , FloatingIpState(..)
        , HttpRequestMethod(..)
        , Msg(..)
        , NewServerNetworkOptions(..)
        , Project
        , ProjectSpecificMsgConstructor(..)
        , ProjectViewConstructor(..)
        , ServerOrigin(..)
        , UnscopedProvider
        , UnscopedProviderProject
        , ViewState(..)
        )
import Url



{- HTTP Requests -}


requestUnscopedAuthToken : Maybe HelperTypes.Url -> OSTypes.OpenstackLogin -> Cmd Msg
requestUnscopedAuthToken maybeProxyUrl creds =
    let
        requestBody =
            Encode.object
                [ ( "auth"
                  , Encode.object
                        [ ( "identity"
                          , Encode.object
                                [ ( "methods", Encode.list Encode.string [ "password" ] )
                                , ( "password"
                                  , Encode.object
                                        [ ( "user"
                                          , Encode.object
                                                [ ( "name", Encode.string creds.username )
                                                , ( "domain"
                                                  , Encode.object
                                                        [ ( idOrName creds.userDomain, Encode.string creds.userDomain )
                                                        ]
                                                  )
                                                , ( "password", Encode.string creds.password )
                                                ]
                                          )
                                        ]
                                  )
                                ]
                          )
                        ]
                  )
                ]

        errorContext =
            ErrorContext
                "log into OpenStack"
                ErrorCrit
                (Just "Make sure your login credentials including password are correct!")
    in
    requestAuthTokenHelper
        requestBody
        creds.authUrl
        maybeProxyUrl
        (resultToMsg errorContext (ReceiveUnscopedAuthToken creds.authUrl creds.password))


requestScopedAuthToken : Maybe HelperTypes.Url -> OSTypes.CredentialsForAuthToken -> Cmd Msg
requestScopedAuthToken maybeProxyUrl input =
    let
        requestBody =
            case input of
                OSTypes.AppCreds _ _ appCred ->
                    Encode.object
                        [ ( "auth"
                          , Encode.object
                                [ ( "identity"
                                  , Encode.object
                                        [ ( "methods", Encode.list Encode.string [ "application_credential" ] )
                                        , ( "application_credential"
                                          , Encode.object
                                                [ ( "id", Encode.string appCred.uuid )
                                                , ( "secret", Encode.string appCred.secret )
                                                ]
                                          )
                                        ]
                                  )
                                ]
                          )
                        ]

                OSTypes.PasswordCreds creds ->
                    Encode.object
                        [ ( "auth"
                          , Encode.object
                                [ ( "identity"
                                  , Encode.object
                                        [ ( "methods", Encode.list Encode.string [ "password" ] )
                                        , ( "password"
                                          , Encode.object
                                                [ ( "user"
                                                  , Encode.object
                                                        [ ( "name", Encode.string creds.username )
                                                        , ( "domain"
                                                          , Encode.object
                                                                [ ( idOrName creds.userDomain, Encode.string creds.userDomain )
                                                                ]
                                                          )
                                                        , ( "password", Encode.string creds.password )
                                                        ]
                                                  )
                                                ]
                                          )
                                        ]
                                  )
                                , ( "scope"
                                  , Encode.object
                                        [ ( "project"
                                          , Encode.object
                                                [ ( "name", Encode.string creds.projectName )
                                                , ( "domain"
                                                  , Encode.object
                                                        [ ( idOrName creds.projectDomain, Encode.string creds.projectDomain )
                                                        ]
                                                  )
                                                ]
                                          )
                                        ]
                                  )
                                ]
                          )
                        ]

        inputUrl =
            case input of
                OSTypes.PasswordCreds creds ->
                    creds.authUrl

                OSTypes.AppCreds url _ _ ->
                    url

        maybePassword =
            case input of
                OSTypes.PasswordCreds c ->
                    Just c.password

                _ ->
                    Nothing

        errorContext =
            let
                projectLabel =
                    case input of
                        OSTypes.AppCreds _ projectName _ ->
                            projectName

                        OSTypes.PasswordCreds creds ->
                            creds.projectName
            in
            ErrorContext
                ("log into OpenStack project named \"" ++ projectLabel ++ "\"")
                ErrorCrit
                (Just "Check with your cloud administrator to ensure you have access to this project.")
    in
    requestAuthTokenHelper
        requestBody
        inputUrl
        maybeProxyUrl
        (resultToMsg errorContext (ReceiveScopedAuthToken maybePassword))


requestAuthTokenHelper : Encode.Value -> HelperTypes.Url -> Maybe HelperTypes.Url -> (Result Http.Error ( Http.Metadata, String ) -> Msg) -> Cmd Msg
requestAuthTokenHelper requestBody authUrl maybeProxyUrl resultMsg =
    let
        correctedUrl =
            let
                maybeUrl =
                    Url.fromString authUrl
            in
            case maybeUrl of
                -- Cannot parse URL, so uh, don't make changes to it. We should never be here
                Nothing ->
                    authUrl

                Just url_ ->
                    { url_ | path = "/v3/auth/tokens" } |> Url.toString

        ( finalUrl, headers ) =
            case maybeProxyUrl of
                Nothing ->
                    ( correctedUrl, [] )

                Just proxyUrl ->
                    proxyifyRequest proxyUrl correctedUrl
    in
    {- https://stackoverflow.com/questions/44368340/get-request-headers-from-http-request -}
    Http.request
        { method = "POST"
        , headers = headers
        , url = finalUrl
        , body = Http.jsonBody requestBody

        {- Todo handle no response? -}
        , expect =
            Http.expectStringResponse
                resultMsg
                (\response ->
                    case response of
                        Http.BadUrl_ url_ ->
                            Err (Http.BadUrl url_)

                        Http.Timeout_ ->
                            Err Http.Timeout

                        Http.NetworkError_ ->
                            Err Http.NetworkError

                        Http.BadStatus_ metadata _ ->
                            Err (Http.BadStatus metadata.statusCode)

                        Http.GoodStatus_ metadata body ->
                            Ok ( metadata, body )
                )
        , timeout = Nothing
        , tracker = Nothing
        }


requestAppCredential : Project -> Time.Posix -> Cmd Msg
requestAppCredential project posixTime =
    let
        appCredentialName =
            "exosphere-" ++ (String.fromInt <| Time.posixToMillis posixTime)

        requestBody =
            Encode.object
                [ ( "application_credential"
                  , Encode.object
                        [ ( "name", Encode.string appCredentialName )
                        ]
                  )
                ]

        urlWithVersion =
            keystoneUrlWithVersion project.endpoints.keystone

        errorContext =
            ErrorContext
                ("request application credential for project named \"" ++ project.auth.project.name ++ "\"")
                ErrorCrit
                (Just "Perhaps you are trying to use a cloud that is too old to support Application Credentials? Exosphere supports OpenStack Queens release and newer. Check with your cloud administrator if you are unsure.")

        resultToMsg_ =
            resultToMsg
                errorContext
                (\appCred ->
                    ProjectMsg
                        (Helpers.getProjectId project)
                        (ReceiveAppCredential appCred)
                )
    in
    openstackCredentialedRequest
        project
        Post
        Nothing
        (urlWithVersion ++ "/users/" ++ project.auth.user.uuid ++ "/application_credentials")
        (Http.jsonBody requestBody)
        (Http.expectJson resultToMsg_ decodeAppCredential)


requestUnscopedProjects : UnscopedProvider -> Maybe HelperTypes.Url -> Cmd Msg
requestUnscopedProjects provider maybeProxyUrl =
    let
        correctedUrl =
            let
                maybeUrl =
                    Url.fromString provider.authUrl
            in
            case maybeUrl of
                -- Cannot parse URL, so uh, don't make changes to it. We should never be here
                Nothing ->
                    provider.authUrl

                Just url_ ->
                    { url_ | path = "/v3/users/" ++ provider.token.user.uuid ++ "/projects" } |> Url.toString

        ( url, headers ) =
            case maybeProxyUrl of
                Just proxyUrl ->
                    proxyifyRequest proxyUrl correctedUrl

                Nothing ->
                    ( correctedUrl, [] )

        errorContext =
            ErrorContext
                ("get a list of projects accessible by user \"" ++ provider.token.user.name ++ "\"")
                ErrorCrit
                Nothing

        resultToMsg_ =
            resultToMsg
                errorContext
                (ReceiveUnscopedProjects provider.authUrl)
    in
    Http.request
        { method = "GET"
        , headers = Http.header "X-Auth-Token" provider.token.tokenValue :: headers
        , url = url
        , body = Http.emptyBody
        , expect =
            Http.expectJson
                resultToMsg_
                decodeUnscopedProjects
        , timeout = Nothing
        , tracker = Nothing
        }



{- JSON Decoders -}


decodeUnscopedAuthToken : Http.Response String -> Result String OSTypes.UnscopedAuthToken
decodeUnscopedAuthToken response =
    decodeAuthTokenHelper response decodeUnscopedAuthTokenDetails


decodeUnscopedAuthTokenDetails : Decode.Decoder (OSTypes.AuthTokenString -> OSTypes.UnscopedAuthToken)
decodeUnscopedAuthTokenDetails =
    Decode.map3 OSTypes.UnscopedAuthToken
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "user", "name" ] Decode.string)
            (Decode.at [ "token", "user", "id" ] Decode.string)
        )
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "user", "domain", "name" ] Decode.string)
            (Decode.at [ "token", "user", "domain", "id" ] Decode.string)
        )
        (Decode.at [ "token", "expires_at" ] Decode.string
            |> Decode.andThen iso8601StringToPosixDecodeError
        )


decodeScopedAuthToken : Http.Response String -> Result String OSTypes.ScopedAuthToken
decodeScopedAuthToken response =
    decodeAuthTokenHelper response decodeScopedAuthTokenDetails


decodeScopedAuthTokenDetails : Decode.Decoder (OSTypes.AuthTokenString -> OSTypes.ScopedAuthToken)
decodeScopedAuthTokenDetails =
    Decode.map6 OSTypes.ScopedAuthToken
        (Decode.at [ "token", "catalog" ] (Decode.list openstackServiceDecoder))
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "project", "name" ] Decode.string)
            (Decode.at [ "token", "project", "id" ] Decode.string)
        )
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "project", "domain", "name" ] Decode.string)
            (Decode.at [ "token", "project", "domain", "id" ] Decode.string)
        )
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "user", "name" ] Decode.string)
            (Decode.at [ "token", "user", "id" ] Decode.string)
        )
        (Decode.map2
            OSTypes.NameAndUuid
            (Decode.at [ "token", "user", "domain", "name" ] Decode.string)
            (Decode.at [ "token", "user", "domain", "id" ] Decode.string)
        )
        (Decode.at [ "token", "expires_at" ] Decode.string
            |> Decode.andThen iso8601StringToPosixDecodeError
        )


openstackServiceDecoder : Decode.Decoder OSTypes.Service
openstackServiceDecoder =
    Decode.map3 OSTypes.Service
        (Decode.field "name" Decode.string)
        (Decode.field "type" Decode.string)
        (Decode.field "endpoints" (Decode.list openstackEndpointDecoder))


openstackEndpointDecoder : Decode.Decoder OSTypes.Endpoint
openstackEndpointDecoder =
    Decode.map2 OSTypes.Endpoint
        (Decode.field "interface" Decode.string
            |> Decode.andThen openstackEndpointInterfaceDecoder
        )
        (Decode.field "url" Decode.string)


openstackEndpointInterfaceDecoder : String -> Decode.Decoder OSTypes.EndpointInterface
openstackEndpointInterfaceDecoder interface =
    case interface of
        "public" ->
            Decode.succeed OSTypes.Public

        "admin" ->
            Decode.succeed OSTypes.Admin

        "internal" ->
            Decode.succeed OSTypes.Internal

        _ ->
            Decode.fail "unrecognized interface type"


decodeAuthTokenHelper : Http.Response String -> Decode.Decoder (OSTypes.AuthTokenString -> a) -> Result String a
decodeAuthTokenHelper response tokenDetailsDecoder =
    case response of
        Http.GoodStatus_ metadata body ->
            case Decode.decodeString tokenDetailsDecoder body of
                Ok tokenDetailsWithoutTokenString ->
                    case authTokenFromHeader metadata of
                        Ok authTokenString ->
                            Ok (tokenDetailsWithoutTokenString authTokenString)

                        Err errStr ->
                            Err errStr

                Err error ->
                    Err (Debug.toString error)

        Http.BadStatus_ _ body ->
            Err (Debug.toString body)

        _ ->
            Err (Debug.toString "foo")


authTokenFromHeader : Http.Metadata -> Result String String
authTokenFromHeader metadata =
    case Dict.get "X-Subject-Token" metadata.headers of
        Just token ->
            Ok token

        Nothing ->
            -- https://github.com/elm/http/issues/31
            case Dict.get "x-subject-token" metadata.headers of
                Just token2 ->
                    Ok token2

                Nothing ->
                    Err "Could not find an auth token in response headers"


decodeAppCredential : Decode.Decoder OSTypes.ApplicationCredential
decodeAppCredential =
    Decode.map2 OSTypes.ApplicationCredential
        (Decode.at [ "application_credential", "id" ] Decode.string)
        (Decode.at [ "application_credential", "secret" ] Decode.string)


decodeUnscopedProjects : Decode.Decoder (List UnscopedProviderProject)
decodeUnscopedProjects =
    Decode.field "projects" <|
        Decode.list unscopedProjectDecoder


unscopedProjectDecoder : Decode.Decoder UnscopedProviderProject
unscopedProjectDecoder =
    Decode.map4 UnscopedProviderProject
        (Decode.field "name" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "domain_id" Decode.string)
        (Decode.field "enabled" Decode.bool)