module Style.Widgets.Text exposing (TextVariant(..), body, defaultFontFamily, defaultFontSize, fontWeightAttr, heading, headingStyleAttrs, mono, p, strong, subheading, subheadingStyleAttrs, text, typography, typographyAttrs, underline)

import Element
import Element.Border as Border
import Element.Font as Font exposing (Font)
import Element.Region as Region
import Style.Helpers as SH
import Style.Types exposing (ExoPalette)



--- model


{-| Font weight is (loosely) how "heavy" or "light" a font appears to us.

    Regular, Semibold, Bold, etc.

-}
type FontWeight
    = Regular
    | Semibold -- | Bold


{-| A typoghraphy captures the size, weight, etc. of fonts that we display.
-}
type alias Typography =
    { size : Int
    , weight : FontWeight
    }


{-| Text variants are the different typographies available to us.

    H1, H2, Body, etc.

-}
type TextVariant
    = H1
    | H2
    | H3
    | H4
    | Body
    | Strong



--- component


{-| Returns a typography object for the chosen variant.
-}
typography : TextVariant -> Typography
typography variant =
    case variant of
        H1 ->
            { size = 26
            , weight = Semibold
            }

        H2 ->
            { size = 24
            , weight = Semibold
            }

        H3 ->
            { size = 20
            , weight = Semibold
            }

        H4 ->
            { size = 17
            , weight = Semibold
            }

        Strong ->
            { size = 17
            , weight = Semibold
            }

        Body ->
            { size = 17
            , weight = Regular
            }


{-| Returns an element attribute for chosen font weight.
-}
fontWeightAttr : FontWeight -> Element.Attribute msg
fontWeightAttr weight =
    case weight of
        Regular ->
            Font.regular

        Semibold ->
            Font.semiBold


{-| Element attribute for the default font family list.
-}
defaultFontFamily : Element.Attribute msg
defaultFontFamily =
    Font.family
        (Font.typeface "Open Sans"
            :: systemFonts
        )


{-| System fonts for common browsers & operating systems.
-}
systemFonts : List Font
systemFonts =
    [ Font.typeface "-apple-system"
    , Font.typeface "BlinkMacSystemFont"
    , Font.typeface "Segoe UI"
    , Font.typeface "Roboto"
    , Font.typeface "Oxygen"
    , Font.typeface "Ubuntu"
    , Font.typeface "Cantarell"
    , Font.typeface "Fira Sans"
    , Font.typeface "Droid Sans"
    , Font.typeface "Helvetica Neue"
    , Font.sansSerif
    ]


{-| Element attribute for normal body text size.
-}
defaultFontSize : Element.Attribute msg
defaultFontSize =
    Font.size (typography Body).size


{-| Creates element attributes for the given typography.

    typographyAttrs H1

    or

    typographyAttrs Body

-}
typographyAttrs : TextVariant -> List (Element.Attribute msg)
typographyAttrs variant =
    let
        typo =
            typography variant
    in
    [ Font.size typo.size
    , fontWeightAttr typo.weight
    ]


{-| Returns element attributes for standard headings, including element spacing & a border.
-}
headingStyleAttrs : ExoPalette -> List (Element.Attribute msg)
headingStyleAttrs palette =
    [ Region.heading 2
    , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
    , Border.color (palette.neutral.border |> SH.toElementColor)
    , Element.width Element.fill
    , Element.paddingEach { bottom = 8, left = 0, right = 0, top = 0 }
    , Element.spacing 12
    ]


{-| Returns element attributes for standard subheadings, including element spacing & a border.
-}
subheadingStyleAttrs : ExoPalette -> List (Element.Attribute msg)
subheadingStyleAttrs palette =
    [ Region.heading 3
    , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
    , Border.color (palette.neutral.border |> SH.toElementColor)
    , Element.width Element.fill
    , Element.paddingEach { bottom = 8, left = 0, right = 0, top = 0 }
    , Element.spacing 12
    ]


{-| Display a paragraph element with typography defaults for body text & line spacing.

    Text.p []
        [ Text.body "Hello, "
        , Text.strong "World"
        , Element.text "!"
        ]

-}
p : List (Element.Attribute msg) -> List (Element.Element msg) -> Element.Element msg
p styleAttrs lines =
    Element.paragraph
        (Element.spacing 8
            :: typographyAttrs Body
            ++ styleAttrs
        )
        lines


{-| Display a text element using a predefined typography variant.

    Text.text Text.Body
        []
        "Hello, World!"

-}
text : TextVariant -> List (Element.Attribute msg) -> String -> Element.Element msg
text variant styleAttrs label =
    Element.el
        (typographyAttrs variant
            ++ styleAttrs
        )
        (Element.text label)



--- helpers


{-| A convience method for showing body text.

    Text.body "Welcome back."

-}
body : String -> Element.Element msg
body label =
    text Body [] label


{-| A convience method for showing strong text (that uses semiBold font weight).

    Text.strong "Hello!"

-}
strong : String -> Element.Element msg
strong label =
    text Strong [] label


{-| A convience method for monospace text.

    Text.mono "198.123.0.1"

-}
mono : String -> Element.Element msg
mono label =
    text Body [ Font.family [ Font.monospace ] ] label


{-| A convience method for underlined body text.

    Text.underline "Emphasis is important."

-}
underline : String -> Element.Element msg
underline label =
    text Body
        [ Border.widthEach
            { bottom = 1
            , left = 0
            , top = 0
            , right = 0
            }
        ]
        label


{-| Shows an underlined top-level heading (using H2 typography) with an optional icon.

    Text.heading context.palette [] Element.none "App Config Info"

    or

    Text.heading context.palette
        []
        (FeatherIcons.helpCircle
            |> FeatherIcons.toHtml []
            |> Element.html
            |> Element.el []
        )
        "Get Support"

-}
heading : ExoPalette -> List (Element.Attribute msg) -> Element.Element msg -> String -> Element.Element msg
heading palette styleAttrs icon label =
    Element.row
        (headingStyleAttrs palette
            ++ styleAttrs
        )
        [ icon
        , text H2 [] label
        ]


{-| Shows an underlined second-level heading (using H3 typography) with an optional icon.

    Text.subheading context.palette
        [ Element.width Element.shrink ]
        Element.none
        "Status"

    or

    Text.subheading context.palette
        [ Element.paddingEach { bottom = 0, left = 0, right = 0, top = 0 }
        , Border.width 0
        ]
        (FeatherIcons.server
            |> FeatherIcons.toHtml []
            |> Element.html
            |> Element.el []
        )
        "Server A"

-}
subheading : ExoPalette -> List (Element.Attribute msg) -> Element.Element msg -> String -> Element.Element msg
subheading palette styleAttrs icon label =
    Element.row
        (subheadingStyleAttrs palette
            ++ styleAttrs
        )
        [ icon
        , text H3 [] label
        ]