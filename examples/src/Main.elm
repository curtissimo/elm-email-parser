module Main exposing (Model, Msg, main)

import Browser
import Curtissimo.Email as Email exposing (Email, ParseOptions)
import Html exposing (Html, button, dd, div, dl, dt, input, label, p, text)
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , for
        , id
        , placeholder
        , type_
        , value
        )
import Html.Events exposing (onCheck, onClick, onInput)


type alias Model =
    { content : String
    , email : Result (List Int) Email
    , options : ParseOptions
    }


type ParseOption
    = AllowDomainLiterals
    | AllowQuotedLocals
    | AllowUnicode


type Msg
    = FieldUpdated String
    | OptionChanged ParseOption Bool
    | UseOption ParseOption String


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        example : String
        example =
            "person+adult@example.com"
    in
    ( { content = example
      , email = Email.fromString Email.defaultOptions example
      , options = Email.defaultOptions
      }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FieldUpdated content ->
            ( { model
                | content = content
                , email = Email.fromString model.options content
              }
            , Cmd.none
            )

        OptionChanged AllowDomainLiterals value ->
            let
                oldOptions : ParseOptions
                oldOptions =
                    model.options

                options : ParseOptions
                options =
                    { oldOptions | allowDomainLiterals = value }
            in
            ( { model
                | email = Email.fromString options model.content
                , options = options
              }
            , Cmd.none
            )

        OptionChanged AllowQuotedLocals value ->
            let
                oldOptions : ParseOptions
                oldOptions =
                    model.options

                options : ParseOptions
                options =
                    { oldOptions | allowQuotedLocals = value }
            in
            ( { model
                | email = Email.fromString options model.content
                , options = options
              }
            , Cmd.none
            )

        OptionChanged AllowUnicode value ->
            let
                oldOptions : ParseOptions
                oldOptions =
                    model.options

                options : ParseOptions
                options =
                    { oldOptions | allowUnicode = value }
            in
            ( { model
                | email = Email.fromString options model.content
                , options = options
              }
            , Cmd.none
            )

        UseOption option content ->
            let
                default : ParseOptions
                default =
                    Email.defaultOptions

                options : ParseOptions
                options =
                    case option of
                        AllowDomainLiterals ->
                            { default | allowDomainLiterals = True }

                        AllowQuotedLocals ->
                            { default | allowQuotedLocals = True }

                        AllowUnicode ->
                            { default | allowUnicode = True }
            in
            ( { content = content
              , email = Email.fromString options content
              , options = options
              }
            , Cmd.none
            )


resultsPanel : Result (List Int) Email -> Html msg
resultsPanel result =
    case result of
        Err columns ->
            let
                cols : List String
                cols =
                    columns |> List.map String.fromInt
            in
            div [] [ text ("Bad email address at columns " ++ String.join "," cols) ]

        Ok email ->
            div [ class "content" ]
                [ dl []
                    [ dt [] [ text "Local" ]
                    , dd [] [ text (email |> Email.local) ]
                    , dt [] [ text "Stem" ]
                    , dd [] [ text (email |> Email.stem) ]
                    , dt [] [ text "Plus" ]
                    , dd [] [ text (email |> Email.plus |> Maybe.withDefault "<none>") ]
                    , dt [] [ text "Domain" ]
                    , dd [] [ text (email |> Email.domain) ]
                    ]
                ]


view : Model -> Html Msg
view model =
    div [ class "is-flex mt-6" ]
        [ div [ class "is-flex-grow-1" ]
            [ div [ class "mb-4 is-flex is-align-items-center" ]
                [ div [ class "mr-2 has-text-weight-bold" ] [ text "Click an example:" ]
                , div [ class "buttons" ]
                    [ button
                        [ class "button is-small is-info"
                        , onClick (UseOption AllowUnicode "ρεrso𐭹+adult@example.org")
                        ]
                        [ text "Unicode address" ]
                    , button
                        [ class "button is-small is-info"
                        , onClick (UseOption AllowQuotedLocals "\"\tpers@n+adul\\t\t\"@example.org")
                        ]
                        [ text "Quoted local" ]
                    , button
                        [ class "button is-small is-info"
                        , onClick (UseOption AllowDomainLiterals "person+adult@[e x a m p l e . o r g]")
                        ]
                        [ text "Domain literal" ]
                    ]
                ]
            , div [ class "field" ]
                [ label [ for "email" ] [ text "Email address" ]
                , div [ class "control" ]
                    [ input
                        [ attribute "inputmode" "email"
                        , class "input"
                        , id "email"
                        , onInput FieldUpdated
                        , placeholder "person@example.org"
                        , type_ "email"
                        , value model.content
                        ]
                        []
                    ]
                ]
            , resultsPanel model.email
            ]
        , div [ class "is-flex-grow-0 instructions ml-6 content" ]
            [ p [] [ text "Type an email address in the field and see how the parser works." ]
            , p [] [ text "Change the options below to alter the way the parser works." ]
            , p []
                [ div []
                    [ label [ class "checkbox" ]
                        [ input
                            [ checked model.options.allowUnicode
                            , onCheck (OptionChanged AllowUnicode)
                            , type_ "checkbox"
                            ]
                            []
                        , text " Allow Unicode"
                        ]
                    ]
                ]
            , p []
                [ label [ class "checkbox" ]
                    [ input
                        [ checked model.options.allowQuotedLocals
                        , onCheck (OptionChanged AllowQuotedLocals)
                        , type_ "checkbox"
                        ]
                        []
                    , text " Allow quoted locals"
                    ]
                ]
            , p []
                [ label [ class "checkbox" ]
                    [ input
                        [ checked model.options.allowDomainLiterals
                        , onCheck (OptionChanged AllowDomainLiterals)
                        , type_ "checkbox"
                        ]
                        []
                    , text " Allow domain literals"
                    ]
                ]
            ]
        ]
