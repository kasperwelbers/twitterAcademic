#' Collect tweets from the Twitter full search API
#'
#' @param query           A Twitter API query (https://developer.twitter.com/en/docs/twitter-api/tweets/search/integrate/build-a-query)
#' @param start_time      A date (Date, POSIXct, or valid datestring) for the start time (i.e. earliest date). This is required.
#' @param end_time        Optionally, the end time (i.e. most recent date). If a date without time is given (like '2010-01-01'),
#'                        it will be interpreted as the end of the given day ('2010-01-01 23:59:59'). If no end_time is given, the CSV file will note end_time
#'                        as "endoftime", and the query can be repeated to update the csv with recent entries. A CSV file will then never be marked as _finished,
#'                        so running this function would always call the API to check for updates. If you just want the current results, use read_finished=T.
#' @param path            This function will create a folder with csv files to store the results. Default location is the current working directory
#' @param read_finished   If TRUE, read the currently finished tweets instead of continuing the data collection (this only makes sense if the query was performed before, but didn't yet finish)
#' @param just_download   Maybe you just want to download the tweets to a csv without immediately reading them. This argument has your back.
#' @param pagesize        The number of tweets per batch (between 10 and 500). Probably you'll just want to use 500, because there is a limit to the number of calls per 15 minutes
#' @param perseverance    If something goes wrong in the GET request, it will try again 10 times, with some waiting times based on the reason. There should be no reason to increase this
#'                        (if the problem is the API limit, it will wait the exact required time once), but if you want to make sure that your data is running, and you don't mind bothering
#'                        Twitter every few seconds, you might as well crank it up to Infinity.
#' @param progressbar     If TRUE (default) show progress bar. This measures progress as the time difference between the start and end date, so for long period searchers
#'                        it might speed up or slow down depending on how many tweets there are over time.
#'
#'
#' @return
#' @export
#'
#' @examples
twitter_archive_search <- function(query, start_time, end_time=NULL, path=getwd(), read_finished=F, just_download=F, pagesize=500, perseverance=10, progressbar=TRUE) {
  if (pagesize > 500) stop('pagesize is limited to max 500')
  tweet.fields='public_metrics,created_at,author_id,attachments,conversation_id,entities,geo,id,in_reply_to_user_id,lang,possibly_sensitive,referenced_tweets,reply_settings,source,withheld'
  save_columns = c("id", "author_id","source","reply_settings","conversation_id","text","created_at","lang","possibly_sensitive",
    "in_reply_to_user_id","retweet_count","reply_count","like_count","quote_count","place_id",
    "referenced_tweets_json","mentions_json","urls_json","hashtags_json","annotations_json",
    "cashtags_json","media_keys_json")

  if (is.null(start_time)) stop('Start time cannot be NULL')
  if (length(query) > 1) stop('Can only provide 1 query at a time')

  ## make a very likely to be unique name for the current query (including time frame)
  csv_file = gsub(' ', '_', query)
  csv_file = gsub('[^[:alnum:]]', '', csv_file)
  csv_file = paste(csv_file,
    if (!is.null(start_time)) start_time else 'firsttweet',
    if (!is.null(end_time)) end_time else 'endoftime', sep='_')
  csv_file = paste0(csv_file, '.csv')

  ## these ugly named csv files are kept in a separate folder
  folder = file.path(path, 'twitterAcademicData')
  if (!dir.exists(folder)) dir.create(folder)
  csv_file = file.path(folder, csv_file)

  ## finished csv files are marked as finished (when the download loop below is finished)
  if (!is.null(end_time)) {
    finished_csv_file = gsub('\\.csv', '_finished\\.csv', csv_file)
    if (file.exists(finished_csv_file)) return(readr::read_csv(finished_csv_file, col_types=readr::cols()))
  } else finished_csv_file = csv_file

  ## prepare start/end time
  start_time = prepare_time_arg(start_time)
  end_time = prepare_time_arg(end_time, TRUE)
  total_seconds = as.numeric(difftime(end_time, start_time, units='secs'))  ## for progress bar

  ## read the most recent id in the current data. This way the loop continues from the most recent tweet
  until_id = NULL
  if (file.exists(csv_file)) {
    if (read_finished) return(readr::read_csv(csv_file))
    message("NOTE: this search (query + time-frame) was started before, but didn't finish. Will now continue where it left off")
    end_point = get_end_point(csv_file)
    end_time = prepare_time_arg(end_point$end_time)
    until_id = end_point$end_id
  } else {
    if (read_finished) stop("Can't really read the 'finished' tweets if you haven't really started yet, now can you?")
  }

  start_time_string = format(start_time, '%Y-%m-%dT%H:%M:%SZ', tz = "GMT", usetz=FALSE)
  end_time_string = format(end_time, '%Y-%m-%dT%H:%M:%SZ', tz = "GMT", usetz=FALSE)

  next_token = NULL
  req_time = Sys.time() ## twitter likes 1 sec breaks between requests

  if (progressbar) {
    pb <- txtProgressBar(min = 0, max = total_seconds, style = 3)
    time_remaining = as.numeric(difftime(end_time, start_time, units='secs')) ## end time can have been updated
    setTxtProgressBar(pb, total_seconds - time_remaining)
  }

  while (TRUE) {
    time_since_req = as.numeric(difftime(Sys.time(), req_time, units = 'secs'))
    if (time_since_req < 1) Sys.sleep(1 - time_since_req)

    page = twitter_get('tweets/search/all', query=query, tweet.fields=tweet.fields,
      start_time=start_time_string, end_time=end_time_string, max_results=pagesize, next_token=next_token, perseverance=perseverance)
    req_time = Sys.time()
    page = jsonlite::fromJSON(page, flatten = F)

    if (page$meta$result_count > 0) {
      d = as_flat_tibble(page)
      if (!is.null(until_id)) d = d[d$id < until_id,]
      if (nrow(d) > 0) {

        if (progressbar) {
          progress_date = min(as.POSIXct(d$created_at, format='%Y-%m-%dT%H:%M:%OSZ'))
          time_remaining = as.numeric(difftime(progress_date, start_time, units='secs'))
          setTxtProgressBar(pb, total_seconds - time_remaining)
        }

        for (col in save_columns) if (!col %in% colnames(d)) d[[col]] = NA
        if (!file.exists(csv_file))
          readr::write_csv(d[,save_columns], csv_file)
        else
          readr::write_csv(d[,save_columns], csv_file, append=T)
      }
    }

    if (!'next_token' %in% names(page$meta)) {
      file.rename(csv_file, finished_csv_file)
      break
    }
    next_token = page$meta$next_token
  }

  if (!just_download) readr::read_csv(finished_csv_file, col_types=readr::cols())
}

twitter_get <- function(endpoint, ..., perseverance=10) {
  query = list(...)
  query = query[!sapply(query, is.null)]
  url = sprintf('https://api.twitter.com/2/%s', endpoint)

  bearer_token = tryCatch(readRDS(token_file()), error=function(e) NULL, warning=function(w) NULL)
  if (is.null(bearer_token)) stop('You did not yet set a Bearer token. See ?set_bearer_token for more information')
  headers <- c(`Authorization` = sprintf('Bearer %s', bearer_token))

  i = 0
  while (i < perseverance) {
    i = i + 1
    response = httr::GET(url = url, query=query,
      httr::add_headers(.headers = headers))
    if (response$status_code == 200) break
    if (response$status_code == 429) {
      if (as.numeric(response$headers$`x-rate-limit-remaining`) > 0) {
        Sys.sleep(1)
        next
      }
      epoch = response$headers$`x-rate-limit-reset`
      reset_time = as.POSIXct(as.numeric(epoch), origin='1970-01-01')
      sec_till_reset = difftime(reset_time, Sys.time(), units = 'secs')
      if (sec_till_reset > 0) Sys.sleep(as.numeric(sec_till_reset))
    } else if (response$status_code == 503) {
      Sys.sleep(5)
      next
    } else if (response$status_code == 400) {
      mes = httr::content(response, as = "text")
      mes = jsonlite::fromJSON(mes, flatten = F)
      mes = paste(paste(names(mes$errors), as.character(mes$errors), sep=':\n'), collapse='\n\n')
      stop(paste0("Oh shit, Twitter think's your request is bad (400 response status). This probably means something was wrong with your query\n\n", mes))
    } else {
      message(sprintf("Something went wrong! Got this non-ok status code here: %s.\nFor now we'll just wait a few seconds and try again, but if this keeps failing let me know", response$status_code))
      Sys.sleep(5)
    }
  }
  httr::content(response, as = "text")
}

as_flat_tibble <- function(page) {
  ## get data.frames and bind columns
  is_df = sapply(page$data, methods::is, 'data.frame')
  d = list()
  d[['']] = dplyr::as_tibble(page$data[,!is_df])
  for (df_field in which(is_df))
    d[['']] = dplyr::as_tibble(page$data[[df_field]])
  d = dplyr::bind_cols(d)

  ## convert list columns to json
  list_fields = colnames(d)[sapply(d, methods::is, 'list')]
  for (list_field in list_fields) {
    d[[paste0(list_field, '_json')]] = sapply(d[[list_field]], jsonlite::toJSON)
    d[[list_field]] = NULL
  }

  d
}

get_end_point <- function(csv_file) {
  ## the since_id field lets us continue archive search from the highest (i.e. most recent) tweet.
  f <- function(x, pos, acc) {
    date = as.POSIXct(x$created_at, format='%Y-%m-%dT%H:%M:%OSZ')
    list(until_id = min(acc$since_id, x$id, na.rm = T), end_time=min(acc$end_time, date, na.rm=T))
  }
  readr::read_csv_chunked(csv_file, readr::AccumulateCallback$new(f, acc=list(until_id=NA, end_time=as.POSIXct('2100-01-01'))), col_types=readr::cols())
}

prepare_time_arg <- function(time, end_time=F) {
  if (is.null(time) && end_time) time = Sys.time() - as.difftime(10, units = 'secs')
  if (is.null(time)) return(NULL)

  time = as.POSIXct(time)
  if (!methods::is(time, 'POSIXct')) stop('start/end time needs to be a Date, POSIXct, or valid date string')
  if (end_time && format(time, '%H%M%S') == '000000') time = time + as.difftime(24*60*60-1, units = 'secs')
  time
}

