return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      gopls = {
        settings = {
          gopls = {
            directoryFilters = { "-", "+domains/atlas" },
            analyses = {
              unusedparams = false,
              shadow = false,
            },
            staticcheck = false,
          },
        },
      },
    },
  },
}
