module Types.HelperTypes exposing
    ( CloudSpecificConfig
    , DefaultLoginView(..)
    , ExcludeFilter
    , FloatingIpAssignmentStatus(..)
    , FloatingIpOption(..)
    , FloatingIpReuseOption(..)
    , Hostname
    , HttpRequestMethod(..)
    , IPv4AddressPublicRoutability(..)
    , KeystoneHostname
    , Localization
    , Password
    , ProjectIdentifier
    , UnscopedProvider
    , UnscopedProviderProject
    , Url
    , UserAppProxyHostname
    , Uuid
    , WindowSize
    )

import OpenStack.Types as OSTypes
import RemoteData exposing (WebData)


type alias Url =
    String


type alias Hostname =
    String


type alias Uuid =
    String


type alias Password =
    String


type IPv4AddressPublicRoutability
    = PrivateRfc1918Space
    | PublicNonRfc1918Space


type alias UnscopedProvider =
    { authUrl : OSTypes.KeystoneUrl
    , token : OSTypes.UnscopedAuthToken
    , projectsAvailable : WebData (List UnscopedProviderProject)
    }


type alias UnscopedProviderProject =
    { project : OSTypes.NameAndUuid
    , description : String
    , domainId : Uuid
    , enabled : Bool
    }


type alias ProjectIdentifier =
    -- We use this when referencing a Project in a Msg (or otherwise passing through the runtime)
    Uuid


type
    FloatingIpOption
    -- Wait to see if server gets a fixed IP in publicly routable space
    = Automatic
      -- Use a floating IP as soon as we are able to do so
    | UseFloatingIp FloatingIpReuseOption FloatingIpAssignmentStatus
    | DoNotUseFloatingIp


type FloatingIpReuseOption
    = CreateNewFloatingIp
    | UseExistingFloatingIp OSTypes.IpAddressUuid


type FloatingIpAssignmentStatus
    = Unknown
      -- We need an active server with a port and an external network before we can assign a floating IP address
    | WaitingForResources
    | Attemptable
    | AttemptedWaiting


type HttpRequestMethod
    = Get
    | Post
    | Put
    | Delete


type DefaultLoginView
    = DefaultLoginOpenstack
    | DefaultLoginJetstream


type alias Localization =
    { openstackWithOwnKeystone : String
    , openstackSharingKeystoneWithAnother : String
    , unitOfTenancy : String
    , maxResourcesPerProject : String
    , pkiPublicKeyForSsh : String
    , virtualComputer : String
    , virtualComputerHardwareConfig : String
    , cloudInitData : String
    , commandDrivenTextInterface : String
    , staticRepresentationOfBlockDeviceContents : String
    , blockDevice : String
    , nonFloatingIpAddress : String
    , floatingIpAddress : String
    , publiclyRoutableIpAddress : String
    , graphicalDesktopEnvironment : String
    }


type alias WindowSize =
    { width : Int
    , height : Int
    }


type alias KeystoneHostname =
    Hostname


type alias CloudSpecificConfig =
    { userAppProxy : Maybe UserAppProxyHostname
    , imageExcludeFilter : Maybe ExcludeFilter
    , featuredImageNamePrefix : Maybe String
    }


type alias UserAppProxyHostname =
    Hostname


type alias ExcludeFilter =
    { filterKey : String
    , filterValue : String
    }
