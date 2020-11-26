module OpenStack.Quotas exposing
    ( computeQuotaDecoder
    , requestComputeQuota
    , requestVolumeQuota
    , volumeQuotaDecoder
    )

import Http
import Json.Decode as Decode
import OpenStack.Types as OSTypes
import Rest.Helpers exposing (expectJsonWithErrorBody, openstackCredentialedRequest, resultToMsgErrorBody)
import Types.Error exposing (ErrorContext, ErrorLevel(..))
import Types.Types
    exposing
        ( HttpRequestMethod(..)
        , Msg(..)
        , Project
        , ProjectSpecificMsgConstructor(..)
        )



-- Compute Quota


requestComputeQuota : Project -> Cmd Msg
requestComputeQuota project =
    let
        errorContext =
            ErrorContext
                "get details of compute quota"
                ErrorCrit
                Nothing

        resultToMsg_ =
            resultToMsgErrorBody
                errorContext
                (\quota ->
                    ProjectMsg
                        project.auth.project.uuid
                        (ReceiveComputeQuota quota)
                )
    in
    openstackCredentialedRequest
        project
        Get
        Nothing
        (project.endpoints.nova ++ "/limits")
        Http.emptyBody
        (expectJsonWithErrorBody
            resultToMsg_
            (Decode.field "limits" computeQuotaDecoder)
        )


computeQuotaDecoder : Decode.Decoder OSTypes.ComputeQuota
computeQuotaDecoder =
    Decode.map3 OSTypes.ComputeQuota
        (Decode.map2 OSTypes.QuotaItemDetail
            (Decode.at [ "absolute", "totalCoresUsed" ] Decode.int)
            (Decode.at [ "absolute", "maxTotalCores" ] specialIntToMaybe)
        )
        (Decode.map2 OSTypes.QuotaItemDetail
            (Decode.at [ "absolute", "totalInstancesUsed" ] Decode.int)
            (Decode.at [ "absolute", "maxTotalInstances" ] specialIntToMaybe)
        )
        (Decode.map2 OSTypes.QuotaItemDetail
            (Decode.at [ "absolute", "totalRAMUsed" ] Decode.int)
            (Decode.at [ "absolute", "maxTotalRAMSize" ] specialIntToMaybe)
        )



-- Volume Quota


requestVolumeQuota : Project -> Cmd Msg
requestVolumeQuota project =
    let
        errorContext =
            ErrorContext
                "get details of volume quota"
                ErrorCrit
                Nothing

        resultToMsg_ =
            resultToMsgErrorBody
                errorContext
                (\quota ->
                    ProjectMsg
                        project.auth.project.uuid
                        (ReceiveVolumeQuota quota)
                )
    in
    openstackCredentialedRequest
        project
        Get
        Nothing
        (project.endpoints.cinder ++ "/limits")
        Http.emptyBody
        (expectJsonWithErrorBody
            resultToMsg_
            (Decode.field "limits" volumeQuotaDecoder)
        )


volumeQuotaDecoder : Decode.Decoder OSTypes.VolumeQuota
volumeQuotaDecoder =
    Decode.map2 OSTypes.VolumeQuota
        (Decode.map2 OSTypes.QuotaItemDetail
            (Decode.at [ "absolute", "totalVolumesUsed" ] Decode.int)
            (Decode.at [ "absolute", "maxTotalVolumes" ] specialIntToMaybe)
        )
        (Decode.map2 OSTypes.QuotaItemDetail
            (Decode.at [ "absolute", "totalGigabytesUsed" ] Decode.int)
            (Decode.at [ "absolute", "maxTotalVolumeGigabytes" ] specialIntToMaybe)
        )



-- Helpers


specialIntToMaybe : Decode.Decoder (Maybe Int)
specialIntToMaybe =
    Decode.int
        |> Decode.map
            (\i ->
                if i == -1 then
                    Nothing

                else
                    Just i
            )
