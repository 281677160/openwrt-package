local ucursor = require "luci.model.uci".cursor()
local json = require "luci.jsonc"
local server_section = arg[1]
local proto = arg[2]
local local_port = arg[3] or "0"
local socks_port = arg[4] or "0"
local server = ucursor:get_all("shadowsocksr", server_section)
local Xray = {
log = {
-- error = "/var/ssrplus.log",
loglevel = "warning"
},
-- 传入连接
inbound = (local_port ~= "0") and {
	port = local_port,
	protocol = "dokodemo-door",
	settings = {
		network = proto,
		followRedirect = true
	},
	sniffing = {
		enabled = true,
		destOverride = { "http", "tls" }
	}
} or nil,
-- 开启 socks 代理
inboundDetour = (proto == "tcp" and socks_port ~= "0") and {
	{
	protocol = "socks",
	port = socks_port,
		settings = {
			auth = "noauth",
			udp = true
		}
	}
} or nil,
-- 传出连接
outbound = {
	protocol = server.type,
	settings = {
		vnext = {
			{
				address = server.server,
				port = tonumber(server.server_port),
				users = {
					{
						id = server.vmess_id,
						alterId = (server.type == "vmess") and tonumber(server.alter_id) or nil,
						security = (server.type == "vmess") and server.security or nil,
						encryption = (server.type == "vless") and server.vless_encryption or nil,
						flow = (server.xtls == '1') and (server.vless_flow and server.vless_flow or "xtls-rprx-splice") or nil,
					}
				}
			}
		}
	},
-- 底层传输配置
	streamSettings = {
		network = server.transport,
		security = (server.tls == '1') and ((server.xtls == '1') and "xtls" or "tls") or "none",
		tlsSettings = (server.tls == '1' and server.xtls ~= '1' and (server.insecure == "1" or server.tls_host)) and {
			allowInsecure = (server.insecure == "1") and true or nil,
			serverName=server.tls_host
		} or nil,
		xtlsSettings = (server.xtls == '1' and (server.insecure == "1" or server.tls_host)) and {
			allowInsecure = (server.insecure == "1") and true or nil,
			serverName=server.tls_host
		} or nil,
		tcpSettings = (server.transport == "tcp" and server.tcp_guise == "http") and {
			header = {
				type = server.tcp_guise,
				request = {
					path = {server.http_path} or {"/"},
					headers = {
						Host = {server.http_host} or {}
					}
				}
			}
		} or nil,
		kcpSettings = (server.transport == "kcp") and {
			mtu = tonumber(server.mtu),
			tti = tonumber(server.tti),
			uplinkCapacity = tonumber(server.uplink_capacity),
			downlinkCapacity = tonumber(server.downlink_capacity),
			congestion = (server.congestion == "1") and true or false,
			readBufferSize = tonumber(server.read_buffer_size),
			writeBufferSize = tonumber(server.write_buffer_size),
			header = {
				type = server.kcp_guise
			},
			seed = server.seed or nil
		} or nil,
		wsSettings = (server.transport == "ws") and (server.ws_path ~= nil or server.ws_host ~= nil) and {
			path = server.ws_path,
			headers = (server.ws_host ~= nil) and {
				Host = server.ws_host
			} or nil,
		} or nil,
		httpSettings = (server.transport == "h2") and {
			path = server.h2_path or "",
			host = {server.h2_host} or nil
		} or nil,
		quicSettings = (server.transport == "quic") and {
			security = server.quic_security,
			key = server.quic_key,
			header = {
				type = server.quic_guise
			}
		} or nil
	},
	mux = (server.xtls ~= "1") and {
		enabled = (server.mux == "1") and true or false,
		concurrency = tonumber(server.concurrency)
	} or nil
} or nil
}
print(json.stringify(Xray,1))