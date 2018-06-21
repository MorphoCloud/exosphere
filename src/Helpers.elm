module Helpers exposing (processError, processOpenRc, providePasswordHint, providerNameFromUrl, serviceCatalogToEndpoints, getExternalNetwork, checkFloatingIpState, serverLookup, providerLookup, flavorLookup, imageLookup, modelUpdateProvider)

import Maybe.Extra
import Regex
import Time
import Toast exposing (Toast)
import Types.HelperTypes as HelperTypes
import Types.Types exposing (..)
import Types.OpenstackTypes as OpenstackTypes


processError : Model -> a -> ( Model, Cmd Msg )
processError model error =
    let
        errorString =
            toString error

        newMsgs =
            errorString :: model.messages

        newToastNotification =
            Toast.createNotification errorString (model.time + Time.second * 30)

        newToast =
            Toast.addNotification newToastNotification model.toast

        newModel =
            { model | messages = newMsgs, toast = newToast }
    in
        ( newModel, Cmd.none )


processOpenRc : Creds -> String -> Creds
processOpenRc existingCreds openRc =
    let
        regexes =
            { authUrl = Regex.regex "export OS_AUTH_URL=\"?([^\"\n]*)\"?"
            , projectDomain = Regex.regex "export OS_PROJECT_DOMAIN(?:_NAME|_ID)=\"?([^\"\n]*)\"?"
            , projectName = Regex.regex "export OS_PROJECT_NAME=\"?([^\"\n]*)\"?"
            , userDomain = Regex.regex "export OS_USER_DOMAIN_NAME=\"?([^\"\n]*)\"?"
            , username = Regex.regex "export OS_USERNAME=\"?([^\"\n]*)\"?"
            , password = Regex.regex "export OS_PASSWORD=\"(.*)\""
            }

        getMatch text regex =
            Regex.find (Regex.AtMost 1) regex text
                |> List.head
                |> Maybe.map (\x -> x.submatches)
                |> Maybe.andThen List.head
                |> Maybe.Extra.join

        newField regex oldField =
            getMatch openRc regex
                |> Maybe.withDefault oldField
    in
        Creds
            (newField regexes.authUrl existingCreds.authUrl)
            (newField regexes.projectDomain existingCreds.projectDomain)
            (newField regexes.projectName existingCreds.projectName)
            (newField regexes.userDomain existingCreds.userDomain)
            (newField regexes.username existingCreds.username)
            (newField regexes.password existingCreds.password)


providePasswordHint : String -> String -> List ( String, String )
providePasswordHint username password =
    let
        checks =
            [ (not <| String.isEmpty username)
            , (String.isEmpty password)
            , (username /= "demo")
            ]
    in
        if List.all (\p -> p) checks then
            [ ( "border-color", "rgba(239, 130, 17, 0.8)" )
            , ( "background-color", "rgba(245, 234, 234, 0.7)" )
            ]
        else
            []


providerNameFromUrl : HelperTypes.Url -> ProviderName
providerNameFromUrl url =
    let
        r =
            Regex.regex ".*\\/\\/(.*?)(:\\d+)?\\/"

        matches =
            Regex.find (Regex.AtMost 1) r url

        maybeMaybeName =
            matches
                |> List.head
                |> Maybe.map (\x -> x.submatches)
                |> Maybe.andThen List.head
    in
        case maybeMaybeName of
            Just (Just name) ->
                name

            _ ->
                "placeholder-url-unparseable"


serviceCatalogToEndpoints : OpenstackTypes.ServiceCatalog -> Endpoints
serviceCatalogToEndpoints catalog =
    Endpoints
        (getServicePublicUrl "glance" catalog)
        (getServicePublicUrl "nova" catalog)
        (getServicePublicUrl "neutron" catalog)


getServicePublicUrl : String -> OpenstackTypes.ServiceCatalog -> HelperTypes.Url
getServicePublicUrl serviceName catalog =
    let
        maybeService =
            getServiceFromCatalog serviceName catalog

        maybePublicEndpoint =
            getPublicEndpointFromService maybeService
    in
        case maybePublicEndpoint of
            Just endpoint ->
                endpoint.url

            Nothing ->
                ""


getServiceFromCatalog : String -> OpenstackTypes.ServiceCatalog -> Maybe OpenstackTypes.Service
getServiceFromCatalog serviceName catalog =
    List.filter (\s -> s.name == serviceName) catalog
        |> List.head


getPublicEndpointFromService : Maybe OpenstackTypes.Service -> Maybe OpenstackTypes.Endpoint
getPublicEndpointFromService maybeService =
    case maybeService of
        Just service ->
            List.filter (\e -> e.interface == OpenstackTypes.Public) service.endpoints
                |> List.head

        Nothing ->
            Nothing


getExternalNetwork : Provider -> Maybe Network
getExternalNetwork provider =
    List.filter (\n -> n.isExternal) provider.networks |> List.head


checkFloatingIpState : ServerDetails -> FloatingIpState -> FloatingIpState
checkFloatingIpState serverDetails floatingIpState =
    let
        hasFixedIp =
            List.filter (\a -> a.openstackType == Fixed) serverDetails.ipAddresses
                |> List.isEmpty
                |> not

        hasFloatingIp =
            List.filter (\a -> a.openstackType == Floating) serverDetails.ipAddresses
                |> List.isEmpty
                |> not

        isActive =
            serverDetails.status == "ACTIVE"
    in
        case floatingIpState of
            RequestedWaiting ->
                if hasFloatingIp then
                    Success
                else
                    RequestedWaiting

            Failed ->
                Failed

            _ ->
                if hasFloatingIp then
                    Success
                else if hasFixedIp && isActive then
                    Requestable
                else
                    NotRequestable


serverLookup : Provider -> ServerUuid -> Maybe Server
serverLookup provider serverUuid =
    List.filter (\s -> s.uuid == serverUuid) provider.servers |> List.head


providerLookup : Model -> ProviderName -> Maybe Provider
providerLookup model providerName =
    List.filter
        (\p -> p.name == providerName)
        (model.providers)
        |> List.head


flavorLookup : Provider -> FlavorUuid -> Maybe Flavor
flavorLookup provider flavorUuid =
    List.filter
        (\f -> f.uuid == flavorUuid)
        provider.flavors
        |> List.head


imageLookup : Provider -> ImageUuid -> Maybe Image
imageLookup provider imageUuid =
    List.filter
        (\i -> i.uuid == imageUuid)
        provider.images
        |> List.head


modelUpdateProvider : Model -> Provider -> Model
modelUpdateProvider model newProvider =
    let
        otherProviders =
            List.filter (\p -> p.name /= newProvider.name) model.providers

        newProviders =
            newProvider :: otherProviders
    in
        { model | providers = newProviders }