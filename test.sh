#!/usr/bin/env bash
# Smoke test for the phppgadmin container.
# Builds the image, starts a postgres:16 sidecar on a shared network, points
# phppgadmin at it and asserts:
#   1. the phpPgAdmin app page renders over HTTP
#   2. a DB-backed page works: login into the postgres sidecar and list its
#      databases (exercises the ADODB + version-detection PHP 8.4 fixes)
#   3. there is NO "PHP Fatal error" in the apache/php error log
# The apache2 base ships neither wget nor curl, so HTTP is done with a small
# bash /dev/tcp helper run *inside* the container (nothing is bind-mounted).
set -e

IMG=phppgadmin-test
NET=phppgadmin-test-net
CN=phppgadmin-test-run
DB=phppgadmin-test-db

cleanup() {
  docker rm -f "$CN" "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "FAIL: $1"; exit 1; }

echo ">> building image"
docker build -t "$IMG" .

echo ">> (re)creating network"
docker network rm "$NET" >/dev/null 2>&1 || true
docker network create "$NET" >/dev/null

echo ">> starting postgres:16 sidecar"
docker rm -f "$DB" >/dev/null 2>&1 || true
docker run -d --name "$DB" --network "$NET" \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=testdb \
  postgres:16 >/dev/null

echo ">> waiting for postgres to accept connections (up to 60s)"
pgup=0
for _ in $(seq 1 30); do
  if docker exec "$DB" pg_isready -U postgres >/dev/null 2>&1; then pgup=1; break; fi
  sleep 2
done
[ "$pgup" = 1 ] || fail "postgres sidecar did not become ready in time"
echo "ok - postgres ready"

echo ">> starting phppgadmin container (pointed at sidecar)"
docker rm -f "$CN" >/dev/null 2>&1 || true
docker run -d --name "$CN" --network "$NET" \
  -e DISABLE_TLS=disable -e DB_HOST="$DB" "$IMG" >/dev/null

echo ">> waiting for apache to listen on 80 (up to 120s)"
up=0
for _ in $(seq 1 60); do
  if docker exec "$CN" bash -c 'exec 3<>/dev/tcp/127.0.0.1/80' 2>/dev/null; then up=1; break; fi
  sleep 2
done
[ "$up" = 1 ] || fail "apache did not start listening on 80 in time"
echo "ok - apache listening"

echo ">> assert: container is running"
[ "$(docker inspect -f '{{.State.Running}}' "$CN")" = true ] || fail "container not running"
echo "ok - container running"

# ---- test 1: the app page renders --------------------------------------------
echo ">> assert: GET /phppgadmin/ renders the phpPgAdmin app"
home=$(docker exec "$CN" bash -c '
  exec 3<>/dev/tcp/127.0.0.1/80
  printf "GET /phppgadmin/ HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3
  cat <&3')
echo "$home" | grep -q '^HTTP/1.1 200' || fail "app page did not return HTTP 200"
echo "$home" | grep -q 'phpPgAdmin' || fail "app page HTML does not contain 'phpPgAdmin'"
echo "ok - app page renders"

# ---- test 2: DB-backed login lists the sidecar's databases -------------------
echo ">> assert: DB-backed login lists the sidecar's databases"
# server id is "<host>:<port>:<sslmode>"; sslmode defaults to 'allow'.
login=$(docker exec "$CN" bash -c "
  SRV='${DB}:5432:allow'
  MD5=\$(php -r \"echo md5('\$SRV');\")
  ESRV=\$(php -r \"echo rawurlencode('\$SRV');\")
  BODY=\"subject=server&server=\${ESRV}&loginServer=\${ESRV}&loginUsername=postgres&loginPassword_\${MD5}=secret\"
  LEN=\${#BODY}
  exec 3<>/dev/tcp/127.0.0.1/80
  printf 'POST /phppgadmin/redirect.php HTTP/1.0\r\nHost: localhost\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: %d\r\n\r\n%s' \"\$LEN\" \"\$BODY\" >&3
  cat <&3")
echo "$login" | grep -qi 'invalid server parameter' && fail "login rejected (invalid server parameter)"
echo "$login" | grep -qi 'login failed\|could not connect' && fail "login could not connect to postgres sidecar"
echo "$login" | grep -q 'testdb' || fail "DB-backed page did not list the 'testdb' database"
echo "ok - DB-backed page lists databases (postgres 16 reached, no fatal)"

# ---- test 3: no PHP fatal error anywhere in the log --------------------------
echo ">> assert: no PHP Fatal error in the apache/php error log"
if docker exec "$CN" grep -i 'PHP Fatal error' /var/log/apache2/error.log; then
  fail "PHP Fatal error found in error log (PHP 8.4 compatibility broken)"
fi
echo "ok - no PHP fatal errors"

echo ""
echo "ALL TESTS PASSED"
