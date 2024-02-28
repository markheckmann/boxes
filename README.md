
<!-- README.md is generated from README.Rmd. Please edit that file -->

# keeper

<!-- badges -->

[![R](https://img.shields.io/badge/language-R-blue)]()
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange)]()
<!-- badges -->

The goal of `keeper` is to provide a convenient way to store R objects
or arbitrary files (plus additional notes) and retrieve them again
later.

To use the package, you need to know a few terms:

- `box`: A container to store things. These things can be R objects or
  files.
- `ìtem`: Anything that is stored inside the a `box`.
- `pack`: adding an item to a box.
- `pick`: retrieving an item from a box.

Boxes are stored on your disk. Hence, anything put into it will remain
there until you delete the box. Technically, each box is a separate
SQLite database. You can create as many boxes as you need.

## Usage

``` r
library(keeper)
depot_create("test")
depot_active()
#> [1] "test"
depots()
#> # A tibble: 2 × 6
#>   name        path        size n_objects modified            created            
#>   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
#> 1 markheckma… …ckmann.db   12K         3 2024-02-28 10:48:18 2024-02-27 23:32:06
#> 2 test        …r/test.db   12K         0 2024-02-28 10:52:56 2024-02-28 10:52:56
depot()
#> # A tibble: 0 × 6
#> # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
#> #   changed <dttm>
keep("my_data", mtcars, "Data to keep for later")
depot()
#> # A tibble: 1 × 6
#>   id             object info                   tags  class   changed            
#>   <chr>          <blob> <chr>                  <chr> <chr>   <dttm>             
#> 1 my_data <raw 1.43 kB> Data to keep for later ""    data.f… 2024-02-28 10:52:56
df <- pick("my_data")
identical(df, mtcars)
#> [1] TRUE
```

## Installation

You can install the development version of keeper like so:

``` r
# TBD
```
