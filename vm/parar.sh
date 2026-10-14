#!/bin/bash
# Para el workflow de un grupo: baja el grupo a 0 (borra la VM y no la recrea).
# Lo guardado en el bucket queda; vm/lanzar.sh retoma desde ahi.
#
#   vm/parar.sh A        (o B)
set -euo pipefail
cd "$(dirname "$0")/.."

G=$(echo "${1:?uso: vm/parar.sh A|B}" | tr '[:lower:]' '[:upper:]')
g=$(echo "$G" | tr '[:upper:]' '[:lower:]')
. vm/vm.env

gcloud compute instance-groups managed resize "$VM_PREFIJO-$g" \
  --project "$PROJECT" --zone "$ZONE" --size 0
