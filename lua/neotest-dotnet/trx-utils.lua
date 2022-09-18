local lib = require("neotest.lib")
local logger = require("neotest.logging")

local trx_utils = {}

local function remove_bom(str)
  if string.byte(str, 1) == 239 and string.byte(str, 2) == 187 and string.byte(str, 3) == 191 then
    str = string.sub(str, 4)
  end
  return str
end

trx_utils.parse_trx = function (output_file)
  local success, xml = pcall(lib.files.read, output_file)

  if not success then
    logger.error("No test output file found ")
    return {}
  end

  local no_bom_xml = remove_bom(xml)

  local ok, parsed_data = pcall(lib.xml.parse, no_bom_xml)
  if not ok then
    logger.error("Failed to parse test output:", output_file)
    return {}
  end

  return parsed_data
end

return trx_utils
