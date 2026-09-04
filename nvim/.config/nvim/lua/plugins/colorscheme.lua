return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      custom_highlights = function(colors)
        return {
          LineNr = { fg = "#ffffff", bg = "NONE" },
          LineNrAbove = { fg = "#ffffff", bg = "NONE" },
          LineNrBelow = { fg = "#ffffff", bg = "NONE" },
          CursorLineNr = { fg = colors.text, bg = "NONE", bold = true },
        }
      end,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
