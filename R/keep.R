#' Create a new depot
#' @param name Depot name.
#' @export
depot_create <- function(name) {
  if (depot_exists(name)) {
    cli::cli_abort("Depot {.emph {name}} already exists.")
  }
  con <- .depot_init_db(name)
  con
}


#' Delete depot
#' @param name Depot name(s) to delete.
#' @export
depot_delete <- function(name) {
  db_names <- .depot_make_name(name)
  h <- get_hoard()
  for (db_name in db_names) {
    h$delete(db_name)
  }
}


#' Switch active depot
#' @param name Depot name to be activated.
#' @export
depot_activate <- function(name) {
  .abort_if_depot_not_exists(name)
  set_depot(name)
}


#' Get name of active depot
#' @export
depot_active <- function() {
  get_depot()
}

#' List names of all depots
#' @param full_path Give full path to database?
#' @export
depot_list <- function(full_path = FALSE) {
  h <- get_hoard()
  files <- h$list()
  if (is.null(files) || full_path) {
    return(files)
  }
  basename(files) |> remove_fileext()
}


#' Show details of all depots
#' @export
depot_details <- function() {
  name <- path <- size <- n_objects <- NULL   # avoid 'no visible binding for global variable' in R CMD CHECK
  paths <- depot_list(full_path = TRUE)
  df <- fs::file_info(paths)
  if (nrow(df) == 0) {
    cli::cli_alert_warning("No depots found.")
  }
  df |>
    mutate(
      name = path |> basename() |> remove_fileext(),
      n_objects = depot_size(name)
    ) |>
    select(name, path, size, n_objects, contains("time")) |>
    arrange(name)
}


# Number of objects stored in one depot
.depot_size <- function(name = NULL) {
  .abort_if_depot_not_exists(name)
  con <- .depot_connection(name, must_exist = TRUE)
  res <- dbGetQuery(con, "select count(*) as no_of_objects from depot")
  dbDisconnect(con)
  res |>
    unlist() |>
    unname()
}


#' Number of objects in depot
#' @param name Depot names. If `NULL`, the active depot is used (`depot_active()`).
#' @returns Named vector with number of objects per depot.
#' @export
depot_size <- function(name = NULL) {
  name <- name %||% depot_active()
  vapply(name, .depot_size, integer(1))
}


#' Does the depot exist?
#' @param name Depot names.
#' @returns Named logical vector.
#' @export
depot_exists <- function(name) {
  res <- name %in% depot_list()
  set_names(res, name)
}



remove_fileext <- function(x) {
  ext <- options()$keeper.fileext
  stringr::str_remove(x, glue("\\.{ext}$"))
}


.abort_if_depot_not_exists <- function(name) {
  if (!depot_exists(name)) {
    cli::cli_abort("depot {.emph {name}} does not exist.")
  }
}


.depot_make_name <- function(name) {
  fileext <- options()$keeper.fileext
  glue("{name}.{fileext}")
}


.depot_path <- function(name) {
  h <- get_hoard()
  base <- h$cache_path_get()
  db_name <- .depot_make_name(name)
  file.path(base, db_name)
}


#' Create depot database connection
#' @param name Depot name.
#' @param must_exist  Security mechanism. Will prevent creation of databse if it does not already exists.
#' @returns Connection object.
#' @keywords internal
.depot_connection <- function(name, must_exist = FALSE) {
  if (must_exist) .abort_if_depot_not_exists(name)
  db_path <- .depot_path(name)
  dbConnect(RSQLite::SQLite(), db_path)
}


.depot_init_db <- function(name) {
  con <- .depot_connection(name)
  file <- system.file("ext/depot_init.sql", package = "keeper", mustWork = TRUE)
  query <- readr::read_file(file)
  if (dbExistsTable(con, "depot")) dbRemoveTable(con, "depot")
  res <- dbSendStatement(con, query)
  dbClearResult(res)
  dbDisconnect(con)
}
