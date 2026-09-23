#!/usr/bin/env bash
# Serve os pacotes de idioma para um device de desenvolvimento.
#
# Escuta em todas as interfaces e anuncia o IP da LAN, porque o caminho por
# "localhost" depende de `adb reverse`, e o `flutter run` limpa os mapeamentos
# de porta a cada execucao -- o tunel morria toda vez que voce rodava o app, e
# o erro no aparelho ("Connection refused") nao dizia isso. O reverse continua
# sendo criado como alternativa para quando o aparelho nao estiver na mesma
# rede, mas o IP da LAN e o caminho estavel.
#
# Isto e so para desenvolvimento: expoe a pasta build/ na sua rede local, e
# em producao os pacotes saem de um CDN por HTTPS.
#
# NAO canalize a saida por `head` ou similar. Quando o leitor do pipe sai, o
# proximo log do http.server leva SIGPIPE, a thread que atende a requisicao
# morre e o cliente ve "Connection closed before full header was received" --
# com o servidor ainda escutando. Redirecione para um arquivo.
set -euo pipefail
PORT="${PORT:-8000}"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo '')"
if [ -n "$LAN_IP" ]; then
  echo "modelBaseUrl para o app: http://$LAN_IP:$PORT"
else
  echo "sem IP de LAN; use o caminho por adb reverse"
fi

if "$ADB" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null 2>&1; then
  echo "alternativa por cabo: http://localhost:$PORT (cai a cada flutter run)"
fi

cd "$(dirname "$0")/../build"
echo "servindo $(pwd) na porta $PORT"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
