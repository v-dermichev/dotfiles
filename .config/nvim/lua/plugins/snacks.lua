local image_formats = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
  "tiff",
  "heic",
  "avif",
  "mp4",
  "mov",
  "avi",
  "mkv",
  "webm",
  "pdf",
  "icns",
}

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    image = {
      enabled = not vim.g.neovide,
      formats = image_formats,
      doc = {
        enabled = true,
        inline = true,
        float = true,
      },
    },
    indent = {
      enabled = true,
      indent = { char = "│" },
      scope = { enabled = true, char = "│" },
      animate = { enabled = false },
    },
  },
}
