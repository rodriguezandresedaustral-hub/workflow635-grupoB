#!/bin/bash
# Startup script de la VM (corre como root en cada arranque).
# Lo instala vm/lanzar.sh en el template; no se usa a mano.
#
# 1. hace lo mismo que el startup de los templates de la catedra (gcloud config)
# 2. espera a ver el bucket montado (lo monta la imagen labo-family)
# 3. corre el workflow si no termino; retoma solo desde los checkpoints
# 4. al salir R, por lo que sea, espera 30 min y baja el grupo a 0, asi no se
#    recrea. Solo una expropiacion (que no pasa por aca) hace que se recree.
#
# El bucket lo monta gcsfuse para el usuario ds, sin allow_other: root NO lo
# puede leer. Todo acceso al bucket va como ds.

META=http://metadata.google.internal/computeMetadata/v1/instance
meta() { curl -sf -H "Metadata-Flavor: Google" "$META/$1"; }
ds() { sudo -u ds -H "$@"; }

PROYECTO=$(meta attributes/proyecto)
MIG=$(meta attributes/mig)
ZONA=$(meta zone | awk -F/ '{print $NF}')
ds gcloud config set project "$PROYECTO"

B=$(meta attributes/bucket-dir)
DIR="$B/$(meta attributes/wf-dir)"

for i in $(seq 120); do ds test -f "$DIR/.env" && break; sleep 5; done
if ! ds test -f "$DIR/.env"; then
  # sin .env no hay mail: queda en el serial port. Se baja el grupo para no
  # dejar la VM prendida cobrando
  echo "startup: no veo $DIR/.env despues de 10 min: el bucket no esta montado. Bajo el grupo a 0"
  gcloud compute instance-groups managed resize "$MIG" --zone "$ZONA" --project "$PROYECTO" --size 0
  exit 1
fi

set -a; . <(ds cat "$DIR/.env" | tr -d '\r'); set +a

# SEMILLAS_PIPELINE (en el .env, separadas por coma): una corrida completa por
# semilla, en orden, cada una en exp/WF<EXPERIMENTO>_s<semilla>. Vacio = una
# sola corrida en exp/WF<EXPERIMENTO> con la semilla del script.
SEMILLAS=$(echo "${SEMILLAS_PIPELINE:-}" | tr ',' ' ')
[ -z "$SEMILLAS" ] && SEMILLAS="-"

nombre() { if [ "$1" = "-" ]; then echo "WF$EXPERIMENTO"; else echo "WF${EXPERIMENTO}_s$1"; fi; }

mail() {   # mail <corrida> <titulo> <cuerpo>: al hilo "experimento" de esa corrida
  ds test -f "$MAIL_PASS_FILE" && ds test -f "$MAIL_TO_FILE" || return 0
  local para rcpt="" m
  para=$(ds cat "$MAIL_TO_FILE" | grep -v '^#' | sed '/^[[:space:]]*$/d')
  for d in $para; do rcpt="$rcpt --mail-rcpt $d"; done
  m=$(mktemp)
  local raiz="<$(echo $1 | tr A-Z a-z)-$(echo $GRUPO | tr A-Z a-z)-experimento@workflow635>"
  printf "From: %s\nTo: %s\nSubject: Re: [%s grupo %s] experimento\nIn-Reply-To: %s\nReferences: %s\n\n%s\n\n%s\n" \
    "$MAIL_FROM" "$(echo $para | sed 's/ /, /g')" "$1" "$GRUPO" "$raiz" "$raiz" "$2" "$3" > "$m"
  curl -s --max-time 30 --ssl-reqd --url smtps://smtp.gmail.com:465 \
    --mail-from "$MAIL_FROM" $rcpt \
    --user "$MAIL_FROM:$(ds head -1 "$MAIL_PASS_FILE" | tr -d '[:space:]')" -T "$m"
  rm -f "$m"
}

for SEM in $SEMILLAS; do
  CORRIDA=$(nombre "$SEM")
  FIN="$B/exp/$CORRIDA/TERMINADO"
  ds test -f "$FIN" && continue
  echo "$CORRIDA" > /home/ds/wf635_corrida_actual    # para el mail del shutdown
  ARG=""; [ "$SEM" != "-" ] && ARG="$SEM"

  # gcsfuse sube un archivo recien al cerrarlo: R escribe el log en el disco
  # local y una copia va al bucket cada minuto (log_<corrida>.txt)
  ds bash -lc "
    export PATH=\$HOME/.local/bin:\$PATH
    LOCAL=\$HOME/log_$CORRIDA.txt
    cd '$DIR' || exit 2
    [ -f log_$CORRIDA.txt ] && [ ! -f \$LOCAL ] && cp log_$CORRIDA.txt \$LOCAL
    ( while sleep 60; do cp \$LOCAL log_$CORRIDA.txt; done ) &
    COPIA=\$!
    Rscript 635_workflow_senior.R .env $ARG >> \$LOCAL 2>&1
    RC=\$?
    kill \$COPIA
    cp \$LOCAL log_$CORRIDA.txt
    exit \$RC"
  RC=$?
  if ! ds test -f "$FIN"; then
    # rc 1 = error que R ya aviso por mail. Otro rc = R murio sin poder avisar
    # (por ejemplo, sin memoria). En los dos casos se corta la serie: un error
    # en una semilla casi seguro se repite en la siguiente.
    [ "$RC" != "1" ] && mail "$CORRIDA" "R termino sin terminar (codigo $RC)" \
      "Rscript salio con codigo $RC y sin TERMINADO. Probable falta de memoria. Ver $DIR/log_$CORRIDA.txt. Se corta la serie; la VM se apaga en 30 min."
    break
  fi
done

if [ "$(meta attributes/apagar-al-terminar)" = "1" ]; then
  sleep 1800
  gcloud compute instance-groups managed resize "$MIG" --zone "$ZONA" --project "$PROYECTO" --size 0
fi
