# create hex sticker

library(hexSticker)

path <- "man/figures/logo.png"
img_boxes <- "inst/ext/logo-transparent.png"  # image made by generative ai
color <- "white"
fill <- "#D1C8AE"
border <- "#B38362"

sticker(img_boxes,
  s_x = 1, s_y = .80, s_width = .77,
  package = "boxes", p_size = 30, p_color = color, p_fontface = "plain",
  h_fill = fill, h_color = border, p_y = 1.41, h_size = 1.4,
  filename = path
)

# file.show(path)
