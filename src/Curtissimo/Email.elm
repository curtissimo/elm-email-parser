module Curtissimo.Email exposing
    ( ParseOptions, defaultOptions
    , fromString, toString, validate
    , domain, local, plus, stem, removePlus
    , Email
    )

{-| This module provides an email address parsing implementation that complies
with

  - [RFC 2822 - Internet Message Format, Section 3.4.1 - **Addr-spec
    specification**](https://www.rfc-editor.org/rfc/rfc2822#section-3.4.1) (no
    comment support), and
  - [RFC 6533 - Internationalized Delivery Status and Disposition
    Notifications,
    Section 3 - **UTF-8 Address
    Type**](https://www.rfc-editor.org/rfc/rfc6533#section-3).

That's pretty cool, but not quite what most of us want from an email address
parser because it allows email addresses like `"this\@is/\vgreat"@[   foo  ]`.
(I _know_, right?)

So, the parser is configurable to allow you greater control over the whole weird
email address thing.


## The anatomy of an email address

**RFC 2822 - Internet Message Format** specifies that an email address has two
parts:

  - The _local_ part which is the stuff before the `@` symbol
  - The _domain_ part which is the stuff after the `@` symbol


### The _local_ part

**RFC 2822 - Internet Message Format** specifies two different formats for the
local part of an email address:

  - The _dot-atom_ format which is what you are most likely used to, like
    `firstName.lastName`
  - The _quoted-string_ format which is the Chaos Monkey of local parts letting
    you put pretty much anything between two double quotes, like
    `"this\@is/\vgreat"`


### Plus addressing

Many modern email providers allow you to perform so-called "plus addressing,"
where anything after a `+` symbol in the local part is completely ignored
when delivering the email. Thus, the emails `human@example.com` and
`human+adult@example.com` would deliver to the same mailbox.

This parser supports the identification of plus addressing. In the terminology
of this parser, the content before the `+` symbol is the _stem_ and the content
after the `+` symbols is the _plus_.


### The _domain_ part

**RFC 2822 - Internet Message Format** specifies two different formats for the
domain part of an email address:

  - The _dot-atom_ format which is what you are most likely used to, like
    `example.com`
  - The _domain-literal_ format which is the Chaos Monkey of domain parts
    letting you put pretty much anything between square brackets, like
    `[this         \bis/\vgreat\t]` (bells and vertical tabs, anyone?)


## Configuration

@docs ParseOptions, defaultOptions


## Use

@docs fromString, toString, validate


## Accessors and modifiers

@docs domain, local, plus, stem, removePlus


## Opaque types

@docs Email

-}

import Parser
    exposing
        ( (|.)
        , (|=)
        , Parser
        , Step(..)
        , andThen
        , chompIf
        , end
        , getChompedString
        , loop
        , map
        , oneOf
        , problem
        , run
        , succeed
        , symbol
        , token
        )
import Unicode


{-| The opaque type representing an email address.
-}
type Email
    = Email EmailParts


type alias EmailParts =
    { stem : String
    , plus : Maybe String
    , quoted : Bool
    , domain : String
    }


{-| Allows you to allow or prevent types of email parts or content when your
code converts a `String` to an [`Email`](#Email).

  - `allowDomainLiterals`: If set to `True`, then the parser will recognize
    what RFC 2822 refers to as "domain literals." A domain literal starts with
    a `[`, ends with an `]`, and allows letters, whitespace, and ASCII control
    characters between the square brackets.
  - `allowQuotedLocals`: If set to `True`, then the parser will recognize what
    RFC 2822 refers to as "quoted strings" as the local part of the email
    address. A quoted string starts and ends with `"` (double quotes), and
    allows letters, whitespace, and escaped letters between the quotes.
  - `allowUnicode`: If set to `True`, then the parser will allow Unicode
    alphanumeric characters in the local part and domain part.

-}
type alias ParseOptions =
    { allowDomainLiterals : Bool
    , allowQuotedLocals : Bool
    , allowUnicode : Bool
    }


{-| Provides a [`ParseOptions`](#ParseOptions) with all flags set to `False`
which is pretty sensible.
-}
defaultOptions : ParseOptions
defaultOptions =
    { allowDomainLiterals = False
    , allowQuotedLocals = False
    , allowUnicode = False
    }


{-| Returns the domain portion of an [`Email`](#Email).

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map domain
    --> Ok "example.org"

-}
domain : Email -> String
domain (Email parts) =
    parts.domain


domainPart : Bool -> (Char -> Bool) -> Parser String
domainPart allowDomainLiterals isAlphaNum =
    let
        domainPartChoices : List (Parser ())
        domainPartChoices =
            if allowDomainLiterals then
                [ domainLiteral isAlphaNum
                , dotAtom isAlphaNum
                ]

            else
                [ dotAtom isAlphaNum ]
    in
    oneOf domainPartChoices |> getChompedString


domainLiteral : (Char -> Bool) -> Parser ()
domainLiteral isAlphaNum =
    succeed ()
        |. token "["
        |. loop () (domainLiteralHelper isAlphaNum)
        |. token "]"


domainLiteralHelper : (Char -> Bool) -> () -> Parser (Step () ())
domainLiteralHelper isAlphaNum _ =
    oneOf
        [ foldableWhiteSpace |> map Loop
        , chompIf isDomainText |> map Loop
        , chompIf isNonWhiteSpaceControl |> map Loop
        , quotedPair isAlphaNum |> map Loop
        , succeed () |> map Done
        ]


dotAtom : (Char -> Bool) -> Parser ()
dotAtom isAlphaNum =
    succeed ()
        |. chompIf (isAtomText isAlphaNum)
        |. loop () (dotAtomText isAlphaNum)


dotAtomNoPlus : (Char -> Bool) -> Parser ()
dotAtomNoPlus isAlphaNum =
    succeed ()
        |. chompIf isAlphaNum
        |. loop () (dotAtomTextNoPlus isAlphaNum)


dotAtomText : (Char -> Bool) -> () -> Parser (Step () ())
dotAtomText isAlphaNum _ =
    oneOf
        [ chompIf (isAtomText isAlphaNum) |> map Loop
        , succeed ()
            |. chompIf (\c -> c == '.')
            |. chompIf (isAtomText isAlphaNum)
            |> map Loop
        , succeed () |> map Done
        ]


dotAtomTextNoPlus : (Char -> Bool) -> () -> Parser (Step () ())
dotAtomTextNoPlus isAlphaNum _ =
    oneOf
        [ chompIf (isAtomTextNoPlus isAlphaNum) |> map Loop
        , succeed ()
            |. chompIf (\c -> c == '.')
            |. chompIf (isAtomTextNoPlus isAlphaNum)
            |> map Loop
        , succeed () |> map Done
        ]


foldableWhiteSpace : Parser ()
foldableWhiteSpace =
    loop "" foldableWhiteSpaceHelper


foldableWhiteSpaceHelper : String -> Parser (Step String ())
foldableWhiteSpaceHelper content =
    oneOf
        [ succeed ()
            |. chompIf isCarriageReturn
            |. chompIf isLineFeed
            |. chompIf isWhiteSpace
            |> getChompedString
            |> map Loop
        , succeed ()
            |. chompIf isWhiteSpace
            |> getChompedString
            |> map Loop
        , succeed ()
            |> andThen
                (\_ ->
                    if String.isEmpty content then
                        problem "Did not find foldable white space"

                    else
                        succeed () |> map Done
                )
        ]


isAtomText : (Char -> Bool) -> Char -> Bool
isAtomText isAlphaNum c =
    isAtomTextNoPlus isAlphaNum c
        || (c == '+')


isAtomTextNoPlus : (Char -> Bool) -> Char -> Bool
isAtomTextNoPlus isAlphaNum c =
    isAlphaNum c
        || (c == '!')
        || (c == '#')
        || (c == '$')
        || (c == '%')
        || (c == '&')
        || (c == '\'')
        || (c == '*')
        || (c == '-')
        || (c == '/')
        || (c == '=')
        || (c == '?')
        || (c == '^')
        || (c == '_')
        || (c == '`')
        || (c == '{')
        || (c == '|')
        || (c == '}')
        || (c == '~')


isCarriageReturn : Char -> Bool
isCarriageReturn c =
    c == '\u{000D}'


isDomainText : Char -> Bool
isDomainText c =
    (c >= '!' && c <= 'Z') || (c >= '^' && c <= '~')


isNonWhiteSpaceControl : Char -> Bool
isNonWhiteSpaceControl c =
    let
        point : Int
        point =
            Char.toCode c
    in
    (point >= 1 && point <= 8)
        || (point >= 11 && point <= 12)
        || (point >= 14 && point <= 31)
        || (point == 127)


isQuotedPairSecondCharacter : Char -> Bool
isQuotedPairSecondCharacter c =
    let
        point : Int
        point =
            Char.toCode c
    in
    (point >= 1 && point <= 9)
        || (point >= 11 && point <= 12)
        || (point >= 14 && point <= 127)


{-| Converts a `String` to an [`Email`](#Email) using the provided
[`ParseOptions`](#ParseOptions).

If the input is invalid, returns a list of columnar positions where the parser
failed to recognize the input.

-}
fromString : ParseOptions -> String -> Result (List Int) Email
fromString options =
    (run <| parser options)
        >> Result.mapError (List.map (\deadEnd -> deadEnd.col))


isLineFeed : Char -> Bool
isLineFeed c =
    c == '\n'


isQuotedPlusText : (Char -> Bool) -> Char -> Bool
isQuotedPlusText isAlphaNum c =
    isAlphaNum c
        || (c == '!')
        || (c >= '#' && c < '\\')
        || (c > '\\' && c <= '~')


isQuotedStemText : (Char -> Bool) -> Char -> Bool
isQuotedStemText isAlphaNum c =
    isAlphaNum c
        || (c == '!')
        || (c >= '#' && c < '+')
        || (c > '+' && c < '\\')
        || (c > '\\' && c <= '~')


isWhiteSpace : Char -> Bool
isWhiteSpace c =
    c == ' ' || c == '\t'


{-| Returns the local portion of an [`Email`](#Email).

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map local
    --> Ok "person+adult"

-}
local : Email -> String
local (Email parts) =
    let
        stemAndPlus : String
        stemAndPlus =
            case parts.plus of
                Nothing ->
                    parts.stem

                Just plusPart ->
                    parts.stem ++ "+" ++ plusPart
    in
    if parts.quoted then
        "\"" ++ stemAndPlus ++ "\""

    else
        stemAndPlus


localPart : (Char -> Bool) -> Parser String
localPart isAlphaNum =
    dotAtomNoPlus isAlphaNum
        |> getChompedString


parser :
    { allowDomainLiterals : Bool
    , allowQuotedLocals : Bool
    , allowUnicode : Bool
    }
    -> Parser Email
parser options =
    let
        isAlphaNum : Char -> Bool
        isAlphaNum =
            if options.allowUnicode then
                Unicode.isAlphaNum

            else
                Char.isAlphaNum

        quotedLocals : List (Parser EmailParts)
        quotedLocals =
            if options.allowQuotedLocals then
                [ succeed EmailParts
                    |. chompIf (\c -> c == '"')
                    |= quotedStem isAlphaNum
                    |= oneOf
                        [ succeed identity
                            |. symbol "+"
                            |= oneOf
                                [ quotedPlus isAlphaNum
                                    |> getChompedString
                                    |> map Just
                                , succeed (Just "")
                                ]
                        , succeed Nothing
                        ]
                    |. chompIf (\c -> c == '"')
                    |= succeed True
                    |. symbol "@"
                    |= domainPart options.allowDomainLiterals isAlphaNum
                    |. end
                ]

            else
                []
    in
    oneOf
        ((succeed EmailParts
            |= localPart isAlphaNum
            |= oneOf
                [ succeed identity
                    |. symbol "+"
                    |= oneOf
                        [ dotAtom isAlphaNum
                            |> getChompedString
                            |> map Just
                        , succeed (Just "")
                        ]
                , succeed Nothing
                ]
            |= succeed False
            |. symbol "@"
            |= domainPart options.allowDomainLiterals isAlphaNum
            |. end
         )
            :: quotedLocals
        )
        |> map Email


{-| Returns the plus portion of an [`Email`](#Email).

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map plus
    --> Ok (Just "adult")

    "person@example.org"
        |> fromString defaultOptions
        |> Result.map plus
    --> Ok Nothing

-}
plus : Email -> Maybe String
plus (Email parts) =
    parts.plus


quotedPair : (Char -> Bool) -> Parser ()
quotedPair isAlphaNum =
    succeed ()
        |. chompIf (\c -> c == '\\')
        |. chompIf (\c -> isQuotedPairSecondCharacter c || isAlphaNum c)


quotedPlus : (Char -> Bool) -> Parser String
quotedPlus isAlphaNum =
    loop () (quotedPlusHelper isAlphaNum)
        |> getChompedString


quotedPlusHelper : (Char -> Bool) -> () -> Parser (Step () ())
quotedPlusHelper isAlphaNum _ =
    oneOf
        [ foldableWhiteSpace |> map Loop
        , chompIf (isQuotedPlusText isAlphaNum) |> map Loop
        , quotedPair isAlphaNum |> map Loop
        , succeed () |> map Done
        ]


quotedStem : (Char -> Bool) -> Parser String
quotedStem isAlphaNum =
    loop () (quotedStemHelper isAlphaNum)
        |> getChompedString


quotedStemHelper : (Char -> Bool) -> () -> Parser (Step () ())
quotedStemHelper isAlphaNum _ =
    oneOf
        [ foldableWhiteSpace |> map Loop
        , chompIf (isQuotedStemText isAlphaNum) |> map Loop
        , quotedPair isAlphaNum |> map Loop
        , succeed () |> map Done
        ]


{-| Returns an [`Email`](#Email) with the _plus_ portion removed.

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map removePlus
        |> Result.map toString
    --> Ok "person@example.org"

-}
removePlus : Email -> Email
removePlus (Email parts) =
    Email { parts | plus = Nothing }


{-| Returns the stem portion of an [`Email`](#Email).

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map stem
    --> Ok "person"

-}
stem : Email -> String
stem (Email parts) =
    parts.stem


{-| Converts an [`Email`](#Email) to a `String`.

    "person+adult@example.org"
        |> fromString defaultOptions
        |> Result.map toString
    --> Ok "person+adult@example.org"

-}
toString : Email -> String
toString email =
    local email ++ "@" ++ domain email


{-| A convenience function to validate an email address.

Returns the email address if it's valid. Returns `Nothing` otherwise.

    "person+adult@example.org"
        |> validate defaultOptions
    --> Just "person+adult@example.org"

    "person@adult@example.org"
        |> validate defaultOptions
    --> Nothing

-}
validate : ParseOptions -> String -> Maybe String
validate options =
    fromString options >> Result.map toString >> Result.toMaybe
