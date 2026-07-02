# frpwrt — frp client (frpc) for OpenWRT

Installs the [frp](https://github.com/fatedier/frp) client on an OpenWRT router,
stores its configuration in UCI (`/etc/config/frpc`) instead of a hand-written
TOML file, and manages the daemon through a standard `procd` init script.

## Install

Copy this directory to the router (e.g. `scp -r frpwrt root@router:/root/`) and run:

```sh
cd /root/frpwrt
FRP_VERSION=0.69.1 FRP_ARCH=arm64 sh install.sh
```

The installer downloads `frpc` to `/usr/bin/frpc`, installs the init script and
(on first install only) the default UCI config, then enables and starts it.

## Configure

Everything lives in `/etc/config/frpc`. Edit and reload:

```sh
uci set frpc.common.server_addr='frp.example.com'
uci set frpc.common.server_port='7000'
uci commit frpc

/etc/init.d/frpc restart
```

### Server section (`config frpc 'common'`)

| Option         | Meaning                            |
| -------------- | ---------------------------------- |
| `enabled`      | `0` disables the service entirely  |
| `server_addr`  | frps server address                |
| `server_port`  | frps server port                   |
| `auth_token`   | optional token auth (matches frps) |
| `log_level`    | `info` / `warn` / `debug`          |
| `log_max_days` | log retention in days              |

### Proxy sections (`config proxy '...'`)

One block per forwarded port. The shipped config reproduces your example:

```
config proxy 'rich_http'
	option enabled '1'
	option name 'rich-http'
	option type 'tcp'
	option local_ip '127.0.0.1'
	option local_port '80'
	option remote_port '9880'
```

Add another proxy:

```sh
uci add frpc proxy
uci set frpc.@proxy[-1].name='my-web'
uci set frpc.@proxy[-1].type='tcp'
uci set frpc.@proxy[-1].local_ip='127.0.0.1'
uci set frpc.@proxy[-1].local_port='8080'
uci set frpc.@proxy[-1].remote_port='9808'
uci commit frpc

/etc/init.d/frpc restart
```

## service control (init.d)

```sh
/etc/init.d/frpc start      # start
/etc/init.d/frpc stop       # stop
/etc/init.d/frpc restart    # restart
/etc/init.d/frpc reload     # regenerate config + restart
/etc/init.d/frpc enable     # start on boot
/etc/init.d/frpc disable    # don't start on boot
```

on every start the init script renders `/var/etc/frpc.toml` from the UCI config
and launches `frpc -c /var/etc/frpc.toml` under procd (auto-respawn on crash).
