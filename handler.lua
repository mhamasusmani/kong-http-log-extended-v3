local cjson = require "cjson"
local uuid = require "resty.uuid"  -- UUID library for unique IDs
local url = require "socket.url"
local serializer = require "kong.plugins.http-log-extended.serializer"
local inspect = require "inspect"

local CustomHttpLogHandler = {}

CustomHttpLogHandler.PRIORITY = 10
CustomHttpLogHandler.VERSION = "1.0"

local HTTP = "http"
local HTTPS = "https"

local function get_request_body()
  ngx.req.read_body()
  return ngx.req.get_body_data()
end

local function generate_post_payload(method, parsed_url, body)
  local url_path = parsed_url.path or "/"
  if parsed_url.query then
    url_path = url_path .. "?" .. parsed_url.query
  end

  local headers = string.format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n",
    method, url_path, parsed_url.host, #body
  )

  if parsed_url.userinfo then
    local auth_header = string.format(
      "Authorization: Basic %s\r\n",
      ngx.encode_base64(parsed_url.userinfo)
    )
    headers = headers .. auth_header
  end

  return string.format("%s\r\n%s", headers, body)
end

local function parse_url(endpoint)
  local parsed = url.parse(endpoint)
  if not parsed.port then
    if parsed.scheme == HTTP then
      parsed.port = 80
     elseif parsed.scheme == HTTPS then
      parsed.port = 443
     end
  end
  if not parsed.path then
    parsed.path = "/"
  end
  return parsed
end

local function log_data(premature, conf, log_body)
  if premature then return end
  local parsed = parse_url(conf.http_endpoint)
  
  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  local ok, err = sock:connect(parsed.host, tonumber(parsed.port))
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to connect to " .. parsed.host .. ":" .. tostring(parsed.port) .. ": ", err)
    return
  end

  if parsed.scheme == "https" then
    local _, ssl_err = sock:sslhandshake(true, parsed.host, false)
    if ssl_err then
      ngx.log(ngx.ERR, "[http-log-extended] SSL handshake failed " .. parsed.host .. ":" .. tostring(parsed.port) .. ": ", ssl_err)
      return
    end
  end

  local payload = generate_post_payload("POST", parsed, log_body)
  ok, err = sock:send(payload)
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to send data " .. parsed.host .. ":" .. tostring(parsed.port) .. ": ", err)
  end

  ok, err = sock:setkeepalive(conf.keepalive)
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to set keepalive " .. parsed.host .. ":" .. tostring(parsed.port) .. ": ", err)
  end
end

function CustomHttpLogHandler:access(conf)
  ngx.ctx.http_log_extended = {
    req_body = conf.log_request_body and get_request_body() or "",
    res_body = "",
  }
end

function CustomHttpLogHandler:body_filter(conf)
  if conf.log_response_body then
    local chunk = ngx.arg[1]
    ngx.ctx.http_log_extended = ngx.ctx.http_log_extended or {}
    ngx.ctx.http_log_extended.res_body = (ngx.ctx.http_log_extended.res_body or "") .. (chunk or "")
  end
end

function CustomHttpLogHandler:log(conf)
  local serialized_data = serializer.serialize(ngx)
  local log_body = cjson.encode(serialized_data)

  local ok, err = ngx.timer.at(0, log_data, conf, serialized_data)
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to create timer: ", err)
  end
end

return CustomHttpLogHandler
