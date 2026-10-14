# ===========================================================================
# Compara los brazos del workflow635 v2 (grupo B: ganancia real en 202107)
#   E0 (WF9900) sin genetica, E1 (WF9901) genetica v2 con 6 meses de fitness,
#   E2 (WF9902) formulas al azar, E3 (WF9903) genetica v2 con todos los meses,
#   E4 (WF9904) E1 con la busqueda en 202105, el mes de la BO (idea del #3)
# Pareado por semilla del pipeline. Las 10 semillas de SEMILLAS_BASE son las del
# experimento; E0 y E2 con otras semillas son la confirmacion de E2-E0, que se
# analiza aparte (una sola comparacion fijada antes de correrla). Metrica: ganancia_meseta.txt, el promedio
# de la ganancia en los cortes fijos de 8.000 a 12.000 envios.
#
# uso (en la VM, como ds):  Rscript brazos/analizar_brazos.R [carpeta exp]
# graba brazos_v2/brazos.csv y brazos_v2/genetica.csv; el resto va a la salida
# ===========================================================================
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly= TRUE)
EXP <- if (length(args)) args[1] else "/home/ds/buckets/b1/exp"
SALIDA <- file.path(EXP, "brazos_v2")
dir.create(SALIDA, showWarnings= FALSE)
BRAZOS <- c(E0= 9900L, E1= 9901L, E2= 9902L, E3= 9903L, E4= 9904L)
SEMILLAS_BASE <- c(100213, 271211, 100313, 353161, 100613, 487757, 100913, 641371, 101113, 823541)
MESES_GA <- list(E1= c(202101, 202103), E3= c(202101, 202103), E4= c(202105, 202103))   # busqueda, control

millones <- function(x) formatC(x / 1e6, format= "f", digits= 2, decimal.mark= ",", big.mark= ".")
miles <- function(x) formatC(round(x), format= "d", big.mark= ".", decimal.mark= ",")
p2 <- function(x) formatC(x, format= "f", digits= 3, decimal.mark= ",")

# --- corridas terminadas ----------------------------------------------------
leer_corrida <- function(brazo, carpeta) {
  g <- fread(file.path(carpeta, "ganancia_202107.txt"))
  cortes <- g[-nrow(g)]                  # la ultima fila es el maximo de la curva
  data.table(brazo= brazo,
    semilla= as.numeric(sub(".*_s", "", basename(carpeta))),
    meseta= as.numeric(readLines(file.path(carpeta, "ganancia_meseta.txt"), warn= FALSE)[1]),
    g10000= cortes[envios == 10000, ganancia],
    maximo= g[nrow(g), ganancia], envios_max= g[nrow(g), envios],
    horas= {
      r <- if (file.exists(file.path(carpeta, "registro.txt"))) readLines(file.path(carpeta, "registro.txt"), warn= FALSE) else ""
      h <- regmatches(r, regexpr("esta sesion: [0-9.]+ h", r))
      if (length(h)) as.numeric(gsub("[^0-9.]", "", h[1])) else NA_real_
    },
    carpeta= carpeta)
}

runs <- rbindlist(lapply(names(BRAZOS), function(b) {
  d <- Sys.glob(file.path(EXP, sprintf("WF%d_s*", BRAZOS[[b]])))
  d <- d[file.exists(file.path(d, "TERMINADO")) & file.exists(file.path(d, "ganancia_meseta.txt"))]
  rbindlist(lapply(d, function(x) leer_corrida(b, x)))
}))

cat("Brazos del workflow635 v2, grupo B (ganancia real en 202107)\n")
cat("Generado:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n\n")
if (!nrow(runs)) { cat("Todavia no termino ninguna corrida.\n"); quit(save= "no") }

fwrite(runs, file.path(SALIDA, "brazos.csv"))
cat("Corridas terminadas por brazo:", paste(names(table(runs$brazo)), table(runs$brazo), sep= "=", collapse= "  "), "\n\n")

ancho <- dcast(runs[semilla %in% SEMILLAS_BASE], semilla ~ brazo, value.var= "meseta")
cat("Meseta por semilla (millones):\n")
print(ancho[, c(list(semilla= semilla), lapply(.SD, millones)), .SDcols= setdiff(names(ancho), "semilla")], row.names= FALSE)
cat("\nPromedio por brazo (millones):",
  paste(runs[semilla %in% SEMILLAS_BASE, .(m= millones(mean(meseta))), by= brazo][order(brazo), paste0(brazo, " ", m)], collapse= "   "), "\n")
cat("Horas por corrida (mediana):",
  paste(runs[, .(h= median(horas, na.rm= TRUE)), by= brazo][order(brazo), paste0(brazo, " ", formatC(h, format= "f", digits= 1, decimal.mark= ","))], collapse= "   "), "\n\n")

# --- diferencias pareadas -----------------------------------------------------
comparar <- function(a, b, tabla= ancho) {
  if (!all(c(a, b) %in% names(tabla))) return(NULL)
  x <- (tabla[[a]] - tabla[[b]])
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 2) return(data.table(comparacion= paste(a, "-", b), n= n))
  set.seed(1)
  boot <- replicate(20000, mean(sample(x, replace= TRUE)))
  # Wilcoxon exacto: con n semillas el p mas chico posible es 2/2^n (6: 0,031; 10: 0,002)
  p <- tryCatch(suppressWarnings(wilcox.test(x, exact= n <= 25)$p.value), error= function(e) NA_real_)
  data.table(comparacion= paste(a, "-", b), n= n,
    media= mean(x), mediana= median(x), gana= sum(x > 0),
    ic_inf= quantile(boot, 0.025), ic_sup= quantile(boot, 0.975), p_wilcoxon= p)
}
tb <- rbindlist(list(comparar("E1", "E0"), comparar("E2", "E0"), comparar("E1", "E2"),
                     comparar("E3", "E0"), comparar("E3", "E2"), comparar("E3", "E1"),
                     comparar("E4", "E0"), comparar("E4", "E2"), comparar("E4", "E1")), fill= TRUE)
imprimir <- function(tb) for (i in seq_len(nrow(tb))) with(tb[i], if (is.na(media)) cat(sprintf("  %s: n=%d, faltan pares\n", comparacion, n)) else
  cat(sprintf("  %s: n=%d  media %s  mediana %s  gana %d de %d  IC [%s; %s]  p Wilcoxon %s%s%s\n",
    comparacion, n, millones(media), millones(mediana), gana, n,
    millones(ic_inf), millones(ic_sup), p2(p_wilcoxon),
    if (!is.null(tb$p_holm)) paste0("  p Holm ", p2(p_holm)) else "",
    if (!isTRUE(p_wilcoxon < 0.05 && (ic_inf > 0 || ic_sup < 0))) ""
    else if (is.null(tb$p_holm) || isTRUE(p_holm < 0.05)) "  <- distinta de 0"
    else "  <- solo sin corregir")))
if (nrow(tb) && "media" %in% names(tb)) {
  # Holm sobre las comparaciones que ya tienen pares (las que faltan no cuentan)
  tb[!is.na(p_wilcoxon), p_holm := p.adjust(p_wilcoxon, method= "holm")]
  cat("Diferencias pareadas por semilla (millones; IC 95% bootstrap de la media; Holm sobre",
      sum(!is.na(tb$p_wilcoxon)), "comparaciones):\n")
  imprimir(tb)
  cat("  (E1-E0: lo que aporta la genetica; E2-E0: agregar 3 formulas cualquiera;",
      "E1-E2: lo que aporta BUSCAR la formula; E3-E1: entrenar el fitness con todos",
      "los meses en vez de 6; E4-E1: buscar en el mes de la BO en vez de 202101)\n\n")
}

# --- confirmacion de E2-E0 con semillas nuevas --------------------------------
conf <- runs[!semilla %in% SEMILLAS_BASE & brazo %in% c("E0", "E2")]
if (nrow(conf)) {
  conf <- dcast(conf, semilla ~ brazo, value.var= "meseta")
  cat("Confirmacion de E2-E0 con", nrow(conf), "semillas nuevas (millones):\n")
  print(conf[, c(list(semilla= semilla), lapply(.SD, millones)), .SDcols= setdiff(names(conf), "semilla")], row.names= FALSE)
  tc <- comparar("E2", "E0", conf)
  if (!is.null(tc) && "media" %in% names(tc)) {
    cat("Una sola comparacion fijada antes de correr, sin correccion:\n")
    imprimir(tc)
    todas <- rbind(ancho[, .(semilla, E0, E2)], conf[, intersect(c("semilla", "E0", "E2"), names(conf)), with= FALSE], fill= TRUE)
    cat("Con las", nrow(todas[!is.na(E0) & !is.na(E2)]), "semillas juntas (informativo):\n")
    imprimir(comparar("E2", "E0", todas))
  }
  cat("\n")
}

# --- la genetica por dentro: busqueda, umbral de Andres y control -----------
rondas <- rbindlist(lapply(runs[brazo %in% c("E1", "E2", "E3", "E4")]$carpeta, function(d) {
  f <- file.path(d, "genetica_rondas.txt")
  if (!file.exists(f)) return(NULL)
  r <- fread(f, sep= "\t")
  r[, `:=`(brazo= runs[carpeta == d, brazo], semilla= runs[carpeta == d, semilla])]
  impo <- if (file.exists(file.path(d, "impo.txt"))) fread(file.path(d, "impo.txt")) else data.table(Feature= character())
  r[, puesto_impo := match(nombre, impo$Feature)]
  r[, de_impo := nrow(impo)]
  r
}), fill= TRUE)

if (nrow(rondas)) {
  fwrite(rondas, file.path(SALIDA, "genetica.csv"))
  for (b in intersect(c("E1", "E3", "E4"), unique(rondas$brazo))) {
    g <- rondas[brazo == b]
    g[, pasa_2sd := mejora > umbral]
    g[, pasa_control := puesto_control == 1 & mejora_control > 0]
    cat(sprintf("Genetica (%s, %s), una fila por ronda: la busqueda mide en %d, el control en %d\n",
      b, if (b == "E3") "fitness con todos los meses" else "fitness con 6 meses", MESES_GA[[b]][1], MESES_GA[[b]][2]))
    print(g[order(semilla, ronda), .(semilla, ronda, formula,
      busqueda= miles(mejora), umbral_2sd= miles(umbral), pasa_2sd,
      control= miles(mejora_control), puesto= paste0(puesto_control, "/20"),
      pasa_control, impo= paste0(puesto_impo, "/", de_impo))], row.names= FALSE)
    cat(sprintf("\nRondas que pasan el umbral de 2 desvios (regla de Andres): %d de %d\n", sum(g$pasa_2sd, na.rm= TRUE), nrow(g)))
    cat(sprintf("Rondas que pasan el control (puesto 1 de 20 y mejora > 0): %d de %d (si la genetica no aporta nada, se esperan %s)\n",
      sum(g$pasa_control, na.rm= TRUE), nrow(g), formatC(nrow(g) / 20, format= "f", digits= 1, decimal.mark= ",")))
    cat(sprintf("Mejora en el control de las ganadoras: mediana %s, positiva en %d de %d\n",
      miles(median(g$mejora_control, na.rm= TRUE)), sum(g$mejora_control > 0, na.rm= TRUE), nrow(g)))
    # se repite la formula entre semillas? si la senal es real, deberia
    rep <- g[, .N, by= formula][N > 1]
    if (nrow(rep)) { cat("Formulas que ganan en mas de una semilla:\n"); print(rep[order(-N)], row.names= FALSE) }
    else cat("Ninguna formula gano en mas de una semilla.\n")
    # las semillas donde el control dice que si, ganan mas?
    por_semilla <- g[, .(pasan= sum(pasa_control, na.rm= TRUE)), by= semilla]
    if (all(c(b, "E0") %in% names(ancho))) {
      por_semilla <- merge(por_semilla, ancho[, .(semilla, dif= get(b) - E0)], by= "semilla")
      cat(sprintf("\n%s-E0 segun cuantas rondas pasaron el control en esa semilla:\n", b))
      print(por_semilla[order(-pasan), .(semilla, pasan, dif= millones(dif))], row.names= FALSE)
    }
    cat("\n")
  }
  a <- rondas[brazo == "E2"]
  if (nrow(a)) {
    cat("\nFormulas al azar (E2):\n")
    print(a[order(semilla, ronda), .(semilla, ronda, formula, impo= paste0(puesto_impo, "/", de_impo))], row.names= FALSE)
  }
}

# --- tiempos de la cola (tiempos_<vm>.tsv si la cola se repartio entre VM) ---
f <- list.files(SALIDA, "^tiempos.*[.]tsv$", full.names= TRUE)
if (length(f)) {
  t <- rbindlist(lapply(f, fread))
  if (nrow(t)) {
    cat("\nMinutos por corrida (cola):\n")
    print(t[, .(corridas= .N, fallidas= sum(rc != 0), mediana_min= as.numeric(median(minutos))), by= brazo], row.names= FALSE)
  }
}
