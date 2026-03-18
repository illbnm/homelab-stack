# Test Results — Base Infrastructure Stack

Tested: 2026-03-17
Server: DigitalOcean Droplet (Ubuntu, Docker 29.3.0, Compose v5.1.0)

---

## docker compose ps

```
NAME           IMAGE                                 STATUS                    PORTS
portainer      portainer/portainer-ce:2.21.3         Up 38 seconds (healthy)   8000/tcp, 9000/tcp, 9443/tcp
socket-proxy   tecnativa/docker-socket-proxy:0.2.0   Up 38 seconds (healthy)   2375/tcp
traefik        traefik:v3.1.6                        Up 32 seconds (healthy)   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
watchtower     containrrr/watchtower:1.7.1           Up 38 seconds (healthy)   8080/tcp
```

All 4 containers: **healthy**

## Health Checks

```
/socket-proxy: healthy
/traefik: healthy
/portainer: healthy
/watchtower: healthy
```

## HTTP → HTTPS Redirect

```
HTTP/1.1 308 Permanent Redirect
Location: https://127.0.0.1/
```

Port 80 correctly redirects to HTTPS with 308 Permanent Redirect.

## Socket Proxy Isolation

```
$ curl -s --connect-timeout 2 http://127.0.0.1:2375/_ping
Not reachable from host (correct — internal network only)
```

Docker socket proxy is NOT exposed to the host. Only accessible from the internal `socket-proxy` network (Traefik only).

## Traefik ↔ Socket Proxy Communication

```
$ docker exec traefik wget -qO- http://socket-proxy:2375/v1.44/containers/json
[{"Id":"b3859c3c38fb...","Names":["/traefik"],"Image":"traefik:v3.1.6"...}]
```

Traefik successfully queries the Docker API via socket proxy.

## Watchtower Schedule

```
level=info msg="Scheduling first run: 2026-03-18 03:00:00 +0000 UTC"
level=info msg="Only checking containers using enable label"
```

Watchtower scheduled for 03:00 AM, label-scoped updates only.

## Port Bindings

```
80/tcp  -> 0.0.0.0:80
443/tcp -> 0.0.0.0:443
```

Traefik correctly binds to host ports 80 and 443.
