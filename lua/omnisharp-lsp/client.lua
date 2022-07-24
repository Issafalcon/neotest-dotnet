local Client = {}

function Client.get_omnisharp_client()
  local clients = vim.lsp.buf_get_clients(0)
  for _, client in pairs(clients) do
    if client.name == "omnisharp" then
      return client
    end
  end

  print("'omnisharp' lsp client not attached to buffer. Please wait for client to be ready.")
  error()
end

function Client.make_basic_request_params()
  local pos = vim.lsp.util.make_position_params()
  local file_name = vim.fn.expand("%:p")

  return {
    fileName = file_name,
    column = pos.position.column,
    line = pos.position.line,
  }
end

--- Make a request on the omnisharp server asynchronously
---@param endpoint The omnisharp endpoint
---@param params Request parameters
---@param callback The callback to invoke with the response from the server
---       when its ready. Format is function({err=<error_message>, result=<response>})
function Client.make_request_async(endpoint, params, callback)
  local status_ok, lsp_client = pcall(Client.get_omnisharp_client)

  if not status_ok then
    error("Omnisharp client is not attached. Cannot make request to server")
  end

  if lsp_client then
    local status, id = lsp_client.request(endpoint, params, callback)

    if not status then
      vim.api.nvim_err_writeln("Error when executing " .. endpoint .. " : " .. id)
      return
    end
  end
end

function Client.make_request(endpoint, params)
  local status_ok, lsp_client = pcall(Client.get_omnisharp_client)

  if not status_ok then
    error()
  end

  if lsp_client then
    local result, err = lsp_client.request_sync(endpoint, params, 100000)

    if err then
      vim.api.nvim_err_writeln("Error when executing " .. endpoint .. " : " .. err)
      return
    end

    return result
  end
end

return Client
