.deprecation_seen <- new.env(parent = emptyenv())

.warn_deprecation <- function(name, replacement) {
  if (exists(name, .deprecation_seen, inherits = FALSE)) return(invisible(NULL))
  assign(name, TRUE, .deprecation_seen)
  message <- paste0("'", name, "' is deprecated since HeatStressR 3.0.0; use '",
    replacement, "'. Removal is planned no earlier than 4.0.0.")
  warning(structure(list(message = message, call = NULL),
    class = c("heatstressr_deprecation", "warning", "condition")))
  invisible(NULL)
}
