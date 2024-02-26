# __________ -----
# DEPOTS ------------------------------------------------------------



#' List names of all depots
#' @param full_path Give full path to database?
#' @export
depots_list <- function(full_path = FALSE) {
  h <- get_hoard()
  files <- h$list()
  if (is.null(files) || full_path) {
    return(files)
  }
  basename(files) |> remove_fileext()
}


#' Show details of all depots
#' @export
depots <- function() {
  name <- path <- size <- n_objects <- modification_time <- birth_time <- NULL # avoid 'no visible binding for global variable' in R CMD CHECK
  paths <- depots_list(full_path = TRUE)
  df <- fs::file_info(paths)
  if (nrow(df) == 0) {
    cli::cli_alert_warning("No depots found.")
  }
  df |>
    mutate(
      name = path |> basename() |> remove_fileext(),
      n_objects = depot_size(name)
    ) |>
    select(name, path, size, n_objects, modified = modification_time, created = birth_time) |>
    arrange(name)
}



# __________ -----
# DEPOT ------------------------------------------------------------


#' Create a new depot
#' @param name Depot name.
#' @param activate Activate depot after creation? Default is `TRUE`.
#' @export
depot_create <- function(name, activate = TRUE) {
  if (depot_exists(name)) {
    cli::cli_abort("Depot {.emph {name}} already exists.")
  }
  .depot_init_db(name)
  if (activate) depot_activate(name)
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



#' Path to depot database file on disk
#' @param name Depot names. If `NULL`, the active depot is used (`depot_active()`).
#' @export
depot_path <- function(name = NULL) {
  name <- name %||% depot_active()
  df <- depot_details()
  df |> dplyr::filter(name == !!name) |> dplyr::pull(path)
}


# Number of objects stored in one depot
.depot_size <- function(name = NULL) {
  .abort_if_depot_not_exists(name)
  con <- .depot_connection(name)
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
  res <- name %in% depots_list()
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
#' @param name Depot names. If `NULL`, the active depot is used (`depot_active()`).
#' @param must_exist  Security mechanism. If `TRUE` (default), prevents creating a database with the given name, if it
#'   does not yet exist.
#' @returns Connection object.
#' @keywords internal
.depot_connection <- function(name = NULL, must_exist = TRUE) {
  name <- name %||% depot_active()
  if (must_exist) .abort_if_depot_not_exists(name)
  db_path <- .depot_path(name)
  dbConnect(RSQLite::SQLite(), db_path)
}


.depot_init_db <- function(name) {
  con <- .depot_connection(name, must_exist = FALSE)
  file <- system.file("ext/depot_init.sql", package = "keeper", mustWork = TRUE)
  query <- readr::read_file(file)
  if (dbExistsTable(con, "depot")) dbRemoveTable(con, "depot")
  res <- dbSendStatement(con, query)
  dbClearResult(res)
  dbDisconnect(con)
}


#' Show depot storage content
#' @param name Depot names. If `NULL`, the active depot is used (`depot_active()`).
#' @returns Tibble with depot content.
#' @export
depot_show <- function(name = NULL) {
  con <- .depot_connection(name = name)
  res <- dbGetQuery(con, "select * from depot") |> as_tibble()
  dbDisconnect(con)
  res |> mutate(changed = lubridate::as_datetime(changed))
}


# __________ -----
# KEEP ------------------------------------------------------------


# prepare R object to be stored in database
prepare_object <- function(obj, serializer = "qs") {
  s <- qs::qserialize(obj)
  list(s)
}


# delete row from depot table
id_delete <- function(id) {
  con <- .depot_connection()
  id <- DBI::dbQuoteString(con, id)
  q <- glue("delete from depot where id = {id}")
  res <- DBI::dbSendQuery(con, q)
  dbClearResult(res)
  dbDisconnect(con)
}


# get id column from depot table
ids_get <- function(depot = NULL) {
    con <- .depot_connection(depot)
    res <- dbGetQuery(con, "select id from depot")
    dbDisconnect(con)
    res |> unlist() |> unname() |> sort()
}


#' Keep object for later use.
#' @param id Unique ID of storage slot.
#' @param obj Object to store.
#' @param info Some information about the object.
#' @param tags One or more tags (character vector or comma separated string)
#' @export
keep <- function(id, obj, info = NULL, tags = NULL) {
  id <- as.character(id)
  id_delete(id)
  df <- tibble(
    id = id,
    object = prepare_object(obj),
    info = info,
    tags = paste(tags, collapse = ","),
    class = paste(class(obj), collapse = ","),
    changed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  con <- .depot_connection()
  res <- dbWriteTable(con, "depot", df, append = TRUE)
  dbDisconnect(con)
  invisible(res)
}


retrieve_object <- function(res) {
  res$object |> unlist() |> qs::qdeserialize()
}


get_object_by_id <- function(id, depot = NULL) {
  id <- as.character(id)
  con <- .depot_connection(depot)
  id_exists <- id %in% ids_get(depot)
  if (!id_exists) {
    cli::cli_alert_warning("id {.emph {id}} not found.")
    invisible(return(NULL))
  }
  query <- "select * from depot where id"
}


#' Get object from depot
#' @param id Object id
#' @param depot Depot name. If `NULL`, the active depot is used (`depot_active()`).
#' @export
pick <- function(id, depot = NULL) {
  id <- as.character(id)
  con <- .depot_connection(depot)
  id_exists <- id %in% ids_get(depot)
  if (!id_exists) {
    cli::cli_alert_warning("id {.emph {id}} not found.")
    invisible(return(NULL))
  }
  id <- DBI::dbQuoteString(con, id)
  query <- glue("select object from depot where id = {id}")
  res <- dbGetQuery(con, query)
  retrieve_object(res)
}
