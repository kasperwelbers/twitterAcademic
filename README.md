# DEPRECATION WARNING

By now, this ad-hoc package outlived it's main purpose, since a more dedicated effort exists in the [academictwitteR](https://cran.r-project.org/web/packages/academictwitteR/index.html) package (the very similar name is pure coincidence, and testifies to our stunning originality).

This package still works at the moment, but since this alternative exists we have little reason to add features or maintain this thing. So if you're looking for a package to use the Academic Twitter API, we strongly recommend using academictwitteR.

I think there are also plans to integrate support for the Twitter V2 api (which is required for using the Academic Twitter licence) in the more longer running rtweet package, but it doesn't yet seem to be available. Anyway, you know how to Google, just saying.

# twitterAcademic

> Really, you're writing an R package for the Twitter API? You didn't bother to check and find out that there's already this excellent rtweet package out there?

We did, but the fancy new [Academic Twitter license](https://developer.twitter.com/en/solutions/academic-research) works with API V2, and that's not yet supported. In time it probably will, but in the meantime we needed this, so there.
You can install the package from GitHub.

```{r}
library(remotes)
install_github('kasperwelbers/twitterAcademic')
```


There are really only two functions of notice, but they should be all you need if you just want to use the full archive search.
The first function let's you store the Bearer Token (see details on how to get this token in the `?set_bearer_token` documentation).
Running it will open a password prompt to enter the token, which will then be stored in a hidden file with restricted access in your home folder.
You can also delete the token with delete_bearer_token(), but why would you.

```{r}
set_bearer_token()
```

Once you've set your token, you're good to go.
With the `twitter_archive_search` function you can search the  full archive.
It is designed to easily handle big downloads, possibly over multiple sessions.

* A folder called `twitterAcademicData` will be created in your working directory, in which all search results are stored in CSV files. 
* Every unique query (including start and end time) is stored as a separate CSV.
* If you crash along the way, or need to shutdown your computer, you can pick-up the download right where it left of when you use the same query. 
* The Academic API has pretty OK limits. You can do 300 batches of 500 tweets every 15 minutes, and you should have a total of 10.000.000 tweets per month. You can see how much you have left on your [dashboard](https://developer.twitter.com/en/portal/dashboard). The `twitter_archive_search` function manages the waiting times, so in theory you should be able to just keep it running for days.
* Once finished, you will get a tibble with the tweets. 

```{r}
d = twitter_archive_search("your query"", start_time="2020-01-01", end_time="2020-02-01")
```

* The V2 query is quite flexible, so check out the [docs](https://developer.twitter.com/en/docs/twitter-api/tweets/search/integrate/build-a-query).
* The `start_time` and `end_time` can also be a POSIXct date, if you want to query at the level of seconds.  
* You can also just download the results with the `only_download` argument, or view the results before finishing the download with `read_finished`. 


# Disclaimer

Rome wasn't built in a day. This package has nothing to do with Rome, but it was built in a day, and it shows. 
We have no deep ambition to develop an R package for the Twitter API, but if you run into bugs please do let me know and we will maintain this thing as long as needed (i.e. when rtweet tackles V2). We might also implement some additional features, since the groundwork is there anyway, so feel free to ask.
