# boxes 0.2.0 (dev version)

* rename `box_activate` to `box_switch` (#7)
* `box_purge`: removes expired (or all) items from (active) box (#6)
* `pack`: arg `expires` to set an expiration date for an item (#6)
* `pick`: get lastest item if `id = NULL` (#3)
* `pack`: use object name as default `id`.
* Rename package to `boxes`.

# boxed 0.1.1

* `remove`, `item_remove`: remove an item from a box.
* Rename package to `boxed`. A depot becomes a `box`, `keep` becomes `pack`

# keeper 0.1.0

* `depot_export` and `depot_import`: store and retrieve a depot in a file on/from disk.
* `keep_file` to add a file from disk to a depot.
* `keep` and `pick` to add and retrieve objects from depot.
* Add basic depot handlers `depots_*` and `depot_*`.
