globalVariables(".h")

# we use hoardr to manage objects on disk.
.boxes_env <- rlang::env(
  hoard = hoardr::hoard(),
  box = NULL,
  rlang::empty_env()
)


get_default_box_name <- function() {
  tryCatch(
    {
      Sys.info()[["user"]]
    },
    error = function(e) {
      "default"
    }
  )
}

# there is one hoard object to manage all objects
get_hoard <- function() {
  .boxes_env$hoard
}


get_box <- function() {
  .boxes_env$box
}


set_box <- function(name) {
  .boxes_env$box <- name
}


.onLoad <- function(lib, pkg) {
  options(
    boxes.silent = FALSE,
    boxes.fileext = "db",
    boxes.default_box = get_default_box_name()
  )

  # init box folder on startup
  h <- get_hoard()
  h$cache_path_set(path = "boxes")
  h$mkdir()

  # init default box
  name <- .opt_default()
  if (!box_exists(name)) {
    box_create(name)
    cli::cli_alert_info("Created default box {.emph {name}}")
  }
  box_activate(name)
}


.opt_silent <- function() {
  options()$boxes.silent
}

# convenience wrapper to get default shelf name
.opt_default <- function() {
  options()$boxes.default_box
}
