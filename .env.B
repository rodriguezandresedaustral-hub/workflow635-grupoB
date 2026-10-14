# Corrida lista para el grupo B: la misma prueba que lanzamos en el grupo A
# (WF9532), adaptada al B. Lo lee vm/lanzar.sh B y lo sube al bucket.
# Formato KEY=valor, sin espacios ni comillas.

# B: valida 202105, predice 202107, calcula la ganancia en 202107 (sin Kaggle)
GRUPO=B

# carpeta de salida: <BUCKET_DIR>/exp/WF<EXPERIMENTO>. Uno distinto por corrida
# (si se repite, retoma la anterior)
EXPERIMENTO=9632
# vacio = una sola corrida con la semilla 100213
SEMILLAS_PIPELINE=

# --- lo que se prueba ---------------------------------------------------------
# transferencia = no corre el workflow entero: la genetica busca en 202011 y en
# 202101, y las 20 mejores formulas de cada busqueda, junto con 20 al azar, se
# vuelven a medir en 202101, 202103 y 202105 con 3 semillas de LightGBM.
# Responde si lo que elige la genetica en un mes sigue sirviendo despues.
# Para correr el workflow completo con esta genetica: GA_MODO=genetica
GA_MODO=transferencia
# la genetica despues del FE historico: el modelo base ve los lags
GA_CON_HISTORIA=1
# y las formulas combinan tambien lags, deltas y tendencias (lo que sugirio Denicolay)
GA_COMBINAR_HISTORIA=1
GA_POBLACION=30
GA_GENERACIONES=20
# vacio = default del grupo B (busca en 202011 y 202101; mide en 202101, 202103 y 202105)
TRF_BUSQUEDAS=
TRF_MEDIR=
TRF_TOP=20

# techo de la BO en log2 (solo importa con el workflow completo)
BO_TECHO_LOG2_ITERACIONES=12
BO_TECHO_LOG2_HOJAS=12

# rutas ADENTRO de la VM (asi las monta la imagen de la catedra)
BUCKET_DIR=/home/ds/buckets/b1
DATASET_PATH=/home/ds/buckets/b1/datasets/analistasr_competencia_2026.csv.gz

# --- mail -----------------------------------------------------------------
# Asi como esta, NO manda mails (el script anota "SIN MAIL" y sigue).
# Para recibirlos, ver "2. El mail" en el README y poner:
#   MAIL_FROM=tu_cuenta@gmail.com
#   MAIL_PASS_FILE=/home/ds/buckets/b1/secrets/gmail_app_password
#   MAIL_TO_FILE=/home/ds/buckets/b1/wf635/destinatarios.txt
MAIL_FROM=sin-mail
MAIL_PASS_FILE=/dev/null
MAIL_TO_FILE=/dev/null
MAIL_CADA_ITER=5

# el grupo B no sube a Kaggle
KAGGLE_SUBIR=0
