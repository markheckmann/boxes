globalVariables(".h")

# we use hoardr to manage objects on disk.
.boxed_env <- rlang::env(
  hoard = hoardr::hoard(),
  box = NULL
)#


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
  .boxed_env$hoard
}


get_box <- function() {
  .boxed_env$box
}


set_box <- function(name) {
  .boxed_env$box <- name
}


.onLoad <- function(lib, pkg) {
  options(
    boxed.silent = FALSE,
    boxed.fileext = "db",
    boxed.default_box = get_default_box_name()
  )

  # init box folder on startup
  h <- get_hoard()
  h$cache_path_set(path = "boxed")
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
  options()$boxed.silent
}

# convenience wrapper to get default shelf name
.opt_default <- function() {
  options()$boxed.default_box
}
