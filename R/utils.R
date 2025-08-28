`%||%` <- function(l, r) {
  if (is.null(l)) r else l
}


# from stats::setNames
set_names <- function(object = nm, nm) {
  names(object) <- nm
  object
}


as_utc_datetime <- function(x) {
  lubridate::as_datetime(x) |> lubridate::force_tz("UTC")
}


as_local_datetime <- function(x) {
  lubridate::as_datetime(x) |> lubridate::force_tz(Sys.timezone())
}


#' Convert different input types into expiration datetime
#'
#' @param x Understands: <date>, <datetime>, <duration>, <period>, duration string
#' @noRd
calc_expiration_date <- function(x) {
  if (is.null(x) || is.na(x) || isFALSE(x)) {
    return(NULL)
  }

  if (lubridate::is.POSIXt(x) || lubridate::is.Date(x)) {
    return(as_utc_datetime(x))
  }

  if (lubridate::is.period(x)) {
    x <- Sys.Date() + x
    return(as_utc_datetime(x))
  }

  if (lubridate::is.duration(x)) {
    return(lubridate::now() + x)
  }

  dt <- suppressWarnings(as_utc_datetime(x))
  if (!is.na(dt)) {
    return(dt)
  }

  date <- suppressWarnings(lubridate::as_date(x))
  if (!is.na(date)) {
    return(date |> as_utc_datetime())
  }

  if (is.character(x)) {
    d <- lubridate::duration(x)
    if (!is.na(d)) {
      r <- lubridate::now() + d
      return(as_utc_datetime(r))
    }
  }
  cli::cli_abort("Cannot parse {.val {x}} into a date, datetime or duration")
}
