module Movie exposing (..)

import Html exposing (Html, div, img, text, a, button, p, h2, h5, ul, b, li)
import Html.Attributes exposing (src, href, target, type_, autofocus)
import Html.Events exposing (onClick)
import AppCss.Helpers exposing (class, classList)
import AppCss as Style
import Time.Date exposing (Date, day, month, year)
import Set exposing (Set)
import Genre exposing (Genre)
import Json.Decode as Decode exposing (string, list)
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required)


-- Types


type MovieSelection
    = NotSelected
    | Selected Movie
    | Loaded MovieDetails


type alias Movie =
    { title : String
    , url : String
    , img : String
    , year : Int
    , runtime : Int
    , genres : Set Genre
    , watched : WatchState
    }


type alias Rating =
    { source : String
    , value : String
    }


type MovieOffers
    = Loading
    | NoResults
    | Found (List JustWatchOffer)


type alias MovieDetails =
    { movie : Movie
    , rated : String
    , runtime : String
    , director : String
    , writer : String
    , actors : String
    , plot : String
    , ratings : List Rating
    , offers : MovieOffers
    }


decodeMovieData : Movie -> Decode.Decoder MovieDetails
decodeMovieData movie =
    Json.Decode.Pipeline.decode MovieDetails
        |> Json.Decode.Pipeline.hardcoded movie
        |> Json.Decode.Pipeline.required "Rated" Decode.string
        |> Json.Decode.Pipeline.required "Runtime" Decode.string
        |> Json.Decode.Pipeline.required "Director" Decode.string
        |> Json.Decode.Pipeline.required "Writer" Decode.string
        |> Json.Decode.Pipeline.required "Actors" Decode.string
        |> Json.Decode.Pipeline.required "Plot" Decode.string
        |> Json.Decode.Pipeline.required "Ratings" (Decode.list ratingDecoder)
        |> Json.Decode.Pipeline.hardcoded Loading


ratingDecoder : Decode.Decoder Rating
ratingDecoder =
    Json.Decode.Pipeline.decode Rating
        |> Json.Decode.Pipeline.required "Source" Decode.string
        |> Json.Decode.Pipeline.required "Value" Decode.string


type alias JustWatchSearchResult =
    { title : String
    , id : Int
    }


type alias JustWatchSearchResults =
    { items : List JustWatchSearchResult
    , movie : MovieDetails
    }


type alias JustWatchDetails =
    { offers : List JustWatchOffer
    , movie : MovieDetails
    }


decodeJustWatchSearch : MovieDetails -> Decode.Decoder JustWatchSearchResults
decodeJustWatchSearch movie =
    Json.Decode.Pipeline.decode JustWatchSearchResults
        |> Json.Decode.Pipeline.required "items" (Decode.list searchResultDecoder)
        |> Json.Decode.Pipeline.hardcoded movie


searchResultDecoder =
    Json.Decode.Pipeline.decode JustWatchSearchResult
        |> Json.Decode.Pipeline.required "title" Decode.string
        |> Json.Decode.Pipeline.required "id" Decode.int


type OfferType
    = Buy
    | Rent
    | Streaming
    | Ads
    | Unknown


offerTypeDecoder : Decode.Decoder OfferType
offerTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "buy" ->
                        Decode.succeed Buy

                    "flatrate" ->
                        Decode.succeed Streaming

                    "rent" ->
                        Decode.succeed Rent

                    "ads" ->
                        Decode.succeed Ads

                    unknown ->
                        Decode.succeed Unknown
            )


type Provider
    = Itunes
    | Microsoft
    | GooglePlay
    | Hulu
    | Netflix
    | Amazon
    | Fandango
    | Vudu
    | PlayStation
    | Starz
    | Crackle
    | Other


providerDecoder : Decode.Decoder Provider
providerDecoder =
    Decode.int
        |> Decode.andThen
            (\providerId ->
                case providerId of
                    2 ->
                        Decode.succeed Itunes

                    3 ->
                        Decode.succeed GooglePlay

                    7 ->
                        Decode.succeed Vudu

                    8 ->
                        Decode.succeed Netflix

                    9 ->
                        Decode.succeed Amazon

                    10 ->
                        Decode.succeed Amazon

                    12 ->
                        Decode.succeed Crackle

                    15 ->
                        Decode.succeed Hulu

                    18 ->
                        Decode.succeed PlayStation

                    43 ->
                        Decode.succeed Starz

                    68 ->
                        Decode.succeed Microsoft

                    105 ->
                        Decode.succeed Fandango

                    other ->
                        Decode.succeed Other
            )


type alias JustWatchOffer =
    { offerType : OfferType
    , provider : Provider
    , url : String
    }


decodeJustWatchOffer : Decode.Decoder JustWatchOffer
decodeJustWatchOffer =
    Json.Decode.Pipeline.decode JustWatchOffer
        |> Json.Decode.Pipeline.required "monetization_type" offerTypeDecoder
        |> Json.Decode.Pipeline.required "provider_id" providerDecoder
        |> Json.Decode.Pipeline.requiredAt [ "urls", "standard_web" ] Decode.string


decodeJustWatchDetails : MovieDetails -> Decode.Decoder JustWatchDetails
decodeJustWatchDetails movie =
    Json.Decode.Pipeline.decode JustWatchDetails
        |> Json.Decode.Pipeline.required "offers" (Decode.list decodeJustWatchOffer)
        |> Json.Decode.Pipeline.hardcoded movie


type WatchState
    = Unwatched
    | Watched Date



-- Helpers


isWatched : Movie -> Bool
isWatched movie =
    case movie.watched of
        Unwatched ->
            False

        Watched _ ->
            True


watchDate : Movie -> Maybe Date
watchDate movie =
    case movie.watched of
        Unwatched ->
            Nothing

        Watched date ->
            Just date


matchGenres : Set Genre -> Movie -> Bool
matchGenres genres movie =
    case Set.size genres of
        0 ->
            True

        _ ->
            Set.size (Set.intersect genres movie.genres) > 0



-- Views


moviePoster : Movie -> Html msg
moviePoster movie =
    img
        [ class [ Style.Poster ]
        , src ("posters/" ++ movie.img)
        ]
        []


movieCard : (Movie -> msg) -> Set Genre -> Movie -> Html msg
movieCard focusMovie selectedGenres movie =
    let
        filtered =
            case Set.size selectedGenres of
                0 ->
                    False

                _ ->
                    Set.size (Set.intersect movie.genres selectedGenres) == 0
    in
        button
            [ classList
                [ ( Style.MovieCard, True )
                , ( Style.Filterable, True )
                , ( Style.Filtered, filtered )
                ]
            , onClick <| focusMovie <| movie
            , type_ "button"
            ]
            [ moviePoster movie
            , div
                [ class [ Style.Title ] ]
                [ text movie.title ]
            , notesView movie
            ]


ratingsList : List Rating -> Html msg
ratingsList ratings =
    ratings
        |> List.map (\l -> li [] [ text (l.source ++ " - "), b [] [ text l.value ] ])
        |> ul []


movieModalBase : msg -> List (Html msg) -> Html msg
movieModalBase closeModal contents =
    div
        [ class [ Style.MovieModal ]
        ]
        ([ button
            [ class [ Style.CloseButton ]
            , onClick closeModal
            , autofocus True
            ]
            [ text "❌"
            ]
         ]
            ++ contents
        )


movieOffer : JustWatchOffer -> List (Html msg)
movieOffer offer =
    [ a [ href offer.url, target "_blank" ]
        [ text ((toString offer.provider) ++ " " ++ (toString offer.offerType))
        ]
    ]


movieOffers : MovieDetails -> Html msg
movieOffers movie =
    case movie.offers of
        Loading ->
            h5 [] [ text "Searching for movie viewing options..." ]

        NoResults ->
            h5 [] [ text "Movie not found for streaming or purchase" ]

        Found offers ->
            div []
                [ h5 [] [ text "Watch" ]
                , div [ class [ Style.Grid ] ]
                    (offers
                        |> List.map (\offer -> div [ class [ Style.GridBlock ] ] (movieOffer offer))
                    )
                ]


movieModal : MovieDetails -> msg -> Html msg
movieModal movie closeModal =
    movieModalBase closeModal
        [ div [ class [ Style.LeftBar ] ]
            [ moviePoster movie.movie
            , div [ class [ Style.InfoBlock ] ]
                [ ratingsList movie.ratings ]
            ]
        , div [ class [ Style.RightBar, Style.InfoBlock ] ]
            [ h2 []
                [ a [ href movie.movie.url, target "_blank" ] [ text movie.movie.title ]
                , text (" - " ++ (toString movie.movie.year) ++ " - Rated " ++ movie.rated ++ " - " ++ movie.runtime)
                ]
            , p [] [ text movie.plot ]
            , p [] [ text ("Directed by " ++ movie.director ++ ". Written by " ++ movie.writer ++ ".") ]
            , p [] [ text ("Starring " ++ movie.actors) ]
            , div []
                (movie.movie.genres
                    |> Set.toList
                    |> List.map (\( g, t ) -> a [ href ("?genres=" ++ g) ] [ text t ])
                )
            , movieOffers movie
            ]
        ]


offlineMovieModal : Movie -> msg -> Html msg
offlineMovieModal movie closeModal =
    movieModalBase closeModal
        [ div [ class [ Style.LeftBar ] ]
            [ moviePoster movie ]
        , div [ class [ Style.RightBar, Style.InfoBlock ] ]
            [ h2 []
                [ a [ href movie.url, target "_blank" ] [ text movie.title ]
                , text (" - " ++ (toString movie.year) ++ " - " ++ (toString movie.runtime) ++ "min")
                ]
            , div []
                (movie.genres
                    |> Set.toList
                    |> List.map (\( g, t ) -> a [ href ("?genres=" ++ g) ] [ text t ])
                )
            ]
        ]


notesView : Movie -> Html msg
notesView movie =
    case movie.watched of
        Unwatched ->
            div [ class [ Style.Notes ] ]
                [ text <|
                    (toString movie.year)
                        ++ ", "
                        ++ (toString movie.runtime)
                        ++ " min"
                ]

        Watched date ->
            div [ class [ Style.Notes ] ]
                [ text <|
                    (toString (month date))
                        ++ "."
                        ++ (toString (day date))
                        ++ "."
                        ++ (toString (year date))
                ]
