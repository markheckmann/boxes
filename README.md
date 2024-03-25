
<!-- README.md is generated from README.Rmd. Please edit that file -->

# boxes

<!-- badges -->

[![R](https://img.shields.io/badge/language-R-blue)]()
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange)]()
<!-- badges -->

The goal of `boxes` is to provide a convenient way to store R objects or
arbitrary files (plus additional notes) and retrieve them again later.

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
library(boxes)
boxes()
#> # A tibble: 1 × 6
#>   name        path        size n_objects modified            created            
#>   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
#> 1 markheckma… …ckmann.db   12K         1 2024-03-25 13:51:19 2024-03-25 13:50:49
box_create("test")
#> ℹ Activated box test
box_active()
#> [1] "test"
box()
#> # A tibble: 0 × 6
#> # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
#> #   changed <dttm>
pack("my_data", mtcars, "Data to keep for later")
box()
#> # A tibble: 1 × 6
#>   id             object info                   tags  class   changed            
#>   <chr>          <blob> <chr>                  <chr> <chr>   <dttm>             
#> 1 my_data <raw 1.43 kB> Data to keep for later ""    data.f… 2024-03-25 13:51:50
df <- pick("my_data")
identical(df, mtcars)
#> [1] TRUE
remove("my_data")
box()
#> # A tibble: 0 × 6
#> # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
#> #   changed <dttm>
box_delete("test")
boxes()
#> # A tibble: 1 × 6
#>   name        path        size n_objects modified            created            
#>   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
#> 1 markheckma… …ckmann.db   12K         1 2024-03-25 13:51:19 2024-03-25 13:50:49
```

## Installation

You can install the development version of `boxes` like so:

``` r
# TBD
```
