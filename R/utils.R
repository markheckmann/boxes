`%||%` <- function(l, r) {
  if (is.null(l)) r else l
}


# from stats::setNames
set_names <- function(object = nm, nm) {
  names(object) <- nm
  object
}
