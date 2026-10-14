# ===========================================================================
# Ensamble de semillas (grupo A): promedia la prob de varias corridas
# terminadas (el prediccion.txt de cada exp/WF<exp>_s<semilla>) y escribe los
# mismos cortes que el workflow, para subir a Kaggle a mano. Las corridas
# tienen que predecir el mismo mes (mismo GRUPO).
#
# uso (en la VM, como ds):
#   Rscript ensamblar.R <carpeta salida> <corrida 1> <corrida 2> ...
#   Rscript ensamblar.R /home/ds/buckets/b1/exp/ENS_E2A \
#     /home/ds/buckets/b1/exp/WF9912_s100213 /home/ds/buckets/b1/exp/WF9912_s100313 ...
# graba <salida>/prediccion.txt (la prob promedio y la de cada corrida) y
# <salida>/kaggle/KA<nombre de la salida>_<envios>.csv
# ===========================================================================
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly= TRUE)
if (length(args) < 3) stop("uso: Rscript ensamblar.R <carpeta salida> <corrida 1> <corrida 2> ...")
SALIDA <- args[1]
CORRIDAS <- args[-1]
CORTES <- seq(8000, 12000, by = 500)   # los de PARAM$kaggle$cortes
if (anyDuplicated(basename(CORRIDAS))) stop("hay corridas repetidas")

leer <- function(carpeta) {
  archivo <- file.path(carpeta, "prediccion.txt")
  if (!file.exists(archivo)) stop("falta ", archivo, " (la corrida no termino?)")
  p <- fread(archivo, select= c("numero_de_cliente", "prob"))
  setnames(p, "prob", basename(carpeta))
  setkey(p, numero_de_cliente)
}
preds <- lapply(CORRIDAS, leer)
tb <- Reduce(function(a, b) merge(a, b, by= "numero_de_cliente"), preds)
filas <- sapply(preds, nrow)
if (any(filas != nrow(tb)))
  stop("las corridas no predicen los mismos clientes: ", paste(filas, collapse= " "), " filas, ", nrow(tb), " en comun")

cols <- basename(CORRIDAS)
tb[, prob := rowMeans(.SD), .SDcols= cols]
setcolorder(tb, c("numero_de_cliente", "prob"))
dir.create(file.path(SALIDA, "kaggle"), recursive= TRUE, showWarnings= FALSE)
fwrite(tb, file.path(SALIDA, "prediccion.txt"), sep= "\t")

# cuanto se parece cada corrida al ensamble: si comparten casi todo el top,
# promediar no cambia nada
top <- function(x) tb$numero_de_cliente[order(-x)][1:10000]
top_ens <- top(tb$prob)
cat("Corridas:", length(cols), " clientes:", nrow(tb), "\n")
cat("Del top 10.000 de cada corrida, cuanto queda en el del ensamble:\n")
for (col in cols) cat(sprintf("  %s: %.1f%%\n", col, 100 * mean(top(tb[[col]]) %in% top_ens)))

setorder(tb, -prob)
nombre <- basename(SALIDA)
for (envios in CORTES) {
  tb[, Predicted := 0L]
  tb[1:envios, Predicted := 1L]
  archivo_kaggle <- file.path(SALIDA, "kaggle", paste0("KA", nombre, "_", envios, ".csv"))
  fwrite(tb[, list(numero_de_cliente, Predicted)], file= archivo_kaggle, sep= ",")
}
cat("Cortes en", file.path(SALIDA, "kaggle"), "\n")
