# phppgadmin - (ghcr.io/servercontainers/phppgadmin) (+ optional tls) on debian, apache2 [x86 + arm]

_maintained by ServerContainers_

## What is it

This Dockerfile (available as ___ghcr.io/servercontainers/phppgadmin___) gives you a ready to use phppgadmin installation with optional tls.

Note: This container only supports `postgres` database servers.
There is no internal postgres-server available - so you need to setup a seconds container for that (take a look at `docker-compose.yml`)

Note: `extra_login_security` is `false` per default. Make sure you understand what that means in production environments etc.

View in Docker Registry [ghcr.io/servercontainers/phppgadmin](https://hub.docker.com/r/ghcr.io/servercontainers/phppgadmin)

View in GitHub [ServerContainers/docker-phppgadmin](https://github.com/ServerContainers/phppgadmin)

This Dockerfile is based on the [ghcr.io/servercontainers/apache2-ssl-secure](https://ghcr.io/servercontainers/apache2-ssl-secure/) `debian:bullseye` based image.

## Build & Versioning

You can specify `DOCKER_REGISTRY` environment variable (for example `my.registry.tld`)
and use the build script to build the main container and it's variants for _x86_64, arm64 and arm_

You'll find all images tagged like `d11.2-a1.18.0-6.1-p1.36.0` which means `d<debian version>-a<apache version (with some esacped chars)>-p<phppgadmin version (with some esacped chars)>`.
This way you can pin your installation/configuration to a certian version. or easily roll back if you experience any problems
(don't forget to open a issue in that case ;D).

To build a `latest` tag run `./build.sh release`

## Changelogs

* 2023-03-20
    * github action to build container
    * implemented ghcr.io as new registry
    * moved from `MarvAmBass` to `ServerContainers`
* 2021-08-28
    * inital commit
    * multiarch build

## How to use

This container needs to connect to a database, so take a look at the `docker-compose.yml`

## Environment variables and defaults

* __DB\_HOST__
 * host of postgres db
 * default: `db`

* __DB\_PORT__
 * port of postgres db
 * default: `5432`

* __DEFAULT\_DB__
 * set default db
 * default: `template1`

* __EXTRA\_LOGIN\_SECURITY__
 * since I want this container to be a usable in every situation it's `false` per default
 * if you want to use this container for a production/long-running environment, you might want to change this
 * default: `false`

### BASEIMAGE: Environment variables and defaults

* __DISABLE\_TLS__
 * default: not set - if set yo any value `https` and the `HSTS_HEADERS_*` will be disabled

* __HSTS\_HEADERS\_ENABLE__
 * default: not set - if set to any value the HTTP Strict Transport Security will be activated on SSL Channel

* __HSTS\_HEADERS\_ENABLE\_NO\_SUBDOMAINS__
 * default: not set - if set together with __HSTS\_HEADERS\_ENABLE__ and set to any value the HTTP Strict Transport Security will be deactivated on subdomains

