#' boxes: store and retrieve arbitrary R objects
#'
#' \if{html}{\figure{logo.png}{options: style='float: right; padding-left: 10px;' alt='logo' width='120'}} The
#' The goal of boxes is to provide a convenient way to store arbitrary R objects or files (plus additional notes)
#' and retrieve them again later.
#'
#' To use the package, you need to know a few terms:
#' * `box`: A container to store things. Things can be R objects or files.
#' * `item`: Anything stored in a box.
#' * `pack`: Adding an item to a box.
#' * `pick`: Retrieving an item from a box.
#'
#' Boxes are stored on your disk. Hence, anything put into it will remain there until you delete the box. Technically, each box is a separate SQLite database. You can create as many boxes as you need.
#'
#' @keywords internal
"_PACKAGE"


#' @import DBI
#' @importFrom dplyr arrange contains mutate select filter
#' @importFrom glue glue
#' @importFrom hoardr hoard
#' @importFrom tibble as_tibble tibble
NULL
