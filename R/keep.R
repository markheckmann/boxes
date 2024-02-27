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
  df <- depots()
  path <- NULL  # avoid R CMD CHECK note
  df |> dplyr::filter(name == !!name) |> dplyr::pull(path)
}


# Number of objects stored in one depot
.depot_size <- function(name = NULL) {
  .abort_if_depot_not_exists(name)
  con <- .depot_connection(name)
  on.exit(dbDisconnect(con))
  res <- dbGetQuery(con, "select count(*) as no_of_objects from depot")
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
  on.exit(dbDisconnect(con))
  res <- dbGetQuery(con, "select * from depot") |> as_tibble()
  changed <- NULL  # avoid R CMD CHECK note
  res |> mutate(changed = lubridate::as_datetime(changed))
}


# Check that depot works
depot_works <- function(name) {
  tryCatch(is.integer(depot_size(name)), error = \(e) {FALSE})
}


#' Export depot to a file
#'
#' The exported depot file contains the depot name, the original depot path and its name and the databse itself.
#'
#' @param name Depot name.
#' @param file Where to store the depot. We suggest the file ending (`.depot`).
#' If `NULL`, the depot is exported to the current working dir.
#' @export
depot_export <- function(name, file = NULL) {
  file <- file %||% glue("{name}.depot") # default name
  out_dir <- dirname(file)
  out_dir_exists <- fs::dir_exists(out_dir)
  if (!out_dir_exists) {
    cli::cli_abort("Folder not found: {.path {out_dir}}. Can only save to existing folder.")
  }
  d_path <- depot_path(name)
  db <- readBin(d_path, what = "raw", n = file.info(d_path)$size)
  l <- list(
    name = name,
    db = db,
    pkg_version = utils::packageVersion("keeper")
  )
  class(l) <- c("keeper_export", class(l))
  qs::qsave(l, file)
  cli::cli_alert_info("Depot file saved as {.path {file}}")
}


#' Import depot from file
#' @param file Path to depot file.
#' @param name Depot name to use for imported data. If `NULL`, the original name (before export) will be used.
#' @param overwrite Overwrite if depot with name already exists?
#' @param activate Activate depot after import?
#' @export
depot_import <- function(file, name = NULL, overwrite = FALSE, activate = FALSE) {
  if (!fs::file_exists(file)) {
    cli::cli_abort("File not found: {.path {file}}")
  }
  l <- tryCatch(qs::qread(file), error = \(e) e)
  if (!inherits(l, "keeper_export")) {
    cli::cli_abort("File cannot be read. Does not seem to be a depot export.")
  }
  if (is.null(name)) {
    name <- l$name
    cli::cli_alert_info("No name provided. Using original name {.emph {name}}")
  }
  if (!overwrite && depot_exists(name)) {
    cli::cli_abort("depot {.emph {name}} already exists. Set {.code overwrite=TRUE} to replace it.")
  }
  h <- get_hoard()
  db_path <- file.path(h$cache_path_get(), glue("{name}.db"))
  writeBin(l$db, db_path)
  if (!depot_works(name)) {  # delete of depot is corrupted
    fs::file_delete(db_path)
    cli::cli_abort("Depot cannot be imported. File appears to be corrupted.")
  }
  cli::cli_alert_info("Imported {.path {basename(file)}} as depot {.emph {name}}")
  if (activate) depot_activate(name)
  invisible(name)
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
  on.exit(dbDisconnect(con))
  res <- dbWriteTable(con, "depot", df, append = TRUE)
  invisible(res)
}


#' Keep object for later use.
#' @param id Unique ID of storage slot.
#' @param path File path.
#' @param info Some information about the object.
#' @param tags One or more tags (character vector or comma separated string)
#' @export
#' @examples
#' file <- system.file("ext/depot_init.sql", package = "keeper")
#' keep_file("code", file, "some SQL code")
keep_file <- function(id, path, info = NULL, tags = NULL) {
  id <- as.character(id)
  if (!fs::is_file(path)) {
    cli::cli_abort("File does not exist: {.file {path}}")
  }
  s <- readBin(path, what = "raw", n = file.info(path)$size)
  df <- tibble::tibble(
    id = id,
    object = list(s),
    info = info,
    tags = paste(tags, collapse = ","),
    class = glue("filetype: .{fs::path_ext(path)}"),
    changed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  id_delete(id)
  con <- .depot_connection()
  on.exit(dbDisconnect(con))
  dbWriteTable(con, "depot", df, append = TRUE)
}




# __________ -----
# PICK ------------------------------------------------------------


retrieve_object <- function(res) {
  res$object |> unlist() |> qs::qdeserialize()
}


#' Get object from depot
#' @param id Object id
#' @param depot Depot name. If `NULL`, the active depot is used (`depot_active()`).
#' @export
pick <- function(id, depot = NULL) {
  id <- as.character(id)
  con <- .depot_connection(depot)
  on.exit(dbDisconnect(con))
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
