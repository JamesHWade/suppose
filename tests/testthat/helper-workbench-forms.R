form_session <- function(x, existing = list()) {
  published <- new.env(parent = emptyenv())
  published$drafts <- list()
  session <- new_proposal_session(
    function() x,
    general = TRUE,
    get_form_state = function() existing,
    publish_form = function(d) published$drafts[[d$form]] <- d
  )
  list(session = session, published = published)
}
