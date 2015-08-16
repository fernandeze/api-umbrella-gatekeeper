local host_normalize = require "api-umbrella.utils.host_normalize"
local lyaml = require "lyaml"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local cache_computed_settings = utils.cache_computed_settings
local log = ngx.log
local ERR = ngx.ERR

local function read_file()
  local f, err = io.open(os.getenv("API_UMBRELLA_CONFIG"), "rb")
  if err then
    log(ERR, "failed to open config file: ", err)
    return nil
  end

  local content = f:read("*all")
  f:close()

  return lyaml.load(content)
end

local function set_defaults(data)
  local default_hostname
  if data["hosts"] then
    for _, host in ipairs(data["hosts"]) do
      if host["default"] and host["hostname"] then
        default_hostname = host_normalize(host["hostname"])
        break
      end
    end
  end

  data["_default_hostname"] = default_hostname

  local default_hostname_replacement = default_hostname or "localhost"
  if data["internal_apis"] then
    for _, api in ipairs(data["internal_apis"]) do
      if api["frontend_host"] == "{{default_hostname}}" then
        api["frontend_host"] = default_hostname_replacement
      end
    end
  end

  if data["internal_website_backends"] then
    for _, website in ipairs(data["internal_website_backends"]) do
      if website["frontend_host"] == "{{default_hostname}}" then
        website["frontend_host"] = default_hostname_replacement
      end

      if website["server_host"] == "{{static_site.host}}" then
        website["server_host"] = data["static_site"]["host"]
      end

      if website["server_port"] == "{{static_site.port}}" then
        website["server_port"] = data["static_site"]["port"]
      end
    end
  end

  local combined_apis = {}
  append_array(combined_apis, data["internal_apis"] or {})
  append_array(combined_apis, data["apis"] or {})
  data["_apis"] = combined_apis
  data["apis"] = nil
  data["internal_apis"] = nil

  local combined_website_backends = {}
  append_array(combined_website_backends, data["internal_website_backends"] or {})
  append_array(combined_website_backends, data["website_backends"] or {})
  data["_website_backends"] = combined_website_backends
  data["website_backends"] = nil
  data["internal_website_backends"] = nil
end

local function read()
  local data = read_file()
  nillify_yaml_nulls(data)
  set_defaults(data)
  cache_computed_settings(data["apiSettings"])

  return data
end

return read()