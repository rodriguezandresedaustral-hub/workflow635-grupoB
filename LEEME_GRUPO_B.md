# Cómo correr esto en el grupo B

Este es el workflow635 con la genética **después del FE histórico** y con las
fórmulas pudiendo **combinar lags, deltas y tendencias** (lo que sugirió
Denicolay). El archivo `.env.B` ya está armado para el grupo B: no hace falta
tocarlo.

Por defecto corre la **prueba de transferencia**, no el workflow entero: la
genética busca fórmulas en 202011 y en 202101, y las 20 mejores de cada
búsqueda se vuelven a medir en 202101, 202103 y 202105 contra 20 fórmulas al
azar. Responde si lo que elige la genética en un mes sigue sirviendo en los
meses siguientes. En el grupo A esta misma prueba tarda unas 34 h.

## Lo que hace falta antes

- **Git Bash** en tu PC (viene con Git para Windows: https://git-scm.com/download/win).
- **gcloud** instalado y logueado con la cuenta de tu proyecto de la cátedra
  (https://cloud.google.com/sdk/docs/install, después `gcloud auth login`).
- En tu bucket, el dataset en `datasets/analistasr_competencia_2026.csv.gz`.

## Pasos

1. **Bajar el código.** En la página del repo: botón verde **Code** →
   **Download ZIP**. Descomprimirlo en cualquier carpeta.
2. **Abrir Git Bash en esa carpeta.** Clic derecho adentro de la carpeta →
   **Open Git Bash here**.
3. **Buscar tus datos de GCP:**
   ```sh
   gcloud projects list                     # el PROJECT_ID
   gsutil ls                                # el nombre de tu bucket (sin gs://)
   gcloud compute instance-templates list   # tiene que aparecer to-128ram-12vcpu
   ```
4. **Crear `vm/vm.env`** a partir del ejemplo y completar `PROJECT` y `BUCKET`:
   ```sh
   cp vm/vm.env.example vm/vm.env
   notepad vm/vm.env
   ```
5. **Lanzar:**
   ```sh
   bash vm/lanzar.sh B
   ```
   Crea una VM Spot que se recrea sola si GCP la expropia, y que se apaga sola
   30 minutos después de terminar.

## Mirar cómo va

```sh
gsutil cat gs://<tu bucket>/wf635/B/log.txt | tail -30
```

Para pararla a mano: `bash vm/parar.sh B`. Para seguir después:
`bash vm/lanzar.sh B` (retoma desde donde quedó).

## El resultado

Al terminar aparece `TERMINADO` en `gs://<tu bucket>/exp/WF9632/`, junto con:

- `transferencia_resumen.txt`: por cada búsqueda y mes medido, la mejora
  promedio de las fórmulas de la genética contra las al azar, el p de
  Wilcoxon y la correlación entre la búsqueda y después.
  ```sh
  gsutil cat gs://<tu bucket>/exp/WF9632/transferencia_resumen.txt
  ```
- `transferencia_formulas.txt`: el detalle por fórmula.

## Si querés cambiar algo

Todo se cambia en `.env.B` (se abre con `notepad .env.B`):

- **Mails:** así como está no manda mails. Para recibirlos, seguir
  "2. El mail" del `README.md` y completar las tres líneas `MAIL_` como dice
  el comentario.
- **Workflow completo** con esta genética, en vez de la prueba:
  `GA_MODO=genetica`.
- **Otra corrida:** cambiar `EXPERIMENTO`. Con el mismo número, retoma la
  anterior.
