module OpenStack.DnsRecordSet exposing
    ( DnsRecordSet
    , RecordType
    , addressToRecord
    , fromStringToRecordType
    , lookupRecordsByAddress
    , recordTypeToString
    )

import List.Extra
import OpenStack.HelperTypes
import Set


type alias DnsRecordSet =
    { zone_id : OpenStack.HelperTypes.Uuid
    , zone_name : String
    , id : OpenStack.HelperTypes.Uuid
    , name : String
    , type_ : RecordType
    , ttl : Maybe Int
    , records : Set.Set String
    }


type RecordType
    = ARecord
    | PTRRecord
    | SOARecord
    | NSRecord
    | CNAMERecord


fromStringToRecordType : String -> Result String RecordType
fromStringToRecordType recordSet =
    case recordSet of
        "A" ->
            Ok ARecord

        "PTR" ->
            Ok PTRRecord

        "SOA" ->
            Ok SOARecord

        "NS" ->
            Ok NSRecord

        "CNAME" ->
            Ok CNAMERecord

        _ ->
            Err (recordSet ++ " is not valid")


recordTypeToString : RecordType -> String
recordTypeToString type_ =
    case type_ of
        ARecord ->
            "A"

        PTRRecord ->
            "PTR"

        SOARecord ->
            "SOA"

        NSRecord ->
            "NS"

        CNAMERecord ->
            "CNAME"


addressToRecord : List DnsRecordSet -> String -> Maybe DnsRecordSet
addressToRecord dnsRecordSets address =
    dnsRecordSets
        |> List.Extra.find
            (\{ records } ->
                records |> Set.toList |> List.member address
            )


lookupRecordsByAddress : List DnsRecordSet -> String -> List DnsRecordSet
lookupRecordsByAddress dnsRecordSets address =
    dnsRecordSets
        |> List.filter (.records >> Set.member address)
