# Curtissimo.Email

[![Pipeline](https://gitlab.com/curtissimo/elm-email-parser/badges/main/pipeline.svg?ignore_skipped=true)](https://gitlab.com/curtissimo/elm-email-parser/-/pipelines/latest)

RFC-2822- and RFC-6533-compliant email parsing and validation.

Check out the [live example](https://curtissimo.gitlab.io/elm-email-parser).
Source for the examples can be found in the
[`./examples`](https://gitlab.com/curtissimo/elm-email-parser/-/tree/main/examples)
directory.

## Design Goals

Recognizing email addresses is a thankless task. This libraries goals are to

- Recognize "ordinary" email addresses such as `person@example.org`
- Allow for "exotic" email addresses with
  - Unicode characters, such as `ρεrso𐭹@example.org`,
  - quoted locals, such as `"per\tson"@example.org"`, or
  - domain literals, such as  `person@[e x a m p l e . o r g]`
- Be able to identify "plus addressing" in email addresses

## Overview

You can validate an "ordinary" email address pretty easily.

```elm
import Curtissimo.Email as Email

"valid@example.org"
    |> Email.validate Email.defaultOptions
--> Just "valid@example.org"

"in..valid@example.org"
    |> Email.validate Email.defaultOptions
--> Nothing
```

## Usage

This section shows use with "ordinary" email addresses. Check out [Exotic email addresses](#exotic-email-addresses) for other options.

### Parsing and converting back to a `String`

To parse an email address, use the `fromString` function.

```elm
import Curtissimo.Email as Email

"valid@example.org" 
    |> Email.fromString Email.defaultOptions
    |> Result.map (always True)
    |> Result.withDefault False
--> True
```

You can convert it back to a `String` using the `toString` function.

```elm
import Curtissimo.Email as Email

"valid@example.org" 
    |> Email.fromString Email.defaultOptions
    |> Result.map Email.toString
--> Ok "valid@example.org" 
```

### Inspecting the parts of an email

You can inspect the different parts of the email using the `domain`, `local`, 
`plus`, `stem` functions.

```elm
import Curtissimo.Email as Email exposing (Email)

email : Result (List Int) Email
email =
  "person+adult@example.org" 
    |> Email.fromString Email.defaultOptions

email |> Result.map Email.domain
--> Ok "example.org"

email |> Result.map Email.local
--> Ok "person+adult"

email |> Result.map Email.plus
--> Ok (Just "adult")

email |> Result.map Email.stem
--> Ok "person"
```

### Removing the plus addressing

If you want to remove the plus addressing from the email address, you can use
the `removePlus` function.

```elm
import Curtissimo.Email as Email

"person+adult@example.org" 
    |> Email.fromString Email.defaultOptions
    |> Result.map Email.removePlus
    |> Result.map Email.toString
--> Ok "person@example.org" 
```

## Exotic email addresses

Okay. You want to let people use weird email addresses. Let's take a look at how
you can do that.

### Unicode characters

To include Unicode characters, you can enable the feature in the parser by
setting the `allowUnicode` option to `True`.

```elm
import Curtissimo.Email as Email

unicodeEnabled : Email.ParseOptions
unicodeEnabled =
    let 
        default : Email.ParseOptions
        default =
            Email.defaultOptions
    in
    { default | allowUnicode = True }

"ρεrso𐭹@example.org" 
    |> Email.fromString unicodeEnabled
    |> Result.map Email.toString
--> Ok "ρεrso𐭹@example.org"

"ρεrso𐭹@example.org" 
    |> Email.fromString Email.defaultOptions
--> Err [1]
```

### Quoted locals

To allow email addresses to have quoted locals, you can enable the feature in
the parser by setting the `allowQuotedLocals` option to `True`.

```elm
import Curtissimo.Email as Email

quotedLocalsEnabled : Email.ParseOptions
quotedLocalsEnabled =
    let 
        default : Email.ParseOptions
        default =
            Email.defaultOptions
    in
    { default | allowQuotedLocals = True }

"\"per\\v\\@\\tson\"@example.org" 
    |> Email.fromString quotedLocalsEnabled
    |> Result.map Email.toString
--> Ok "\"per\\v\\@\\tson\"@example.org"

"\"per\tson\"@example.org" 
    |> Email.fromString Email.defaultOptions
--> Err [1]
```

### Domain literals

To allow email addresses to have domain literals, you can enable the feature in
the parser by setting the `allowDomainLiterals` option to `True`.

```elm
import Curtissimo.Email as Email

domainLiteralsEnabled : Email.ParseOptions
domainLiteralsEnabled =
    let 
        default : Email.ParseOptions
        default =
            Email.defaultOptions
    in
    { default | allowDomainLiterals = True }

"person@[192.168.2.1/22]" 
    |> Email.fromString domainLiteralsEnabled
    |> Result.map Email.toString
--> Ok "person@[192.168.2.1/22]"

"person@[192.168.2.1/22]" 
    |> Email.fromString Email.defaultOptions
--> Err [8]
```

## Acknowledgements

Thanks to [Leonardo Taglialegne](https://github.com/miniBill) for the
[`miniBill/elm-unicode`](https://github.com/miniBill/elm-unicode) package used
to identify alphanumeric Unicode characters in the email addresses.

Thanks to the following packages which provided inspiration for the design of 
this package.

- [bellroy/elm-email](https://package.elm-lang.org/packages/bellroy/elm-email/latest/) (now archived)
- [panthershark/email-parser](https://package.elm-lang.org/packages/panthershark/email-parser/latest/)
- [tricycle/elm-email](https://package.elm-lang.org/packages/tricycle/elm-email/latest/) (disappeared)

Generated using
[`create-elm-package-gitlab`](https://gitlab.com/curtissimo/create-elm-package-gitlab).