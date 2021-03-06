#' Load variables from a decennial Census or American Community Survey dataset to search in R
#'
#' @param year The year for which you are requesting variables.  Either the year of the decennial Census,
#'             or the endyear for a 5-year ACS sample.
#' @param dataset One of "sf1", "sf3", "acs5", or "acs5/profile".
#' @param cache Whether you would like to cache the dataset for future access, or load the dataset
#'              from an existing cache. Defaults to FALSE.
#'
#' @return A tibble of variables from the requested dataset.
#' @examples \dontrun{
#' v15 <- load_variables(2015, "acs5", cache = TRUE)
#' View(v15)
#' }
#' @export
load_variables <- function(year, dataset, cache = FALSE) {

  if (dataset=="acs3") {
    if (year > 2013 | year < 2012)
      stop("The current acs3 survey contains data from 2012-2013. Please select a different year.")
  }

  rds <- paste0(dataset, "_", year, ".rds")

  if (dataset == "acs5/profile" | dataset == "acs5/subject" | dataset == "acs1/profile" | dataset == "acs1/subject" |
      dataset == "acs3/profile" | dataset == "acs3/subject") {
    rds <- gsub("/", "_", rds)
  }

  get_dataset <- function(d) {
    set <- paste(as.character(year), d, sep = "/")

    # If ACS, use JSON parsing to speed things up
    if (grepl("acs5", d) | grepl("acs1", d) | grepl("acs3", d)) {
      url <- paste("http://api.census.gov/data",
                   set,
                   "variables.json", sep = "/")

      dat <- GET(url) %>%
        content(as = "text") %>%
        fromJSON() %>%
        modify_depth(2, function(x) {
          x$validValues <- NULL
          x
        }) %>%
        flatten_df(.id = "name") %>%
        arrange(name)

      out <- dat[,1:3]

      return(tbl_df(out))
    # Otherwise use HTML scraping as JSON is not available for decennial Census
    } else {
      url <- paste("http://api.census.gov/data",
                   set,
                   "variables.html", sep = "/")

      dat <- url %>%
        read_html() %>%
        html_nodes("table") %>%
        html_table(fill = TRUE)

      out <- dat[[1]]

      out <- out[-1,]

      out <- out[,1:3]

      names(out) <- tolower(names(out))

      return(tbl_df(out))

    }

  }

  if (cache) {
    cache_dir <- user_cache_dir("tidycensus")
    if (!file.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }

    if (file.exists(cache_dir)) {
      file_loc <- file.path(cache_dir, rds)
      if (file.exists(file_loc)) {
        return(read_rds(file_loc))
      } else {
        df <- get_dataset(dataset)
        write_rds(df, file_loc)
        return(df)
      }
    }
  } else {
    return(get_dataset(dataset))
  }
}

