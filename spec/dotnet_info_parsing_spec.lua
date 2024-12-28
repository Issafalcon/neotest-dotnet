describe("Dotnet info parsing should", function()
  local dotnet_utils = require("neotest-dotnet.dotnet_utils")

  it("parse sdk_path from dotnet 9.0.x output on macos", function()
    local output = [[
.NET SDK:
 Version:           9.0.200
 Commit:            90e8b202f2
 Workload version:  9.0.200-manifests.b4a8049f
 MSBuild version:   17.13.8+cbc39bea8

Runtime Environment:
 OS Name:     Mac OS X
 OS Version:  15.1
 OS Platform: Darwin
 RID:         osx-arm64
 Base Path:   /usr/local/share/dotnet/sdk/9.0.200/
]]

    local parsed = dotnet_utils.parse_dotnet_info(output)
    assert.are_equal("/usr/local/share/dotnet/sdk/9.0.200/", parsed.sdk_path)
  end)
  it("parse sdk_path from dotnet 9.0.x output on windows", function()
    local output = [[
.NET SDK:
Version: 9.0.200
Commit: 90e8b202f2
Workload version: 9.0.200-manifests.69179adf
MSBuild version: 17.13.8+cbc39bea8

Runtime Environment:
OS Name: Windows
OS Version: 10.0.26100
OS Platform: Windows
RID: win-x64
Base Path: C:\Program Files\dotnet\sdk\9.0.200\
]]

    local parsed = dotnet_utils.parse_dotnet_info(output)
    assert.are_equal([[C:\Program Files\dotnet\sdk\9.0.200\]], parsed.sdk_path)
  end)
end)
