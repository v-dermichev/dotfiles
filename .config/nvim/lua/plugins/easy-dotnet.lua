return {
  "GustavEikaas/easy-dotnet.nvim",
  event = {
    "BufReadPost *.csproj",
    "BufNewFile *.csproj",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
  },
  config = function()
    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    if vim.fn.executable(dotnet_tools .. "/dotnet-easydotnet") == 1 then
      local sep = package.config:sub(1, 1) == "\\" and ";" or ":"
      local path = vim.env.PATH or ""
      if not vim.list_contains(vim.split(path, sep, { plain = true }), dotnet_tools) then
        vim.env.PATH = dotnet_tools .. sep .. path
      end
    end

    require("easy-dotnet").setup({
      picker = "snacks",
      -- roslyn.nvim already owns the C# language server in this config.
      lsp = {
        enabled = false,
      },
      projx_lsp = {
        enabled = true,
      },
      csproj_mappings = true,
      fsproj_mappings = false,
      enable_filetypes = false,
    })
  end,
}
