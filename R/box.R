# __________ -----
# BOXES ------------------------------------------------------------



#' List names of all boxes
#' @param full_path Give full path to database?
#' @export
boxes_list <- function(full_path = FALSE) {
  h <- get_hoard()
  files <- h$list()
  if (is.null(files) || full_path) {
    return(files)
  }
  basename(files) |> remove_fileext()
}


#' Show details of all boxes
#' @export
boxes <- function() {
  name <- path <- size <- n_objects <- modification_time <- birth_time <- NULL # avoid 'no visible binding for global variable' in R CMD CHECK
  paths <- boxes_list(full_path = TRUE)
  df <- fs::file_info(paths)
  if (nrow(df) == 0) {
    cli::cli_alert_warning("No boxes found.")
  }
  df |>
    mutate(
      name = path |> basename() |> remove_fileext(),
      active = ifelse(name == get_box(), "*", "\u2800"),
      objects = box_size(name)
    ) |>
    select(active, name, objects, size, last_modified = modification_time, created = birth_time) |>
    arrange(name)
}



# __________ -----
# BOX ------------------------------------------------------------


#' Create a new box
#' @param name box name.
#' @param activate Activate box after creation? Default is `TRUE`.
#' @export
box_create <- function(name, activate = TRUE) {
  if (box_exists(name)) {
    cli::cli_abort("box {.emph {name}} already exists.")
  }
  .box_init_db(name)
  if (activate) {
    box_activate(name)
    cli::cli_alert_info("Activating box {.emph {name}}")
  }
}


# delete one box. Issue warning if it does not exist
# name: box name
# .skip: box must exist. Throw error otherwise.
.box_delete <- function(name, .skip = TRUE) {
  exists <- box_exists(name)
  if (!.skip && !exists) {
    cli::cli_abort("Cannot delete box {.emph {name}} as it does not exist.")
  }
  if (exists) {
    db_name <- .box_make_name(name)
    h <- get_hoard()
    h$delete(db_name)
  } else {
    cli::cli_alert_warning("Skipped {.emph {name}}, box does not exist.")
  }
}


#' Delete box
#'
#' Delete one or more boxes. If a box does not exist it is skipped.
#'
#' @param name box name(s) to delete.
#' @param ... More comma separated box names (optional).
#' @param .skip Skip box if it does not exist (default is `TRUE`).
#' @export
#' @examples \dontrun{
#'   box_delete("a")
#'   box_delete(c("a", "b"))
#'   box_delete("a", "b")  # same as above
#' }
box_delete <- function(name, ..., .skip = TRUE) {
  dots <- list(...)
  name <- c(name, unlist(dots)) |> unique()
  for (nm in name) {
    .box_delete(nm, .skip = .skip)
  }
}


#' Switch active box
#' @param name box name to be activated.
#' @export
box_activate <- function(name) {
  .abort_if_box_not_exists(name)
  set_box(name)
}


#' Get name of active box
#' @export
box_active <- function() {
  get_box()
}



#' Path to box database file on disk
#' @param name box names. If `NULL`, the active box is used (`box_active()`).
#' @export
box_path <- function(name = NULL) {
  name <- name %||% box_active()
  df <- boxes()
  path <- NULL  # avoid R CMD CHECK note
  df |> dplyr::filter(name == !!name) |> dplyr::pull(path)
}


# Number of objects stored in one box
.box_size <- function(name = NULL) {
  .abort_if_box_not_exists(name)
  con <- .box_connection(name)
  on.exit(dbDisconnect(con))
  res <- dbGetQuery(con, "select count(*) as no_of_objects from box")
  res |>
    unlist() |>
    unname()
}


#' Number of objects in box
#' @param name box names. If `NULL`, the active box is used (`box_active()`).
#' @returns Named vector with number of objects per box.
#' @export
box_size <- function(name = NULL) {
  name <- name %||% box_active()
  vapply(name, .box_size, integer(1))
}


#' Does the box exist?
#' @param name box names.
#' @returns Named logical vector.
#' @export
box_exists <- function(name) {
  res <- name %in% boxes_list()
  set_names(res, name)
}



remove_fileext <- function(x) {
  ext <- options()$boxes.fileext
  stringr::str_remove(x, glue("\\.{ext}$"))
}


.abort_if_box_not_exists <- function(name) {
  if (!box_exists(name)) {
    cli::cli_abort("box {.emph {name}} does not exist.")
  }
}


.box_make_name <- function(name) {
  fileext <- options()$boxes.fileext
  glue("{name}.{fileext}")
}


.box_path <- function(name) {
  h <- get_hoard()
  base <- h$cache_path_get()
  db_name <- .box_make_name(name)
  file.path(base, db_name)
}


#' Create box database connection
#' @param name box names. If `NULL`, the active box is used (`box_active()`).
#' @param must_exist  Security mechanism. If `TRUE` (default), prevents creating a database with the given name, if it
#'   does not yet exist.
#' @returns Connection object.
#' @keywords internal
.box_connection <- function(name = NULL, must_exist = TRUE) {
  name <- name %||% box_active()
  if (must_exist) .abort_if_box_not_exists(name)
  db_path <- .box_path(name)
  dbConnect(RSQLite::SQLite(), db_path)
}


.box_init_db <- function(name) {
  con <- .box_connection(name, must_exist = FALSE)
  file <- system.file("ext/box_init.sql", package = "boxes", mustWork = TRUE)
  query <- readr::read_file(file)
  if (dbExistsTable(con, "box")) dbRemoveTable(con, "box")
  res <- dbSendStatement(con, query)
  dbClearResult(res)
  dbDisconnect(con)
}


#' Show box content
#' @param name box names. If `NULL`, the active box is used (`box_active()`).
#' @returns Tibble with box content.
#' @export
box <- function(name = NULL) {
  con <- .box_connection(name = name)
  on.exit(dbDisconnect(con))
  cli::cli_h3("active box {.val {get_box()}}")
  res <- dbGetQuery(con, "select * from box") |> as_tibble()
  changed <- NULL  # avoid R CMD CHECK note
  res |> mutate(changed = lubridate::as_datetime(changed))
}


# Check that box works
box_works <- function(name) {
  tryCatch(is.integer(box_size(name)), error = \(e) {FALSE})
}


#' Export box to a file
#'
#' The exported box file contains the box name, the original box path and its name and the databse itself.
#'
#' @param name box name.
#' @param file Where to store the box. We suggest the file ending (`.box`).
#' If `NULL`, the box is exported to the current working dir.
#' @export
box_export <- function(name, file = NULL) {
  force(name) # clearer error message if name is missing
  file <- file %||% glue("{name}.box") # default name
  out_dir <- dirname(file)
  out_dir_exists <- fs::dir_exists(out_dir)
  if (!out_dir_exists) {
    cli::cli_abort("Folder not found: {.path {out_dir}}. Can only save to existing folder.")
  }
  d_path <- box_path(name)
  db <- readBin(d_path, what = "raw", n = file.info(d_path)$size)
  l <- list(
    name = name,
    db = db,
    pkg_version = utils::packageVersion("boxes")
  )
  class(l) <- c("boxes_export", class(l))
  qs::qsave(l, file)
  cli::cli_alert_info("box file saved as {.path {file}}")
}


#' Import box from file
#' @param file Path to box file.
#' @param name box name to use for imported data. If `NULL`, the original name (before export) will be used.
#' @param overwrite Overwrite if box with name already exists?
#' @param activate Activate box after import?
#' @export
box_import <- function(file, name = NULL, overwrite = FALSE, activate = FALSE) {
  if (!fs::file_exists(file)) {
    cli::cli_abort("File not found: {.path {file}}")
  }
  l <- tryCatch(qs::qread(file), error = \(e) e)
  if (!inherits(l, "boxes_export")) {
    cli::cli_abort("File cannot be read. Does not seem to be a box export.")
  }
  if (is.null(name)) {
    name <- l$name
    cli::cli_alert_info("No name provided. Using original name {.emph {name}}")
  }
  if (!overwrite && box_exists(name)) {
    cli::cli_abort("box {.emph {name}} already exists. Set {.code overwrite=TRUE} to replace it.")
  }
  h <- get_hoard()
  db_path <- file.path(h$cache_path_get(), glue("{name}.db"))
  writeBin(l$db, db_path)
  if (!box_works(name)) {  # delete of box is corrupted
    fs::file_delete(db_path)
    cli::cli_abort("box cannot be imported. File appears to be corrupted.")
  }
  cli::cli_alert_info("Imported {.path {basename(file)}} as box {.emph {name}}")
  if (activate) box_activate(name)
  invisible(name)
}



# __________ -----
# ITEMS ------------------------------------------------------------


# prepare R object to be stored in database
prepare_object <- function(obj, serializer = "qs") {
  s <- qs::qserialize(obj)
  list(s)
}


# delete row from box table
.item_delete <- function(id, box = NULL) {
  con <- .box_connection(name = box)
  on.exit(dbDisconnect(con))
  id <- DBI::dbQuoteString(con, id)
  q <- glue("delete from box where id = {id}")
  res <- DBI::dbSendQuery(con, q)
  dbClearResult(res)
}


# get id column from box table
box_ids <- function(name = NULL) {
    con <- .box_connection(name = name)
    res <- dbGetQuery(con, "select id from box")
    dbDisconnect(con)
    res |> unlist() |> unname() |> sort()
}


retrieve_object <- function(res) {
  res$object |> unlist() |> qs::qdeserialize()
}


#' Remove an item from a box
#' @param id Item id.
#' @param box Box name. If `NULL`, the active box is used (`box_active()`).
#' @returns `TRUE` if deletion succeeded, else `FALSE`.
#' @export
#' @rdname item-remove
item_remove <- function(id, box = NULL) {
  box <- box %||% box_active()
  id <- as.character(id)
  id_exists <- id %in% box_ids(name = box)
  if (!id_exists) {
    cli::cli_alert_warning("No item with id {.emph {id}} in box {.emph {box}}. Nothing deleted.")
    return(invisible(FALSE))
  }
  .item_delete(id, box = box)
}


#' @rdname item-remove
#' @export
remove <- item_remove


#' Pack item into a box.
#' @param obj Object to store.
#' @param id Unique id as storage name. If `NULL`, the objects's name is used.
#' @param info Some information about the object.
#' @param tags One or more tags (character vector or comma separated string).
#' @param box Name of box to use. If `NULL`, the active box used (`box_active()`).
#' @param replace Replace object if `id` already exists (default `FALSE`).
#' @returns Returns `id`.
#' @export
#' @rdname item-pack
item_pack <- function(obj, id = NULL, info = NULL, tags = NULL, box = NULL, replace = FALSE) {
  if (is.null(id)) {
    id <- rlang::enexpr(obj) |> as.character()
    cli::cli_alert_info("No {.arg id} provided, using {.val {id}}")
  }
  id <- as.character(id)
  if (length(id) == 0 || id == "") {
    cli::cli_abort("{.arg id} must have at least one character.")
  }
  id_exists <- id %in% box_ids(box)
  if (id_exists && !replace) {
    cli::cli_abort("id {.val {id}} already exists. Set {.arg replace = TRUE} to replace it.")
  }
  .item_delete(id)
  df <- tibble(
    id = id,
    object = prepare_object(obj),
    info = info,
    tags = paste(tags, collapse = ","),
    class = paste(class(obj), collapse = ","),
    changed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  con <- .box_connection()
  on.exit(dbDisconnect(con))
  res <- dbWriteTable(con, "box", df, append = TRUE)
  invisible(id)
}


#' @rdname item-pack
#' @export
pack <- item_pack


#' Pack file into a box.
#' @param id Unique ID of storage slot.
#' @param path File path.
#' @param info Some information about the object.
#' @param tags One or more tags (character vector or comma separated string)
#' @export
#' @examples
#' file <- system.file("ext/box_init.sql", package = "boxes")
#' pack_file("code", file, "some SQL code")
pack_file <- function(id, path, info = NULL, tags = NULL) {
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
  .item_delete(id)
  con <- .box_connection()
  on.exit(dbDisconnect(con))
  dbWriteTable(con, "box", df, append = TRUE)
}


#' Get object from box
#' @param id Object id
#' @param box Box name. If `NULL`, the active box is used (`box_active()`).
#' @param remove Remove object from box when retrieving it? (default `FALSE`)
#' @export
#' @rdname item-pick
item_pick <- function(id, box = NULL, remove = FALSE) {
  if (!is.numeric(id) && !is.character(id)) {
    cli::cli_alert_warning("{.arg id} is not numeric or string. Is the id correct?")
  }
  id <- as.character(id)
  con <- .box_connection(box)
  on.exit(dbDisconnect(con))
  id_exists <- id %in% box_ids(box)
  if (!id_exists) {
    cli::cli_alert_warning("id {.emph {id}} not found.")
    return(invisible(NULL))
  }
  id_sql <- DBI::dbQuoteString(con, id)
  query <- glue("select object from box where id = {id_sql}")
  res <- dbGetQuery(con, query)
  l <- retrieve_object(res)
  if (remove) {
    item_remove(id, box = box)
    cli::cli_alert_success("Removed item {.val {id}} from box {.emph {box}}.")
  }
  l
}


#' @rdname item-pick
#' @export
pick <- item_pick
