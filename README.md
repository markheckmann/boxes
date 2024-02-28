
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

- `box`: A container to store things. Things can be R objects or files.
- `item`: Anything that is stored inside the a box.
- `pack`: adding an item to a box.
- `pick`: retrieving an item from a box.

Boxes are stored on your disk. Hence, anything put into it will remain
there until you delete the box. Technically, each box is a separate
SQLite database. You can create as many boxes as you need.

## Usage

``` r
library(boxed)
box_create("test")
box_active()
#> [1] "test"
boxes()
#> # A tibble: 2 × 6
#>   name        path        size n_objects modified            created            
#>   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
#> 1 markheckma… …ckmann.db   12K         1 2024-02-28 11:43:58 2024-02-28 11:25:40
#> 2 test        …d/test.db   12K         0 2024-02-28 11:47:07 2024-02-28 11:47:06
box()
#> # A tibble: 0 × 6
#> # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
#> #   changed <dttm>
pack("my_data", mtcars, "Data to keep for later")
box()
#> # A tibble: 1 × 6
#>   id             object info                   tags  class   changed            
#>   <chr>          <blob> <chr>                  <chr> <chr>   <dttm>             
#> 1 my_data <raw 1.43 kB> Data to keep for later ""    data.f… 2024-02-28 11:47:07
df <- pick("my_data")
identical(df, mtcars)
#> [1] TRUE
```

## Installation

You can install the development version of keeper like so:

``` r
# TBD
```
