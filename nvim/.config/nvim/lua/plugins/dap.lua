return {
  -- Disable nvim-dap-go so it doesn't override our adapter
  { "leoluz/nvim-dap-go", enabled = false },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      local TEST_BINARY = "/tmp/authzv3_test"
      local GOPATH = "/Users/mortadha.teffaha/go/src/github.com/DataDog/dd-source"
      local WORKDIR = "/Users/mortadha.teffaha/dd/dd-source"

      -- Go adapter: start dlv dap in server mode, connect to it
      dap.adapters.go = {
        type = "server",
        port = "${port}",
        executable = {
          command = "/Users/mortadha.teffaha/go/bin/dlv",
          args = { "dap", "-l", "127.0.0.1:${port}", "--check-go-version=false" },
          detached = true,
          cwd = WORKDIR,
        },
        options = {
          initialize_timeout_sec = 60,
        },
      }

      -- Helper: find nearest test function name by scanning lines upward
      local function get_nearest_test_func()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for i = row, 1, -1 do
          local line = lines[i]
          if line then
            local name = line:match("^func%s+(Test[%w_]+)%s*%(")
            if name then
              return name
            end
          end
        end
        return nil
      end

      -- Helper: find nearest subtest name (t.Run or name: "...")
      local function get_nearest_subtest_name()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for i = row, 1, -1 do
          local line = lines[i]
          if not line then
            goto continue
          end
          local name = line:match('t%.Run%s*%(%s*"([^"]+)"')
          if name then
            return name
          end
          name = line:match('^%s*name:%s*"([^"]+)"')
          if name then
            return name
          end
          ::continue::
        end
        return nil
      end

      -- Convert subtest name to Go's -test.run filter format
      local function subtest_to_filter(test_func, subtest_name)
        if subtest_name then
          local sanitized = subtest_name:gsub("%s", "_")
          sanitized = sanitized:gsub("[^%w_/]", "_")
          return test_func .. "/" .. sanitized
        end
        return test_func
      end

      dap.configurations.go = {
        {
          type = "go",
          name = "Debug subtest under cursor",
          request = "launch",
          mode = "exec",
          program = TEST_BINARY,
          cwd = WORKDIR,
          substitutePath = {
            { from = WORKDIR, to = GOPATH },
            { from = GOPATH, to = WORKDIR },
          },
          args = function()
            local test_func = get_nearest_test_func()
            if not test_func then
              vim.notify("No test function found near cursor", vim.log.levels.ERROR)
              return nil
            end
            local subtest = get_nearest_subtest_name()
            local filter = subtest_to_filter(test_func, subtest)
            vim.notify("Debugging: " .. filter, vim.log.levels.INFO)
            return { "-test.run", filter, "-test.count", "1" }
          end,
        },
        {
          type = "go",
          name = "Debug test function under cursor",
          request = "launch",
          mode = "exec",
          program = TEST_BINARY,
          cwd = WORKDIR,
          substitutePath = {
            { from = WORKDIR, to = GOPATH },
            { from = GOPATH, to = WORKDIR },
          },
          args = function()
            local test_func = get_nearest_test_func()
            if not test_func then
              vim.notify("No test function found near cursor", vim.log.levels.ERROR)
              return nil
            end
            return { "-test.run", test_func, "-test.count", "1" }
          end,
        },
        {
          type = "go",
          name = "Debug all tests in file",
          request = "launch",
          mode = "exec",
          program = TEST_BINARY,
          cwd = WORKDIR,
          substitutePath = {
            { from = WORKDIR, to = GOPATH },
            { from = GOPATH, to = WORKDIR },
          },
          args = { "-test.count", "1" },
        },
      }

      -- Use <leader>dd for debug subtest (LazyVim uses <leader>ds for dap.session())
      vim.keymap.set("n", "<leader>dd", function()
        if not dap.session() then
          for _, cfg in ipairs(dap.configurations.go) do
            if cfg.name == "Debug subtest under cursor" then
              local args = cfg.args()
              if args then
                local run_cfg = vim.deepcopy(cfg)
                run_cfg.args = args
                dap.run(run_cfg)
              end
              return
            end
          end
        else
          dap.continue()
        end
      end, { desc = "Debug subtest under cursor" })

      -- F9 for breakpoint (LazyVim uses <leader>db, but F9 is more ergonomic)
      -- Avoid F11/F12 (macOS Show Desktop / Dashboard)
      vim.keymap.set("n", "<F9>", function() dap.toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<F5>", function() dap.continue() end, { desc = "Start/Continue" })
      vim.keymap.set("n", "<F10>", function() dap.step_over() end, { desc = "Step Over" })
      vim.keymap.set("n", "<F23>", function() dap.step_into() end, { desc = "Step Into" })
      vim.keymap.set("n", "<F24>", function() dap.step_out() end, { desc = "Step Out" })
    end,
  },
}
