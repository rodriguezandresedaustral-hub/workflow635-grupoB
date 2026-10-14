# Experimento de brazos (grupo B)

¿Las variables de la genética mejoran el **modelo final**? El fitness es un
LightGBM chico sobre una muestra sin lags, así que no alcanza con que ganen en
la búsqueda: hay que pasarlas por el workflow entero y medir contra la clase
real. Una corrida en el LB público no sirve para esto: el público es el 30%
de 202109 y el desvío de la diferencia entre dos corridas ronda los 7 M.

Por eso: grupo B (ganancia real en 202107), varias semillas del pipeline y,
en cada semilla, cuatro brazos con todo lo demás igual.

| Brazo | Experimento | `GA_MODO` | Pregunta |
|---|---|---|---|
| E0 | WF9900 | `nada` | la base, sin FE genético |
| E1 | WF9901 | `genetica` + `GA_FORZAR=1`, fitness con 6 meses | ¿las 3 ganadoras de la genética mejoran el modelo final? |
| E2 | WF9902 | `azar` | ¿3 fórmulas cualquiera de la misma gramática hacen lo mismo? |
| E3 | WF9903 | `genetica` + `GA_FORZAR=1`, fitness con todos los meses | ¿entrenar el fitness con toda la historia elige mejores fórmulas? |
| E4 | WF9904 | como E1, con la búsqueda en 202105 y el control en 202103 (`GA_BUSQUEDA_EN_BO=1`) | ¿buscar en el mes con clase más cercano al testing elige mejores fórmulas? (la idea del #3, en grupo B) |

- **E1 − E0** es lo que aporta la genética.
- **E1 − E2** es lo que aporta *buscar*: si no es positivo, la búsqueda no
  sirve y alcanza con sortear fórmulas.
- **E3 − E1** es lo que aporta entrenar el fitness con todos los meses desde
  201901 (el default, como la v1) en vez de los 6 anteriores (~4 veces más
  filas y más lento). E3 − E0 y E3 − E2 son las mismas preguntas de arriba
  para E3.
- **E4 − E1** es lo que aporta buscar en el mes de la BO (202105) en vez de
  202101. El control no puede ir después de 202105 (202107 es el testing), así
  que queda en 202103, que la búsqueda usa para entrenar: es un control más
  débil que el de E1.
- E1 fuerza las ganadoras para medirlas siempre, pero registra el veredicto
  del control: se ve si las semillas donde el control dijo "sí" son las que
  ganan.
- Semillas: las 10 asignadas, intercaladas para que cualquier corte de la
  cola quede repartido: 100213, 271211, 100313, 353161, 100613, 487757,
  100913, 641371, 101113 y 823541. Con Wilcoxon pareado hacen falta al menos
  6 para poder llegar a p < 0,05 (el p más chico posible es 2/2^n: 0,031 con
  6, 0,002 con 10).
- Confirmación: E0 y E2 con 10 semillas nuevas (512959, 683323, 187223,
  842879, 784841, 696929, 336239, 294023, 436693 y 272507), para ver si
  E2 − E0 (+3,3 M con p 0,020 en las 10 primeras, que no sobrevive a Holm)
  se repite. `analizar_brazos.R` la analiza aparte, como una sola comparación
  fijada antes de correrla.
- Con varias comparaciones, el análisis agrega el p de Holm.
- Métrica: `ganancia_meseta.txt`, el promedio de la ganancia en 202107 en los
  9 cortes fijos de 8.000 a 12.000 envíos.

Para que entre en unos días de VM, lo que no se compara está fijo en todos
los brazos:

- **HT fija** (`HT_FIJO`): la mejor fila del `BO_log.txt` de una corrida base
  del grupo B; no se corre la BO. Los `.env` apuntan a la nuestra
  (`exp/WF9600`, z635 grupo B con 30 iteraciones). En otro bucket hay que
  apuntar a un `BO_log.txt` propio, o dejarla vacía y que cada corrida haga su
  BO (mucho más lento).
- **Final train** de 3 semillas (`FT_SEMILLAS_N=3`) con el 20% de los
  CONTINUA (`FT_UNDERSAMPLING=0.2`), como entrenó la BO.
- Sin mail (`MAIL_TO_FILE=/dev/null`) y sin Kaggle.

## Resultados (2026-10-13)

E0 y E2 con 20 semillas (las 10 de arriba y las 10 de la confirmación), E1,
E3 y E4 con 10, más E0 y E2 en grupo A para Kaggle. El detalle por semilla y
ronda queda en `exp/brazos_v2/analisis.txt`.

Meseta promedio en las 10 semillas (millones): E0 582,69, E1 584,41,
E2 585,99, E3 582,83, E4 585,81.

| Comparación | Media | Gana | IC 95% | p Wilcoxon | p Holm |
|---|---|---|---|---|---|
| E2 − E0 | +3,30 | 8 de 10 | [1,13; 5,57] | 0,020 | 0,176 |
| E4 − E0 | +3,12 | 7 de 10 | [1,02; 5,03] | 0,037 | 0,297 |
| E1 − E0 | +1,72 | 7 de 10 | [−0,09; 3,47] | 0,111 | 0,668 |
| E1 − E2 | −1,58 | 5 de 10 | [−4,16; 1,06] | 0,322 | 1,000 |
| E4 − E2 | −0,18 | 5 de 10 | [−2,22; 2,03] | 0,883 | 1,000 |
| E3 − E2 | −3,16 | 2 de 10 | [−5,94; −0,77] | 0,037 | 0,297 |

- **Agregar 3 fórmulas suma algo; buscarlas, no.** E2 (sorteadas) y E4 le
  ganan a E0 por unos 3 M, pero ninguna genética le gana a E2: E1 − E2 da
  −1,58 M y E4 − E2, −0,18 M.
- **El control no distingue a las ganadoras del azar.** Pasan 2 de 30 rondas
  en E1, 3 de 30 en E3 y 2 de 30 en E4 (por azar se esperan 1,5), y ninguna
  fórmula ganó en más de una semilla.
- **Confirmación de E2 − E0** (10 semillas nuevas, una sola comparación
  fijada antes de correrla): +2,40 M, gana 8 de 10, IC [−0,63; 5,12], p 0,275.
  Va para el mismo lado, pero sola no alcanza. Con las 20 semillas juntas:
  +2,85 M, gana 16 de 20, IC [0,91; 4,65], p 0,010.
- **Costo:** mediana de 0,6 h por corrida en E0, E2 y E4, 0,8 h en E3 y 1,3 h
  en E1. E2 cuesta lo mismo que E0.

En Kaggle (E0A = WF9910, E2A = WF9912, las semillas 100213, 271211 y 100313;
LB público, el 30% de 202109, meseta de los 9 cortes):

| | Meseta pública |
|---|---|
| E0A, promedio de las 3 corridas | 443,4 |
| E2A, promedio de las 3 corridas | 441,1 |
| ensamble de las 3 E0A (`ensamblar.R`) | 448,7 |
| ensamble de las 3 E2A | 443,0 |
| ensamble de las 6 | 446,6 |

E0A contra E2A queda dentro del ruido del público. Lo que sí se ve es que la
semilla mueve más que el brazo (12 a 18 M entre semillas del mismo brazo,
2 o 3 M entre brazos) y que promediar semillas suma de 2 a 5 M y aplana la
curva entre cortes.

## Archivos

- `E0.env` a `E4.env`: los brazos. Revisar `BUCKET_DIR`, `DATASET_PATH` y
  `HT_FIJO`. E1, E2 y E4 fijan `GA_VENTANA=6`; E3 la deja vacía (todos los meses).
- `E0A.env` y `E2A.env`: E0 y E2 en grupo A (WF9910 y WF9912), para Kaggle.
  Los 9 cortes quedan en `kaggle/` de cada corrida, sin subir. Van por la
  misma cola: `BRAZOS="E0A E2A"`.
- `correr_brazos.sh`: la cola, semillas × brazos. Corre todos los brazos de
  cada semilla seguidos (si se corta a mitad, lo terminado ya está pareado),
  saltea lo que tiene `TERMINADO` y relanza lo que falló, que retoma desde sus
  checkpoints.
- `analizar_brazos.R`: la comparación pareada. Tabla por semilla, diferencias
  con IC bootstrap de la media y Wilcoxon exacto, la genética ronda por ronda
  (búsqueda, umbral de 2 desvíos, control, puesto en la importancia) y las
  fórmulas al azar de E2.

## Cómo correrlo

En una VM con el bucket montado (no Spot: una corrida tarda horas y la cola,
varios días), con el repo copiado en `/home/ds/buckets/b1/wf635v2`. La cola
corre como `ds`, dueña del bucket: en las VM de la cátedra los demás usuarios
no pueden leerlo, y `ds` no puede apagar la VM. Por eso se lanza desde un
usuario con sudo, envuelta en un `bash -c` que apaga al terminar:

```bash
cd /tmp
nohup setsid bash -c 'sudo -u ds -H bash /home/ds/buckets/b1/wf635v2/brazos/correr_brazos.sh; sudo poweroff' > ~/cola_brazos.log 2>&1 < /dev/null &
```

Para una sola corrida de prueba, sin apagar:

```bash
cd /tmp
sudo -u ds -H env SEMILLAS=100213 BRAZOS=E0 bash /home/ds/buckets/b1/wf635v2/brazos/correr_brazos.sh
```

Todo queda en `exp/brazos_v2/`:

- `cola.log`: avance de la cola.
- `WF990x_s<semilla>.log`: el log de cada corrida.
- `analisis.txt`: la comparación, que se actualiza después de cada corrida.
- `brazos.csv`, `genetica.csv`, `tiempos.tsv`: los datos.

Para frenar al terminar la corrida en curso:
`touch /home/ds/buckets/b1/exp/brazos_v2/PARAR`.

Opcionales de la cola (con `sudo -u ds -H env VAR=... bash ...`):
`SEMILLAS="..."`, `BRAZOS="..."`, `REINTENTOS=1` y `BORRAR_CHECKPOINTS=1`
(default: borra los `.fst` de `checkpoints/` de cada corrida terminada).
