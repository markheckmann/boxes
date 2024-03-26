
<!-- README.md is generated from README.Rmd. Please edit that file -->

# boxes: store and retrieve arbitrary R objects

<a href="https://github.com/markheckmann/boxes"><img src="man/figures/logo.png" align="right" height="138" /></a>

<!-- badges -->

[![R](https://img.shields.io/badge/language-R-blue)]()
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange)]()
<!-- badges -->

The goal of `boxes` is to provide a convenient way to store R objects or
arbitrary files (plus additional notes) and retrieve them again later.

To use the package, you need to know a few terms:

- `box`: A container to store things. Things can be R objects or files.
- `item`: Anything stored inside a box.
- `pack`: Adding an item to a box.
- `pick`: Retrieving an item from a box.

Boxes are stored on your disk. Hence, anything put into it will remain
there until you delete the box. Technically, each box is a separate
SQLite database. You can create as many boxes as you need.

## Installation

You can install the dev version of `boxes` like so:

``` r
devtools::install_github("markheckmann/boxes")
```

## Usage

Load package and show existings boxes. A box with your username exists
by default.

``` r
library(boxes)
boxes()
# # A tibble: 1 × 6
#   name        path        size n_objects modified            created            
#   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
# 1 markheckma… …ckmann.db   12K         3 2024-03-26 14:41:29 2024-03-25 13:50:49
```

Create a new box and see that it is empty.

``` r
box_create("test")
# ℹ Activating box test
box_active()
# [1] "test"
box()
# # A tibble: 0 × 6
# # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
# #   changed <dttm>
```

Add a new object to the box.

``` r
pack(mtcars, "my_data", "Data to keep for later")
box()
# # A tibble: 1 × 6
#   id             object info                   tags  class   changed            
#   <chr>          <blob> <chr>                  <chr> <chr>   <dttm>             
# 1 my_data <raw 1.43 kB> Data to keep for later ""    data.f… 2024-03-26 14:47:18
```

Retrieve an object from a box and remove it.

``` r
x <- pick("my_data")
identical(x, mtcars)
# [1] TRUE
remove("my_data")
```

Check if item is gone and delete box.

``` r
box()
# # A tibble: 0 × 6
# # ℹ 6 variables: id <chr>, object <blob>, info <chr>, tags <chr>, class <chr>,
# #   changed <dttm>
box_delete("test")
boxes()
# # A tibble: 1 × 6
#   name        path        size n_objects modified            created            
#   <chr>       <fs::path> <fs:>     <int> <dttm>              <dttm>             
# 1 markheckma… …ckmann.db   12K         3 2024-03-26 14:41:29 2024-03-25 13:50:49
```
