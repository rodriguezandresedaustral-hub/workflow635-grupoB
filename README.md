# workflow635

> **Grupo B:** ver [LEEME_GRUPO_B.md](LEEME_GRUPO_B.md), con el `.env.B` ya armado.

El Workflow 01 senior de la cátedra (`z635_WorkFlow_01_senior.ipynb`, sin
modificar) llevado a un script que corre desatendido en las VM Spot de la
cátedra, para los dos grupos del experimento colaborativo.

| | Grupo A | Grupo B |
|---|---|---|
| Validación de la BO | 202107 | 202105 |
| Final train | 201901 – 202107 | 201901 – 202105 |
| Predice | 202109 | 202107 |
| Testing | Kaggle (sube los cortes 8000 – 12000) | ganancia contra la clase real de 202107 |

## Qué cambia respecto del z635

Las funciones y celdas de la cátedra están copiadas **sin cambios** en
`635_workflow_senior.R`; cada bloque dice de qué celda viene. Lo agregado:

- **FE genético** (la consigna del FE intra-mes), después del FE intra-mes
  manual y antes del histórico:
  - `gramEvol` evoluciona fórmulas `v1 op v2` o `(v1 op v2) op v3` sobre los
    campos del mes, con `+ − × /`.
  - **Fitness:** cuánta ganancia agrega la fórmula a un LightGBM fijo, medida
    en un **mes de búsqueda** que ni la BO ni el testing usan (A: 202103,
    B: 202101), entrenando con todos los meses desde 201901 hasta 1 de gap
    (o solo los `GA_VENTANA` anteriores) y el 20% de los CONTINUA. Ver [La genética v2](#la-genética-v2).
  - Por ronda, la mejor fórmula pasa por un **control** en otro mes que la
    búsqueda no vio (A: 202105, B: 202103): se mide junto a 19 fórmulas al
    azar de la misma gramática y **queda solo si sale primera y mejora**
    (si no aporta nada, eso pasa con probabilidad 1/20). El umbral de 2
    desvíos del ruido entre semillas se sigue calculando, pero solo queda en
    el registro. Cada ganadora entra como `gen_01`, `gen_02`... y después
    recibe lags, deltas y tendencia como cualquier campo.
  - Cada fórmula evaluada queda en `genetica_log.txt` (si la VM se corta,
    retoma sin volver a entrenar lo medido), cada ronda en
    `genetica_rondas.txt` y el control de cada ronda en
    `genetica_control.txt`.
  - Mail en cada generación con las 10 mejores fórmulas, los segundos por
    fórmula y las horas usadas, y al terminar cada ronda.
  - **Tope de horas opcional** (`PARAM$GA$horas_max`, apagado por defecto):
    con un número, al llegar cierra la ronda con la mejor fórmula medida y
    sigue sola con el resto del workflow. El mail final dice, por variable ganadora, la fórmula, la mejora,
    si sobrevivió a canaritos y su puesto en la importancia del modelo final.
  - Los parámetros (`PARAM$GA$...`: rondas, población, generaciones, meses,
    LightGBM del fitness) están al principio del script.
- **Configuración en `.env`**: grupo, rutas, mail, Kaggle. Si falta una
  variable, corta al arrancar con su nombre.
- **Semillas fijas**: primigenia 100213, semillerio de 9:
  `100213, 100313, 100613, 100913, 101113` más 4 primos sorteados
  `570991, 669287, 832421, 882599` (en vez de 10 primos al azar).
- **Mail a una lista**: arranque, fin de cada etapa, cada N evaluaciones de la
  BO, error (con la etapa), fin, y si GCP expropia la VM. Un mail que falla no
  corta la corrida.
- **Registro de la corrida**: el mail final (y `registro.txt` en la carpeta)
  trae la versión del script (commit), grupo, línea de tiempo, semillas,
  tamaño del dataset final, mejor AUC y los hiperparámetros del modelo final,
  la duración de cada etapa, el `PARAM.yml` completo y la lista de archivos.
- **Checkpoints en el bucket**, para que una expropiación no pierda trabajo:

  | Qué | Archivo (en `exp/WF<experimento>/`) |
  |---|---|
  | dataset después del FE histórico | `checkpoints/dataset_fe_historico.fst` |
  | dataset después de canaritos | `checkpoints/dataset_canaritos.fst` |
  | cada punto del diseño inicial de la BO | `BO_init.txt` |
  | cada evaluación de la BO | `BO_iter.txt` |
  | estado de la BO en cada iteración | `HT.RDATA` |
  | un modelo final por semilla | `modelos/modelo_<semilla>.txt` |
  | cada archivo subido a Kaggle | `kaggle/*.csv.subido` |

  El z635 solo grababa la BO cada 600 s y nunca durante el diseño inicial (20
  entrenamientos): si se cortaba ahí, se perdía todo.

## La genética v2

La primera versión de la genética tenía dos problemas de diseño que la
hacían aceptar ruido:

1. **Elegía con el mismo mes que valida la BO.** El fitness medía en 202107
   (A) o 202105 (B), que es el `validate` de la BO. Las `gen_*` se eligen por
   ser buenas en ese mes y después la BO evalúa en ese mismo mes: la ganancia
   de validación sale inflada a favor de ellas.
2. **El umbral de 2 desvíos compara cosas distintas.** Compara el *máximo* de
   cientos de fórmulas contra el ruido entre semillas de *una* sola (y con 3
   semillas, un desvío muy impreciso). El máximo de muchas fórmulas inútiles
   supera 2 desvíos casi seguro (winner's curse).

La v2 mide en otros meses y decide con un control contra el azar:

| Grupo | Búsqueda (gramEvol) | Control | Nunca |
|---|---|---|---|
| A | 202103 | 202105 | 202107, 202109 |
| B | 202101 | 202103 | 202105, 202107 |

El script corta con error si se le pide medir en un mes prohibido.

**Prueba con datos sintéticos** (una variable con señal plantada, `v1 / v2`,
y el resto ruido puro; control de 5 fórmulas al azar para que fuera rápido).
Las ganadoras de la búsqueda, ronda por ronda:

| Fórmula | Mejora en la búsqueda | Umbral 2 desvíos | Regla v1 | Mejora en el control | Puesto | Regla v2 |
|---|---|---|---|---|---|---|
| ronda 1: `(v3 * v6) + v3` (ruido) | 3.000.700 | 2.457.304 | queda | −796.300 | 2 de 6 | descartada |
| ronda 2: `(v6 * v3) - v3` (ruido) | 3.048.150 | 2.457.304 | queda | −1.160.550 | 3 de 6 | descartada |

Las dos fórmulas de ruido superan el umbral porque cada una es la mejor de
cientos; en un mes que no vieron, pierden. Puesta a mano en el control,
`v1 / v2` (la señal) sale primera con +628.800. El costo del control es que
el ruido también puede salir primero: con 5 fórmulas al azar, 1 de cada 6
veces; con las 19 de la configuración real, 1 de cada 20.

**Variables nuevas del `.env`** (todas opcionales; sin ellas corre como antes,
salvo los meses y la regla de la genética):

| Variable | Qué hace |
|---|---|
| `GA_MODO` | `genetica` (default), `azar` (una fórmula sorteada por ronda, sin búsqueda), `nada` (sin FE genético) o `transferencia` (ver abajo) |
| `GA_FORZAR=1` | las ganadoras entran aunque no pasen el control (el veredicto queda registrado igual) |
| `GA_VALIDA_BUSQUEDA`, `GA_VALIDA_CONTROL` | meses de la genética (defaults en la tabla de arriba) |
| `GA_BUSQUEDA_EN_BO=1` | deja que la búsqueda mida en el mes de validación de la BO (202107 en el A, 202105 en el B); el control sigue sin poder. Lo usa el brazo E4 |
| `GA_VENTANA` | meses de entrenamiento del fitness antes de cada mes, con 1 de gap (vacío o 0: todos desde 201901, como la v1; 6 es ~4 veces más rápido) |
| `GA_N_CONTROL` | fórmulas al azar del control (19) |
| `GA_UNDERSAMPLING` | fracción de CONTINUA en el fitness (0.2) |
| `GA_RONDAS` | rondas de la genética (3) |
| `HT_FIJO` | ruta a un `BO_log.txt` de otra corrida: se usa su mejor fila y no se corre la BO |
| `FT_SEMILLAS_N` | cuántas semillas del semillerio final usar (default: las 9) |
| `FT_UNDERSAMPLING` | fracción de CONTINUA en el final train (default 1 = todos) |
| `KAGGLE_SUBIR=0` | grupo A sin subir a Kaggle (los CSV quedan igual) |
| `TRF_BUSQUEDAS`, `TRF_MEDIR`, `TRF_TOP` | solo con `GA_MODO=transferencia`: meses de búsqueda, meses donde se vuelve a medir y cuántas fórmulas (20) |

**`GA_MODO=transferencia`** no corre el workflow: después del FE intra-mes,
por cada mes de búsqueda corre una ronda de la genética, toma las 20 mejores
fórmulas distintas y 20 al azar de la misma gramática, y mide las 40 en los
meses posteriores con 3 semillas de LightGBM, contra la base sin fórmula.
Responde si lo que elige la genética en un mes sigue sirviendo después, más
que una fórmula cualquiera, sin pasar por el modelo final. Graba
`transferencia.txt` (una fila por medición; es también el checkpoint),
`transferencia_formulas.txt` y `transferencia_resumen.txt`, manda el resumen
por mail y termina. Con los defaults del grupo A fueron unas 4,5 h en
`to-128ram-12vcpu` (WF9530). Con `GA_CON_HISTORIA=1` corre después del FE
histórico: la base del fitness ve los lags y tendencias, y cada fórmula entra
con sus lags y deltas, como en la genética con historia (más lento: el dataset
es más ancho). Con `GA_COMBINAR_HISTORIA=1` además las fórmulas (y las
sorteadas) combinan los lags, deltas y tendencias, no solo los campos del mes.

En grupo B la corrida graba además `ganancia_meseta.txt`: el promedio de la
ganancia en 202107 en los 9 cortes fijos (8.000 a 12.000 envíos). Es la
métrica para comparar corridas; el máximo de la curva se elige mirando la
respuesta y no sirve para eso.

**¿La genética mejora el modelo final?** Eso no se ve en una corrida del LB
público (el desvío de la diferencia entre dos corridas ronda los 7 M). Para
eso está el [experimento de brazos](brazos/README.md): grupo B, las 10
semillas asignadas pareadas, sin genética vs. genética (fitness con 6 meses y
con todos) vs. fórmulas al azar.

## Puesta en marcha

Todo se hace desde **Git Bash** en tu PC, con `gcloud` instalado y logueado
con la cuenta dueña del proyecto de la cátedra (`gcloud auth login`). Nada
secreto va al repo, que es público: la clave del mail, los destinatarios y
el `kaggle.json` viven en tu bucket.

### 1. Tus datos de GCP

```sh
gcloud projects list                          # PROJECT_ID de tu proyecto de la cátedra
gcloud compute instance-templates list        # tienen que aparecer los to-128ram-...
gsutil ls                                      # el nombre de tu bucket (gs://...)
gsutil ls gs://<bucket>/datasets/              # tiene que estar analistasr_competencia_2026.csv.gz
```

Si no ves los templates `to-...`, tu proyecto no tiene la infra de la cátedra
armada: hay que correr primero su script de alta.

### 2. El mail

El script manda los mails desde una cuenta de Gmail con una **app password**
(una clave de 16 letras solo para esto; no es la clave de la cuenta).

1. En la cuenta que va a mandar, activá la **verificación en 2 pasos**:
   https://myaccount.google.com/signinoptions/twosv (sin eso Google no deja
   crear app passwords).
2. Creá la app password en https://myaccount.google.com/apppasswords
   (nombre: `workflow635`). Copiá las 16 letras **sin espacios**.
3. Subila al bucket (reemplazá las x y el bucket):
   ```sh
   printf '%s' 'xxxxxxxxxxxxxxxx' | gsutil cp - gs://<bucket>/secrets/gmail_app_password
   ```
4. Los destinatarios, uno por línea (puede ser la misma cuenta u otras):
   ```sh
   printf 'vos@gmail.com\notro@gmail.com\n' | gsutil cp - gs://<bucket>/wf635/destinatarios.txt
   ```
5. Probá que anda **antes de lanzar**, desde Git Bash (`curl` ya viene):
   ```sh
   DESDE=tu_cuenta@gmail.com; PARA=vos@gmail.com
   printf "From: $DESDE\nTo: $PARA\nSubject: prueba workflow635\n\nanda\n" > /tmp/m.txt
   curl -s --ssl-reqd --url smtps://smtp.gmail.com:465 --mail-from $DESDE --mail-rcpt $PARA \
     --user "$DESDE:$(gsutil cat gs://<bucket>/secrets/gmail_app_password)" -T /tmp/m.txt; echo "codigo: $?"
   ```
   `codigo: 0` = enviado. `67` = Google rechazó el login: la app password no
   es de esa cuenta o tiene espacios.

Los mails llegan en **dos hilos** por experimento: `[WF<exp> grupo A]
experimento` (arranque, fin de cada etapa con sus tiempos, errores, VM
expropiada, registro final) e `[WF<exp> grupo A] iteraciones` (cada
generación de la genética y el avance de la BO).

### 3. Kaggle (solo grupo A)

Bajá tu `kaggle.json` de https://www.kaggle.com/settings (API → Create New
Token) y subilo:

```sh
gsutil cp kaggle.json gs://<bucket>/kaggle/kaggle.json
```

El CLI de Kaggle lo instala el script en la VM. Si falta el `kaggle.json`,
llega un mail de aviso al arrancar y al final los archivos quedan en
`exp/WF<exp>/kaggle/` para subir a mano.

### 4. Configuración y lanzamiento

```sh
cp vm/vm.env.example vm/vm.env     # PROJECT, BUCKET, TEMPLATE (to-128ram-12vcpu)
cp .env.example .env.A             # GRUPO=A, EXPERIMENTO, MAIL_FROM=tu_cuenta@gmail.com
vm/lanzar.sh A
```

`EXPERIMENTO` es la carpeta de salida (`exp/WF<EXPERIMENTO>`): uno distinto
por corrida, si no retoma la anterior. Los `.env.*` y `vm/vm.env` no se
commitean (están en el `.gitignore`).

`lanzar.sh`:

1. chequea la cuota de vCPUs;
2. sube el script y el `.env` a `gs://<bucket>/wf635/<grupo>/`;
3. crea un template propio, copia del de la cátedra (misma máquina, disco,
   imagen, Spot) con `vm/startup.sh` y `vm/shutdown.sh`;
4. crea un **grupo administrado de una VM** (`wf635-a` / `wf635-b`).

**Si GCP expropia la VM**, llega un mail y el grupo crea otra sola, que
retoma desde el último checkpoint. No hay que hacer nada.

**Al terminar, o si R falla**, la VM espera 30 minutos y baja el grupo a 0,
así no se recrea (con `APAGAR_AL_TERMINAR=1`). Si R muere sin poder avisar
(por ejemplo, sin memoria), el startup manda el mail.

Para pararlo a mano: `vm/parar.sh A`. Para seguir después: `vm/lanzar.sh A`.

Log en vivo:

```sh
gsutil cat gs://<bucket>/wf635/A/log.txt | tail -50
```

### 5. Ensamble de semillas (grupo A)

`ensamblar.R` promedia la `prob` del `prediccion.txt` de varias corridas
terminadas y escribe los mismos 9 cortes que el workflow, para subir a mano.
En una VM con el bucket montado y el repo copiado en
`/home/ds/buckets/b1/wf635v2` (como en [brazos](brazos/README.md#cómo-correrlo)):

```sh
E=/home/ds/buckets/b1/exp
cd /tmp
sudo -u ds -H Rscript /home/ds/buckets/b1/wf635v2/ensamblar.R $E/ENS_E2A $E/WF9912_s100213 $E/WF9912_s100313 $E/WF9912_s271211
```

Deja `ENS_E2A/kaggle/KAENS_E2A_<envios>.csv` y la `prob` promedio, con la de
cada corrida al lado, en `ENS_E2A/prediccion.txt`. En el LB público, promediar
3 semillas sumó de 2 a 5 M de meseta contra una corrida suelta
([resultados](brazos/README.md#resultados-2026-10-13)).

## Las máquinas

Los templates de la cátedra están en el proyecto
(`gcloud compute instance-templates list`): Spot, n2 custom, de 128 a 512 GB,
con 8 o 12 vCPU, imagen `labo-family`. Los de la cátedra borran la VM al
expropiarse (`DELETE`), pero GCP no acepta eso en un grupo administrado: el
template propio usa `STOP`, y el grupo vuelve a arrancar la VM detenida.

Con una sola corrida a la vez conviene `TEMPLATE=to-128ram-12vcpu` en
`vm/vm.env`: usa los 12 vCPU de la cuota.

Detalles de la imagen que el script ya resuelve:

- el bucket lo monta gcsfuse para el usuario `ds` y **root no lo puede leer**:
  los scripts de la VM acceden como `ds`;
- gcsfuse sube un archivo recién al cerrarlo: el log se escribe en el disco
  local y se copia al bucket cada minuto;
- el Python es "externally managed" (PEP 668): el CLI de Kaggle se instala con
  `pip --user --break-system-packages`;
- desde Git Bash, `lanzar.sh` evita que las rutas del metadata se conviertan en
  rutas de Windows.

La cuota global de este proyecto es de **12 vCPUs**: dos VM de
`to-128ram-08vcpu` (8 + 8) no entran a la vez. `lanzar.sh` lo chequea antes
de crear nada.

## Primera corrida (WF9500, grupo A, 2026-10-10)

Corre en `to-128ram-12vcpu`. Tiempos medidos hasta la BO:

| Etapa | min |
|---|---|
| lectura + CA + drift + FE intra-mes | ~2 |
| FE genético | 11,4 |
| FE histórico | 6,1 |
| FE random forest | 3,1 |
| canaritos | 4,0 |

La genética evaluó 230 fórmulas distintas (~3 s cada una). La mejor,
`vm_mconsumosdolares * vmr_mpagado`, mejoró 2,26 M, por debajo del umbral de
5,7 M (2 desvíos de un ruido de 2,8 M): **ninguna variable genética quedó**.
El fitness barato y la búsqueda chica (600 contra 9.600 del default de
gramEvol) son lo primero a revisar.

Esa corrida usaba para el fitness solo 202101-202105 con el 10% de los
CONTINUA, y cortaba la genética en la primera ronda que no superaba el ruido.
Las dos cosas se cambiaron: el fitness usa los meses de la training strategy
del z635 (201901-202105, 20% de CONTINUA, mide en 202107: 1.037.931 filas,
ruido 3,1 M) y corren todas las rondas. La corrida con eso es **WF9501**.

Lo que la corrida confirmó: el uso de `gramEvol` (la fórmula llega a la
función de costo y el monitor por generación funciona), los checkpoints de
FE, el mail y la VM que retoma desde el bucket.

Pendiente:

- **El fitness de la genética.** Es un LightGBM de 200 árboles sobre una
  muestra sin lags: no está validado que prediga la ganancia del workflow
  completo. El [experimento de brazos](brazos/README.md#resultados-2026-10-13)
  pasó sus ganadoras por el workflow entero: no le ganan a 3 fórmulas
  sorteadas de la misma gramática. Lo que queda es un fitness más fiel
  (dataset completo, lags de la fórmula, varias semillas).
- **El tamaño de la búsqueda** (`PARAM$GA$poblacion`, `generaciones`), que
  con ~3 s por fórmula puede crecer mucho.
