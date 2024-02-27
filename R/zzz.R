globalVariables(".h")

# we use hoardr to manage objects on disk.
.keeper_env <- rlang::env(
  hoard = hoardr::hoard(),
  depot = NULL
)


get_default_depot_name <- function() {
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
  .keeper_env$hoard
}


get_depot <- function() {
  .keeper_env$depot
}


set_depot <- function(name) {
  .keeper_env$depot <- name
}


.onLoad <- function(lib, pkg) {
  options(
    keeper.silent = FALSE,
    keeper.fileext = "db",
    keeper.default_depot = get_default_depot_name()
  )

  # init depot folder on startup
  h <- get_hoard()
  h$cache_path_set(path = "keeper")
  h$mkdir()

  # init default depot
  name <- .opt_default()
  if (!depot_exists(name)) {
    depot_create(name)
    cli::cli_alert_info("Created default depot {.emph {name}}")
  }
  depot_activate(name)
}


.opt_silent <- function() {
  options()$keeper.silent
}

# convenience wrapper to get default shelf name
.opt_default <- function() {
  options()$keeper.default_depot
}
