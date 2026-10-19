Description for DNS2SOCKS
-------------------------

DNS2SOCKS is a command line utility running to forward DNS requests to a
DNS server via a SOCKS or HTTP tunnel.

I know that this is no new idea, but let me explain why I've coded this:
Windows supports using a SOCKS server for Internet connections, but it
only uses the SOCKS server for the content and not the DNS requests. I
found several articles in the Internet referring this issue. There seem
to be tools that do exactly the same thing as DNS2SOCKS, but they either
need a scripting interpreter or are not available for downloading anymore.

So I've coded an own tool. It's very(!) simple and doesn't use any
sophisticated technology.

To use it, just configure your OS to use the DNS server on the local
IP address 127.0.0.1 (IPv4) and/or ::1 (IPv6). On Windows: open the
properties of your network adapter. For IPv4 open the properties of
"Internet Protocol Version 4 (TCP/IPv4)", select "Use the following DNS
server addresses" and enter "127.0.0.1" for the "Preferred DNS server".
For IPv6 open the properties of "Internet Protocol Version 6
(TCP/IPv6)", select "Use the following DNS server addresses" and enter
"::1" for the "Preferred DNS server".

After that run your SOCKS server (must support SOCKS protocol version 5,
for example Tor) or HTTP proxy and start DNS2SOCKS using the correct
command line switches (see below). Now all DNS requests of your OS
(triggered by any application) run through DNS2SOCKS and your SOCKS
server or HTTP proxy.

You can additionally configure Windows to use your SOCKS server for
Internet connections (for the content, not DNS). To do this open the
"Internet Options" of the control panel, select the tab "Connections" and
click on "LAN settings". Check "Use a proxy server for your LAN..." and
click on "Advanced". Enter your SOCKS server address and port in the field
"Socks". Now Internet Explorer and other tools using these settings get
web pages via your SOCKS server. This works with most browsers. However,
you should rely on IPv4 for Tor here as (most?) Tor exit servers currently
don't support IPv6 (see below).
The settings are similar for using a HTTP proxy.

The command line call for DNS2SOCKS has the following format:

DNS2SOCKS [/?] [/t] [/d] [/q] [l[a]:FilePath] [/u:User /p:Password]
          [/e[f]:IP/Bits]
          [Socks5ServIP[:Port]] [DNSServIPorName[:Port]] [ListenIP[:Port]]

/?            or any invalid parameter outputs the usage text
/t            to use a HTTP proxy instead of a SOCKS server
              (here: Socks5ServIP = HttpProxyIP, no support for /u and /p)
/d            disables the cache
/q            disables the text output to the console
/l:FilePath   creates a new log file "FilePath"
/la:FilePath  creates a new log file "FilePath" or appends to the file if
              it already exists
/u:User       user name if your SOCKS server uses user/password
              authentication
/p:Password   password if your SOCKS server uses user/password
              authentication
/e:IP/Bits    to enable and specify EDNS client subnet in DNS queries
/ef:IP/Bits   same as above but also replaces EDNS client subnet if it
              exists

The default values for the addresses and ports are (in case you don't
specify the command line arguments):
Default Socks5ServerIP:Port = 127.0.0.1:9050
Default DNSServerIPorName:Port = 46.182.19.48
Default ListenIP:Port = 127.0.0.1:53

So the SOCKS server runs locally on the TCP port 9050 (Tor's default port;
attention: for Tor Browser Bundle you must change it to 9150). The used
DNS server is 46.182.19.48 (Digitalcourage e.V.). The DNS server must
support TCP on port 53 as Tor doesn't support UDP via SOCKS. DNS2SOCKS
listens on the UDP port 53 of 127.0.0.1 (only locally) - change this to
0.0.0.0 for listening on all available local IPv4 addresses.

You can launch DNS2SOCKS several times with different settings, for
example to listen on IPv6 addresses additionally. To specify an IPv6
address, use the typical format like 1234:5678::1234. To add the port
number please embed the IP address in square brackets and add the port
number separated by the colon, e.g. [::1]:1024

Hint: In the default configuration Tor only listens on 127.0.0.1 for
incoming requests. You can change this in Tor's configuration file using
the following line
SocksListenAddress 192.168.1.1
In this example it listens on 192.168.1.1
Currently Tor doesn't support IPv6 addresses for listening.

Please note that Tor/Vidalia will output warnings that your application
doesn't resolve host names via Tor. This is not true, but Tor can't know
this as Tor doesn't recognize the tunneled DNS requests. DNS2SOCKS
directly uses the IP address of the DNS server while using SOCKS and also
your application will do this as it gets the IP address from DNS2SOCKS.
Tor expects getting the host names instead of IP addresses and thus
outputs these warnings.

However, instead of an IP address you can also specify the DNS server's
name instead of its IP address, e.g.
DNS2SOCKS 127.0.0.1 dns2.digitalcourage.de ::1
Specifying an IPv6 address for the DNS server is also supported by
DNS2SOCKS, but it's not recommended to do this as your current Tor exit
server would need to support IPv6, which it typically doesn't. So it's
better to specify the DNS server name as the exit server can choose IPv4
or IPv6 automatically this way. Directly specifying an IPv4 address might
be a bit faster; currently all Tor exit servers should support this.

Use the /e parameter to specify/overwrite the EDNS client subnet in your
DNS queries. This is a hint for the DNS server to reply with IP addresses
close to the specified subnet. It can speed things up. However, please
be aware of the privacy risk. There are three possible variants DNS2SOCKS
handles concerning the DNS requests if /e... is enabled:
1. There is no OPT pseudo-RR -> DNS2SOCKS adds one with the EDNS client
   subnet option. It sets the DNSSEC flag to 0 as the original request
   didn't have it.
2. There is an OPT pseudo-RR but no EDNS client subnet in it -> DNS2SOCKS
   only adds the EDNS client subnet option but doesn't change the rest.
3. There is an OPT pseudo-RR including the EDNS client subnet. Now it
   depends what you specify:
   /e:... leaves it untouched.
   /ef:... overwrites the original EDNS client subnet (f=force).

As DNS requests running through the SOCKS/HTTP tunnel are very slow, the
calling application might time out before it gets the answer - in this
case just try it again (press "reload" in the browser).

The output of DNS2SOCKS is very simple. On each new request it outputs
the requested name prefixed by the current number of entries in the
cache (just an increasing number in case the cache is disabled) and a time
stamp. DNS2SOCKS caches DNS requests, so the next time it can serve the
answer faster. The cache is a very simple list. There is no sophisticated
hash algorithm or something like that for the cache and DNS2SOCKS doesn't
really interpret the DNS requests and answers - it just forwards them.

DNS2SOCKS runs as long as you don't manually stop it.
You can also run several instances of DNS2SOCKS at the same time when
using different local ports or IPv4 and IPv6 at the same time, e.g. use a
batch file and Window's Start command to do this.

If you think that DNS2SOCKS is not the right tool for you, but you want
to route all network traffic of a specific Windows application through a
SOCKS tunnel, you might want to try my tool InjectSOCKS.



Now about some technical details:
DNS2SOCKS listens on the local UDP and TCP port you specify. In case it
gets a request it first searches the cache for an identical request.
In case of a cache miss or expiration of the entry, the tool creates a new
thread for resolving the request. The new thread opens a TCP connection to
the SOCKS server and forwards the DNS request. This time the DNS request
always runs on TCP as Tor currently doesn't support UDP via SOCKS. So the
DNS server must support TCP. When the thread finally gets the answer, it
forwards it via UDP or TCP to the requesting client and stores it in the
cache. DNS2SOCKS supports user/password authentication (method 0x02) for
SOCKS.

I've tried to comment the source code as good as possible and you can
compile it using Visual C++ 2015 Express Edition (or any other edition).
I've also tested it on Knoppix and Damn Small Linux and compiled it via
gcc -pthread -Wall -O2 -o DNS2SOCKS DNS2SOCKS.c
It should also run on other *nix variants; maybe with tiny modifications.

Have fun using this software!

ghostmaker



License (3-clause BSD License)
------------------------------

Copyright (c) 2012, ghostmaker
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
   * Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
   * Neither the name of ghostmaker nor the names of its contributors may
     be used to endorse or promote products derived from this software
     without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL ghostmaker BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.



Changes of version 2.1 (released on 2020-02-18)
-----------------------------------------------

- Added command line parameter /e... to set/overwrite the EDNS client
  subnet in DNS requests
- Changed default DNS server to 46.182.19.48
- Usage of the MSG_NOSIGNAL flag
- No modification of pseudo TTL field of OPT pseudo-RR anymore when
  updating TTL in answer from cache
- Updated to Visual C++ 2015 Express Edition for compiling
- SHA256 for DNS2SOCKS.exe:
  f4bb9471f73648a9f4f30cf7e9200eef3280499fb5c9e64a0234c9a4398c9edf


Changes of version 2.0 (released on 2015-06-28)
-----------------------------------------------

- Added command line parameter /t to use a HTTP proxy instead of a SOCKS5
  server (HTTP CONNECT tunneling)
- SHA256 for DNS2SOCKS.exe:
  ba841370b0d79b776438eb22a9131e91250025b55db4200db8f66a060cf6047d


Changes of version 1.9 (released on 2015-06-18)
-----------------------------------------------

- Added fallback to old IPv4 parsing via "inet_addr" in case "getaddrinfo"
  fails (workaround for erroneous "getaddrinfo" implementation)
- SHA256 for DNS2SOCKS.exe:
  5612bf263136852c39d929691b63a103c166f78bbd606d7947ce1d813c28c560


Changes of version 1.8 (released on 2015-01-01)
-----------------------------------------------

- Support for IPv6
- Support for DNS server name instead of IP address
- Added BSD license text to ReadMe.txt
- Minor tweaks
- SHA256 for DNS2SOCKS.exe:
  d654659b031ede16224fa37f585c735112a689f46497afc3fca6ccd4cde70b93


Changes of version 1.7 (released on 2013-11-14)
-----------------------------------------------

- Support for SOCKS5 user/password authentication (method 0x02)
- SHA256 for DNS2SOCKS.exe:
  63c0fd8f9dcd3f3546691892999d868ce74601778111dcf08cdfeb140818d28e


Changes of version 1.6 (released on 2013-10-21)
-----------------------------------------------

- Cache function respects the "time to live" field of DNS answers
- Command line parameter /d to disable the cache
- SHA256 for DNS2SOCKS.exe:
  45a20efacb8fed901299712ae2ee6147ac453d69c349b0766024cb5d3634a0b5


Changes of version 1.5 (released on 2013-10-06)
-----------------------------------------------

- Removed several compiler warnings that appeared when compiling for
  some platforms (tested on Knoppix V7.2.0 64 bit)
- Additional output of system error text in case of system call failure
- Added Windows application manifest "supportedOS" entry for Windows 8.1
- Bugfix: Output of settings at startup was missing
- SHA256 for DNS2SOCKS.exe:
  8e987da2a57e5be942c21c76e28e185279a527ed67a468dab5757d38dc1e37ea


Changes of version 1.4 (released on 2013-01-19)
-----------------------------------------------

- Command line parameter /l:filePath or /la:filePath to create a log file
  for the output (/la for appending)
- Output has a time stamp for each line
- SHA256 for DNS2SOCKS.exe:
  cae8aab900897b2c03bd8f3d415de91df596479bca2f83b107455ba68de28793


Changes of version 1.3 (released on 2012-11-03)
-----------------------------------------------

- DNS requests/responses via TCP additionally to UDP (still always via
  TCP for transportation via SOCKS)
- UDP requests/responses can now have the maximum possible size for UDP
- You can specify the local port number to use for UDP and TCP
- You can specify the remote port number to use for contacting the DNS
  server
- You can compile the sources on Unix/Linux now and use it like on
  Windows. You only need DNS2SOCKS.c and stdafx.h for that and compile
  it with a command like
  gcc -pthread -Wall -O2 -o DNS2SOCKS DNS2SOCKS.c
  (tested on Damn Small Linux; use sudo to run it as otherwise it's
  impossible to bind port 53; please be aware that the connect time-
  out on Linux is typically several minutes while it is just some
  seconds on Windows, so in case connecting to the SOCKS server doesn't
  work, it takes very long until you see an error message)
- On Windows DNS2SOCKS is no console application anymore, but it creates
  its own new console window at start-up; this way you can start it with
  the new /q option to suppress any output and it has no window in this
  case - use the Task Manager to terminate it
- SHA1 for DNS2SOCKS.exe: 596015cba187a9184c5b480b8666c0d4b37d9552


Changes of version 1.2 (released on 2012-01-13)
-----------------------------------------------

You can configure the listen address via the command line now. The default
is 127.0.0.1 instead of 0.0.0.0 of version 1.1. This way the Windows
firewall doesn't show up.