#' Set Twitter API Bearer token
#'
#' To use the Academic Twitter API, you first need to register for an account and get a Bearer token (see details below).
#' You can then use this function to store the token. This is only required once (unless you change your token).
#'
#' First register for a Twitter Academic API licence (https://developer.twitter.com/en/solutions/academic-research).
#' You can then get your "Bearer" key from your Twitter Project & Apps dashboard (https://developer.twitter.com/en/portal/projects-and-apps).
#'
#' Here you should see something along the lines of "Academic Research", with a "Project App".
#' In the Project app you should see a button looking like a key. On the next page you can generate a new Bearer token (you don't need the other tokens)
#' When you generate a new token you should copy it immediately, because you cannot look it up again (only generate a new one).
#' Then just run the set_bearer_token() function, and enter the Token in the password prompt.
#'
#' @return Nothing, just stores the thing
#' @export
#'
#' @examples
#' set_bearer_token()  ## opens a password prompt
set_bearer_token <- function() {
  bt = getPass::getPass(msg = "Enter your Twitter API Bearer Token")
  tf = token_file()
  saveRDS(bt, tf)
  Sys.chmod(tf, mode='0400')
}

token_file <- function() {
  path = Sys.getenv("HOME")
  if (path == '') path = normalizePath('~')
  paste0(path, '/.twit_acad_token.rds')
}

#' Delete Twitter API Bearer token
#'
#' Just in case you really want to.
#'
#' @return Nothing, just deletes the thing
#' @export
#'
#' @examples
#' delete_bearer_token()
delete_bearer_token <- function() {
  file.remove(token_file())
}
