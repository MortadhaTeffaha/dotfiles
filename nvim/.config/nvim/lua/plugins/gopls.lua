return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      gopls = {
        cmd = { "/opt/homebrew/bin/dd-gopls" },
        cmd_env = {
          GOPLS_DISABLE_MODULE_LOADS = "1",
        },
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
