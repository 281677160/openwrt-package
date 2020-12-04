local d = require "luci.dispatcher"
local api = require "luci.model.cbi.passwall.api.api"

local ss_encrypt_method_list = {
    "rc4-md5", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "aes-128-ctr",
    "aes-192-ctr", "aes-256-ctr", "bf-cfb", "camellia-128-cfb",
    "camellia-192-cfb", "camellia-256-cfb", "salsa20", "chacha20",
    "chacha20-ietf", -- aead
    "aes-128-gcm", "aes-192-gcm", "aes-256-gcm", "chacha20-ietf-poly1305",
    "xchacha20-ietf-poly1305"
}

local ssr_encrypt_method_list = {
    "none", "table", "rc2-cfb", "rc4", "rc4-md5", "rc4-md5-6", "aes-128-cfb",
    "aes-192-cfb", "aes-256-cfb", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr",
    "bf-cfb", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb",
    "cast5-cfb", "des-cfb", "idea-cfb", "seed-cfb", "salsa20", "chacha20",
    "chacha20-ietf"
}

local ssr_protocol_list = {
    "origin", "verify_simple", "verify_deflate", "verify_sha1", "auth_simple",
    "auth_sha1", "auth_sha1_v2", "auth_sha1_v4", "auth_aes128_md5",
    "auth_aes128_sha1", "auth_chain_a", "auth_chain_b", "auth_chain_c",
    "auth_chain_d", "auth_chain_e", "auth_chain_f"
}
local ssr_obfs_list = {
    "plain", "http_simple", "http_post", "random_head", "tls_simple",
    "tls1.0_session_auth", "tls1.2_ticket_auth"
}

local v_ss_encrypt_method_list = {
    "aes-128-cfb", "aes-256-cfb", "aes-128-gcm", "aes-256-gcm", "chacha20", "chacha20-ietf", "chacha20-poly1305", "chacha20-ietf-poly1305"
}

local header_type_list = {
    "none", "srtp", "utp", "wechat-video", "dtls", "wireguard"
}

local encrypt_methods_ss_aead = {
	"dummy",
	"aead_chacha20_poly1305",
	"aead_aes_128_gcm",
	"aead_aes_256_gcm",
	"chacha20-ietf-poly1305",
	"aes-128-gcm",
	"aes-256-gcm",
}

m = Map("passwall_server", translate("Server Config"))
m.redirect = d.build_url("admin", "services", "passwall", "server")

s = m:section(NamedSection, arg[1], "user", "")
s.addremove = false
s.dynamic = false

share = s:option(DummyValue, "passwall_server", translate("Share Current"))
share.rawhtml  = true
share.template = "passwall/node_list/link_share_man"
share.value = arg[1]

enable = s:option(Flag, "enable", translate("Enable"))
enable.default = "1"
enable.rmempty = false

remarks = s:option(Value, "remarks", translate("Remarks"))
remarks.default = translate("Remarks")
remarks.rmempty = false

type = s:option(ListValue, "type", translate("Type"))
if api.is_finded("microsocks") then
    type:value("Socks", translate("Socks"))
end
if api.is_finded("ss-server") then
    type:value("SS", translate("Shadowsocks"))
end
if api.is_finded("ssr-server") then
    type:value("SSR", translate("ShadowsocksR"))
end
if api.is_finded("xray") then
    type:value("Xray", translate("Xray"))
end
if api.is_finded("v2ray") then
    type:value("V2ray", translate("V2ray"))
end
if api.is_finded("brook") then
    type:value("Brook", translate("Brook"))
end
--[[
if api.is_finded("trojan-plus") or api.is_finded("trojan") then
    type:value("Trojan", translate("Trojan"))
end
]]--
if api.is_finded("trojan-plus") then
    type:value("Trojan-Plus", translate("Trojan-Plus"))
end
if api.is_finded("trojan-go") then
    type:value("Trojan-Go", translate("Trojan-Go"))
end

protocol = s:option(ListValue, "protocol", translate("Protocol"))
protocol:value("vmess", "Vmess")
protocol:value("vless", "VLESS")
protocol:value("http", "HTTP")
protocol:value("socks", "Socks")
protocol:value("shadowsocks", "Shadowsocks")
protocol:value("trojan", "Trojan")
protocol:value("mtproto", "MTProto")
protocol:depends("type", "Xray")
protocol:depends("type", "V2ray")

-- Brook协议
brook_protocol = s:option(ListValue, "brook_protocol", translate("Protocol"))
brook_protocol:value("server", "Brook")
brook_protocol:value("wsserver", "WebSocket")
brook_protocol:depends("type", "Brook")
function brook_protocol.cfgvalue(self, section)
	return m:get(section, "protocol")
end
function brook_protocol.write(self, section, value)
	m:set(section, "protocol", value)
end

brook_tls = s:option(Flag, "brook_tls", translate("Use TLS"))
brook_tls:depends("brook_protocol", "wsserver")

port = s:option(Value, "port", translate("Port"))
port.datatype = "port"
port.rmempty = false

auth = s:option(Flag, "auth", translate("Auth"))
auth.validate = function(self, value, t)
    if value and value == "1" then
        local user_v = username:formvalue(t) or ""
        local pass_v = password:formvalue(t) or ""
        if user_v == "" or pass_v == "" then
            return nil, translate("Username and Password must be used together!")
        end
    end
    return value
end
auth:depends("type", "Socks")
auth:depends({ type = "Xray", protocol = "socks" })
auth:depends({ type = "Xray", protocol = "http" })
auth:depends({ type = "V2ray", protocol = "socks" })
auth:depends({ type = "V2ray", protocol = "http" })

username = s:option(Value, "username", translate("Username"))
username:depends("auth", "1")

password = s:option(Value, "password", translate("Password"))
password.password = true
password:depends("auth", "1")
password:depends("type", "SS")
password:depends("type", "SSR")
password:depends("type", "Brook")
password:depends({ type = "Xray", protocol = "shadowsocks" })
password:depends({ type = "V2ray", protocol = "shadowsocks" })

mtproto_password = s:option(Value, "mtproto_password", translate("Password"), translate("The MTProto protocol must be 32 characters and can only contain characters from 0 to 9 and a to f."))
mtproto_password:depends({ type = "Xray", protocol = "mtproto" })
mtproto_password:depends({ type = "V2ray", protocol = "mtproto" })
mtproto_password.default = arg[1]
function mtproto_password.cfgvalue(self, section)
	return m:get(section, "password")
end
function mtproto_password.write(self, section, value)
	m:set(section, "password", value)
end

decryption = s:option(Value, "decryption", translate("Encrypt Method"))
decryption.default = "none"
decryption:depends({ type = "Xray", protocol = "vless" })
decryption:depends({ type = "V2ray", protocol = "vless" })

ss_encrypt_method = s:option(ListValue, "ss_encrypt_method", translate("Encrypt Method"))
for a, t in ipairs(ss_encrypt_method_list) do ss_encrypt_method:value(t) end
ss_encrypt_method:depends("type", "SS")
function ss_encrypt_method.cfgvalue(self, section)
	return m:get(section, "method")
end
function ss_encrypt_method.write(self, section, value)
	m:set(section, "method", value)
end

ssr_encrypt_method = s:option(ListValue, "ssr_encrypt_method", translate("Encrypt Method"))
for a, t in ipairs(ssr_encrypt_method_list) do ssr_encrypt_method:value(t) end
ssr_encrypt_method:depends("type", "SSR")
function ssr_encrypt_method.cfgvalue(self, section)
	return m:get(section, "method")
end
function ssr_encrypt_method.write(self, section, value)
	m:set(section, "method", value)
end

v_ss_encrypt_method = s:option(ListValue, "v_ss_encrypt_method", translate("Encrypt Method"))
for a, t in ipairs(v_ss_encrypt_method_list) do v_ss_encrypt_method:value(t) end
v_ss_encrypt_method:depends({ type = "Xray", protocol = "shadowsocks" })
v_ss_encrypt_method:depends({ type = "V2ray", protocol = "shadowsocks" })
function v_ss_encrypt_method.cfgvalue(self, section)
	return m:get(section, "method")
end
function v_ss_encrypt_method.write(self, section, value)
	m:set(section, "method", value)
end

ss_network = s:option(ListValue, "ss_network", translate("Transport"))
ss_network.default = "tcp,udp"
ss_network:value("tcp", "TCP")
ss_network:value("udp", "UDP")
ss_network:value("tcp,udp", "TCP,UDP")
ss_network:depends({ type = "Xray", protocol = "shadowsocks" })
ss_network:depends({ type = "V2ray", protocol = "shadowsocks" })

ssr_protocol = s:option(ListValue, "ssr_protocol", translate("Protocol"))
for a, t in ipairs(ssr_protocol_list) do ssr_protocol:value(t) end
ssr_protocol:depends("type", "SSR")
function ssr_protocol.cfgvalue(self, section)
	return m:get(section, "protocol")
end
function ssr_protocol.write(self, section, value)
	m:set(section, "protocol", value)
end

protocol_param = s:option(Value, "protocol_param", translate("Protocol_param"))
protocol_param:depends("type", "SSR")

obfs = s:option(ListValue, "obfs", translate("Obfs"))
for a, t in ipairs(ssr_obfs_list) do obfs:value(t) end
obfs:depends("type", "SSR")

obfs_param = s:option(Value, "obfs_param", translate("Obfs_param"))
obfs_param:depends("type", "SSR")

timeout = s:option(Value, "timeout", translate("Connection Timeout"))
timeout.datatype = "uinteger"
timeout.default = 300
timeout:depends("type", "SS")
timeout:depends("type", "SSR")

udp_forward = s:option(Flag, "udp_forward", translate("UDP Forward"))
udp_forward.default = "1"
udp_forward.rmempty = false
udp_forward:depends("type", "SSR")

uuid = s:option(DynamicList, "uuid", translate("ID") .. "/" .. translate("Password"))
for i = 1, 3 do
    uuid:value(api.gen_uuid(1))
end
uuid:depends({ type = "Xray", protocol = "vmess" })
uuid:depends({ type = "Xray", protocol = "vless" })
uuid:depends({ type = "Xray", protocol = "trojan" })
uuid:depends({ type = "V2ray", protocol = "vmess" })
uuid:depends({ type = "V2ray", protocol = "vless" })
uuid:depends({ type = "V2ray", protocol = "trojan" })
uuid:depends("type", "Trojan")
uuid:depends("type", "Trojan-Go")
uuid:depends("type", "Trojan-Plus")

alter_id = s:option(Value, "alter_id", translate("Alter ID"))
alter_id.default = 16
alter_id:depends({ type = "Xray", protocol = "vmess" })
alter_id:depends({ type = "V2ray", protocol = "vmess" })

level = s:option(Value, "level", translate("User Level"))
level.default = 1
level:depends({ type = "Xray", protocol = "vmess" })
level:depends({ type = "Xray", protocol = "vless" })
level:depends({ type = "Xray", protocol = "shadowsocks" })
level:depends({ type = "Xray", protocol = "trojan" })
level:depends({ type = "Xray", protocol = "mtproto" })
level:depends({ type = "V2ray", protocol = "vmess" })
level:depends({ type = "V2ray", protocol = "vless" })
level:depends({ type = "V2ray", protocol = "shadowsocks" })
level:depends({ type = "V2ray", protocol = "trojan" })
level:depends({ type = "V2ray", protocol = "mtproto" })

tls = s:option(Flag, "tls", translate("TLS"))
tls.default = 0
tls.validate = function(self, value, t)
    if value then
        local type = type:formvalue(t) or ""
        if value == "0" and (type == "Trojan" or type == "Trojan-Plus") then
            return nil, translate("Original Trojan only supported 'tls', please choose 'tls'.")
        end
        if value == "1" then
            local ca = tls_certificateFile:formvalue(t) or ""
            local key = tls_keyFile:formvalue(t) or ""
            if ca == "" or key == "" then
                return nil, translate("Public key and Private key path can not be empty!")
            end
        end
        return value
    end
end
tls:depends({ type = "Xray", protocol = "vmess" })
tls:depends({ type = "Xray", protocol = "vless" })
tls:depends({ type = "Xray", protocol = "socks" })
tls:depends({ type = "Xray", protocol = "shadowsocks" })
tls:depends({ type = "V2ray", protocol = "vmess" })
tls:depends({ type = "V2ray", protocol = "vless" })
tls:depends({ type = "V2ray", protocol = "socks" })
tls:depends({ type = "V2ray", protocol = "shadowsocks" })
tls:depends("type", "Trojan")
tls:depends("type", "Trojan-Plus")
tls:depends("type", "Trojan-Go")

xtls = s:option(Flag, "xtls", translate("XTLS"))
xtls.default = 0
xtls:depends({ type = "Xray", protocol = "vless", tls = "1" })

flow = s:option(Value, "flow", translate("flow"))
flow.default = "xtls-rprx-origin"
flow:value("xtls-rprx-origin")
flow:value("xtls-rprx-origin-udp443")
flow:value("xtls-rprx-direct")
flow:value("xtls-rprx-direct-udp443")
flow:value("xtls-rprx-splice")
flow:value("xtls-rprx-splice-udp443")
flow:depends("xtls", "1")

-- [[ TLS部分 ]] --

tls_allowInsecure = s:option(Flag, "tls_allowInsecure", translate("allowInsecure"), translate("Whether unsafe connections are allowed. When checked, Certificate validation will be skipped."))
tls_allowInsecure.default = "0"
tls_allowInsecure:depends({ type = "Trojan", tls = "1" })
tls_allowInsecure:depends({ type = "Trojan-Plus", tls = "1" })
tls_allowInsecure:depends({ type = "Trojan-Go", tls = "1" })

tls_serverName = s:option(Value, "tls_serverName", translate("Domain"))
tls_serverName:depends("tls", "1")

tls_certificateFile = s:option(Value, "tls_certificateFile", translate("Public key absolute path"), translate("as:") .. "/etc/ssl/fullchain.pem")
tls_certificateFile.validate = function(self, value, t)
    if value and value ~= "" then
        if not nixio.fs.access(value) then
            return nil, translate("Can't find this file!")
        else
            return value
        end
    end
    return nil
end
tls_certificateFile:depends("tls", "1")

tls_keyFile = s:option(Value, "tls_keyFile", translate("Private key absolute path"), translate("as:") .. "/etc/ssl/private.key")
tls_keyFile.validate = function(self, value, t)
    if value and value ~= "" then
        if not nixio.fs.access(value) then
            return nil, translate("Can't find this file!")
        else
            return value
        end
    end
    return nil
end
tls_keyFile:depends("tls", "1")

tls_sessionTicket = s:option(Flag, "tls_sessionTicket", translate("Session Ticket"))
tls_sessionTicket.default = "0"
tls_sessionTicket:depends({ type = "Trojan", tls = "1" })
tls_sessionTicket:depends({ type = "Trojan-Plus", tls = "1" })
tls_sessionTicket:depends({ type = "Trojan-Go", tls = "1" })

transport = s:option(ListValue, "transport", translate("Transport"))
transport:value("tcp", "TCP")
transport:value("mkcp", "mKCP")
transport:value("ws", "WebSocket")
transport:value("h2", "HTTP/2")
transport:value("ds", "DomainSocket")
transport:value("quic", "QUIC")
transport:depends({ type = "Xray", protocol = "vmess" })
transport:depends({ type = "Xray", protocol = "vless" })
transport:depends({ type = "Xray", protocol = "socks" })
transport:depends({ type = "Xray", protocol = "shadowsocks" })
transport:depends({ type = "Xray", protocol = "trojan" })
transport:depends({ type = "V2ray", protocol = "vmess" })
transport:depends({ type = "V2ray", protocol = "vless" })
transport:depends({ type = "V2ray", protocol = "socks" })
transport:depends({ type = "V2ray", protocol = "shadowsocks" })
transport:depends({ type = "V2ray", protocol = "trojan" })

trojan_transport = s:option(ListValue, "trojan_transport", translate("Transport"))
trojan_transport:value("original", "Original")
trojan_transport:value("ws", "WebSocket")
trojan_transport:value("h2", "HTTP/2")
trojan_transport:value("h2+ws", "HTTP/2 & WebSocket")
trojan_transport.default = "ws"
trojan_transport:depends("type", "Trojan-Go")

trojan_plugin = s:option(ListValue, "plugin_type", translate("Plugin Type"))
trojan_plugin:value("plaintext", "Plain Text")
trojan_plugin:value("shadowsocks", "ShadowSocks")
trojan_plugin:value("other", "Other")
trojan_plugin.default = "plaintext"
trojan_plugin:depends({ tls = "0", trojan_transport = "original" })

trojan_plugin_cmd = s:option(Value, "plugin_cmd", translate("Plugin Binary"))
trojan_plugin_cmd.placeholder = "eg: /usr/bin/v2ray-plugin"
trojan_plugin_cmd:depends({ plugin_type = "shadowsocks" })
trojan_plugin_cmd:depends({ plugin_type = "other" })

trojan_plugin_op = s:option(Value, "plugin_option", translate("Plugin Option"))
trojan_plugin_op.placeholder = "eg: obfs=http;obfs-host=www.baidu.com"
trojan_plugin_op:depends({ plugin_type = "shadowsocks" })
trojan_plugin_op:depends({ plugin_type = "other" })

trojan_plugin_arg = s:option(DynamicList, "plugin_arg", translate("Plugin Option Args"))
trojan_plugin_arg.placeholder = "eg: [\"-config\", \"test.json\"]"
trojan_plugin_arg:depends({ plugin_type = "shadowsocks" })
trojan_plugin_arg:depends({ plugin_type = "other" })

-- [[ WebSocket部分 ]]--

ws_host = s:option(Value, "ws_host", translate("WebSocket Host"))
ws_host:depends("transport", "ws")
ws_host:depends("ss_transport", "ws")
ws_host:depends("trojan_transport", "h2+ws")
ws_host:depends("trojan_transport", "ws")

ws_path = s:option(Value, "ws_path", translate("WebSocket Path"))
ws_path:depends("transport", "ws")
ws_path:depends("ss_transport", "ws")
ws_path:depends("trojan_transport", "h2+ws")
ws_path:depends("trojan_transport", "ws")

-- [[ HTTP/2部分 ]]--

h2_host = s:option(Value, "h2_host", translate("HTTP/2 Host"))
h2_host:depends("transport", "h2")
h2_host:depends("ss_transport", "h2")
h2_host:depends("trojan_transport", "h2+ws")
h2_host:depends("trojan_transport", "h2")

h2_path = s:option(Value, "h2_path", translate("HTTP/2 Path"))
h2_path:depends("transport", "h2")
h2_path:depends("ss_transport", "h2")
h2_path:depends("trojan_transport", "h2+ws")
h2_path:depends("trojan_transport", "h2")

-- [[ TCP部分 ]]--

-- TCP伪装
tcp_guise = s:option(ListValue, "tcp_guise", translate("Camouflage Type"))
tcp_guise:value("none", "none")
tcp_guise:value("http", "http")
tcp_guise:depends("transport", "tcp")

-- HTTP域名
tcp_guise_http_host = s:option(DynamicList, "tcp_guise_http_host", translate("HTTP Host"))
tcp_guise_http_host:depends("tcp_guise", "http")

-- HTTP路径
tcp_guise_http_path = s:option(DynamicList, "tcp_guise_http_path", translate("HTTP Path"))
tcp_guise_http_path:depends("tcp_guise", "http")

-- [[ mKCP部分 ]]--

mkcp_guise = s:option(ListValue, "mkcp_guise", translate("Camouflage Type"), translate('<br />none: default, no masquerade, data sent is packets with no characteristics.<br />srtp: disguised as an SRTP packet, it will be recognized as video call data (such as FaceTime).<br />utp: packets disguised as uTP will be recognized as bittorrent downloaded data.<br />wechat-video: packets disguised as WeChat video calls.<br />dtls: disguised as DTLS 1.2 packet.<br />wireguard: disguised as a WireGuard packet. (not really WireGuard protocol)'))
for a, t in ipairs(header_type_list) do mkcp_guise:value(t) end
mkcp_guise:depends("transport", "mkcp")

mkcp_mtu = s:option(Value, "mkcp_mtu", translate("KCP MTU"))
mkcp_mtu.default = "1350"
mkcp_mtu:depends("transport", "mkcp")

mkcp_tti = s:option(Value, "mkcp_tti", translate("KCP TTI"))
mkcp_tti.default = "20"
mkcp_tti:depends("transport", "mkcp")

mkcp_uplinkCapacity = s:option(Value, "mkcp_uplinkCapacity", translate("KCP uplinkCapacity"))
mkcp_uplinkCapacity.default = "5"
mkcp_uplinkCapacity:depends("transport", "mkcp")

mkcp_downlinkCapacity = s:option(Value, "mkcp_downlinkCapacity", translate("KCP downlinkCapacity"))
mkcp_downlinkCapacity.default = "20"
mkcp_downlinkCapacity:depends("transport", "mkcp")

mkcp_congestion = s:option(Flag, "mkcp_congestion", translate("KCP Congestion"))
mkcp_congestion:depends("transport", "mkcp")

mkcp_readBufferSize = s:option(Value, "mkcp_readBufferSize", translate("KCP readBufferSize"))
mkcp_readBufferSize.default = "1"
mkcp_readBufferSize:depends("transport", "mkcp")

mkcp_writeBufferSize = s:option(Value, "mkcp_writeBufferSize", translate("KCP writeBufferSize"))
mkcp_writeBufferSize.default = "1"
mkcp_writeBufferSize:depends("transport", "mkcp")

mkcp_seed = s:option(Value, "mkcp_seed", translate("KCP Seed"))
mkcp_seed:depends("transport", "mkcp")

-- [[ DomainSocket部分 ]]--

ds_path = s:option(Value, "ds_path", "Path", translate("A legal file path. This file must not exist before running."))
ds_path:depends("transport", "ds")

-- [[ QUIC部分 ]]--
quic_security = s:option(ListValue, "quic_security", translate("Encrypt Method"))
quic_security:value("none")
quic_security:value("aes-128-gcm")
quic_security:value("chacha20-poly1305")
quic_security:depends("transport", "quic")

quic_key = s:option(Value, "quic_key", translate("Encrypt Method") .. translate("Key"))
quic_key:depends("transport", "quic")

quic_guise = s:option(ListValue, "quic_guise", translate("Camouflage Type"))
for a, t in ipairs(header_type_list) do quic_guise:value(t) end
quic_guise:depends("transport", "quic")

-- [[ VLESS Fallback部分 ]]--
--[[
fallback = s:option(Flag, "fallback", translate("Fallback"))
fallback:depends({ type = "Xray", protocol = "vless", transport = "tcp", tls = "1" })
fallback:depends({ type = "V2ray", protocol = "vless", transport = "tcp", tls = "1" })

fallback_alpn = s:option(Value, "fallback_alpn", "Fallback alpn")
fallback_alpn:depends("fallback", "1")

fallback_path = s:option(Value, "fallback_path", "Fallback path")
fallback_path:depends("fallback", "1")

fallback_dest = s:option(Value, "fallback_dest", "Fallback dest")
fallback_dest:depends("fallback", "1")

fallback_xver = s:option(Value, "fallback_xver", "Fallback xver")
fallback_xver.default = 0
fallback_xver:depends("fallback", "1")
]]--

ss_aead = s:option(Flag, "ss_aead", translate("Shadowsocks2"))
ss_aead:depends("type", "Trojan-Go")
ss_aead.default = "0"

ss_aead_method = s:option(ListValue, "ss_aead_method", translate("Encrypt Method"))
for _, v in ipairs(encrypt_methods_ss_aead) do ss_aead_method:value(v, v) end
ss_aead_method.default = "aead_aes_128_gcm"
ss_aead_method:depends("ss_aead", "1")

ss_aead_pwd = s:option(Value, "ss_aead_pwd", translate("Password"))
ss_aead_pwd.password = true
ss_aead_pwd:depends("ss_aead", "1")

tcp_fast_open = s:option(Flag, "tcp_fast_open", translate("TCP Fast Open"))
tcp_fast_open.default = "0"
tcp_fast_open:depends("type", "SS")
tcp_fast_open:depends("type", "SSR")
tcp_fast_open:depends("type", "Trojan")
tcp_fast_open:depends("type", "Trojan-Plus")
tcp_fast_open:depends("type", "Trojan-Go")

remote_enable = s:option(Flag, "remote_enable", translate("Enable Remote"), translate("You can forward to Nginx/Caddy/Xray/V2ray WebSocket and more."))
remote_enable.default = "1"
remote_enable.rmempty = false
remote_enable:depends("type", "Trojan")
remote_enable:depends("type", "Trojan-Plus")
remote_enable:depends("type", "Trojan-Go")

remote_address = s:option(Value, "remote_address", translate("Remote Address"))
remote_address.default = "127.0.0.1"
remote_address:depends("remote_enable", 1)

remote_port = s:option(Value, "remote_port", translate("Remote Port"))
remote_port.datatype = "port"
remote_port.default = "80"
remote_port:depends("remote_enable", 1)

bind_local = s:option(Flag, "bind_local", translate("Bind Local"), translate("When selected, it can only be accessed locally,It is recommended to turn on when using reverse proxies."))
bind_local.default = "0"
bind_local:depends("type", "Xray")
bind_local:depends("type", "V2ray")

accept_lan = s:option(Flag, "accept_lan", translate("Accept LAN Access"), translate("When selected, it can accessed lan , this will not be safe!"))
accept_lan.default = "0"
accept_lan.rmempty = false
accept_lan:depends("type", "Xray")
accept_lan:depends("type", "V2ray")

local nodes_table = {}
for k, e in ipairs(api.get_valid_nodes()) do
    if e.node_type == "normal" and e.type == "Xray" or e.type == "V2ray" then
        nodes_table[#nodes_table + 1] = {
            id = e[".name"],
            remarks = e.remarks_name
        }
    end
end

transit_node = s:option(ListValue, "transit_node", translate("transit node"))
transit_node:value("nil", translate("Close"))
for k, v in pairs(nodes_table) do transit_node:value(v.id, v.remarks) end
transit_node.default = "nil"
transit_node:depends("type", "Xray")
transit_node:depends("type", "V2ray")

return m
