#!/bin/bash
# Shutdown script: si la VM fue expropiada (Spot), avisa por mail.
# GCP da ~30 segundos antes de apagarla; alcanza para un curl.
# El bucket solo lo puede leer el usuario ds (gcsfuse sin allow_other).

META=http://metadata.google.internal/computeMetadata/v1/instance
meta() { curl -sf -H "Metadata-Flavor: Google" "$META/$1"; }
ds() { sudo -u ds -H "$@"; }

[ "$(meta preempted)" = "TRUE" ] || exit 0

DIR="$(meta attributes/bucket-dir)/$(meta attributes/wf-dir)"
ds test -f "$DIR/.env" || exit 0
set -a; . <(ds cat "$DIR/.env" | tr -d '\r'); set +a
ds test -f "$MAIL_PASS_FILE" && ds test -f "$MAIL_TO_FILE" || exit 0

PARA=$(ds cat "$MAIL_TO_FILE" | grep -v '^#' | sed '/^[[:space:]]*$/d')
RCPT=""
for d in $PARA; do RCPT="$RCPT --mail-rcpt $d"; done

M=$(mktemp)
# va al hilo "experimento" de Gmail, el mismo que usa el script de R
CORRIDA=$(cat /home/ds/wf635_corrida_actual 2>/dev/null || echo "WF$EXPERIMENTO")
RAIZ="<$(echo $CORRIDA | tr A-Z a-z)-$(echo $GRUPO | tr A-Z a-z)-experimento@workflow635>"
printf "From: %s\nTo: %s\nSubject: Re: [%s grupo %s] experimento\nIn-Reply-To: %s\nReferences: %s\n\nVM expropiada\n\nGCP expropio la VM %s. El grupo la vuelve a arrancar solo y retoma desde los checkpoints del bucket.\n" \
  "$MAIL_FROM" "$(echo $PARA | sed 's/ /, /g')" "$CORRIDA" "$GRUPO" "$RAIZ" "$RAIZ" "$(meta name)" > "$M"

curl -s --max-time 20 --ssl-reqd --url smtps://smtp.gmail.com:465 \
  --mail-from "$MAIL_FROM" $RCPT \
  --user "$MAIL_FROM:$(ds head -1 "$MAIL_PASS_FILE" | tr -d '[:space:]')" -T "$M"
rm -f "$M"
