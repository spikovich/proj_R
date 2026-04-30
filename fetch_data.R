#!/usr/bin/env Rscript
# fetch_data.R
# Stiahne historicke ceny a aktualny option chain pre AAPL.
#
# POZN: getOptionChain z packagu quantmod nefunguje z GDPR krajin (EU)
# kvoli Yahoo crumb mechanizmu. Tento skript je preto urceny primarne
# na spustenie v GitHub Actions (runners su v US).
#
# Lokalne stiahne aspon historicke ceny, ktore Yahoo posiela bez crumbu.

if (!requireNamespace("quantmod", quietly = TRUE)) {
  install.packages("quantmod", repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(quantmod)
})

dir.create("data", showWarnings = FALSE)

TICKER     <- "AAPL"
HIST_YEARS <- 2

# -----------------------------------------------------------------
# 1) Historicke ceny
# -----------------------------------------------------------------
message("[1/3] Stahujem historicke ceny ", TICKER, "...")
end_date   <- Sys.Date()
start_date <- end_date - 365 * HIST_YEARS

prices <- getSymbols(TICKER, src = "yahoo",
                     from = start_date, to = end_date,
                     auto.assign = FALSE)

prices_df <- data.frame(
  date   = as.Date(index(prices)),
  open   = as.numeric(prices[, paste0(TICKER, ".Open")]),
  high   = as.numeric(prices[, paste0(TICKER, ".High")]),
  low    = as.numeric(prices[, paste0(TICKER, ".Low")]),
  close  = as.numeric(prices[, paste0(TICKER, ".Close")]),
  adj    = as.numeric(prices[, paste0(TICKER, ".Adjusted")]),
  volume = as.numeric(prices[, paste0(TICKER, ".Volume")])
)
write.csv(prices_df, "data/aapl_prices.csv", row.names = FALSE)
message(sprintf("      ulozenych %d riadkov.", nrow(prices_df)))

last_close <- tail(prices_df$close, 1)
last_date  <- tail(prices_df$date, 1)
message(sprintf("      posledna cena: %.2f USD k %s", last_close, last_date))

# -----------------------------------------------------------------
# 2) Option chain - vsetky expiracie
# -----------------------------------------------------------------
message("[2/3] Stahujem option chain pre vsetky expiracie...")
all_opts <- tryCatch(
  getOptionChain(TICKER, NULL),  # NULL = vsetky expiracie
  error = function(e) {
    message("      CHYBA: ", conditionMessage(e))
    message("      (Toto je ocakavane lokalne v EU - skript bezi v GitHub Actions.)")
    NULL
  }
)

if (is.null(all_opts)) {
  message("[3/3] Preskakujem spracovanie opcii.")
  message("Hotovo (len historicke data).")
  quit(status = 0)
}

message(sprintf("      ziskanych %d expiracii.", length(all_opts)))

# -----------------------------------------------------------------
# 3) Vyber rozumne expiracie a strike-y
# -----------------------------------------------------------------
message("[3/3] Filtrujem opcie pre near-the-money, T = 30-90 dni...")

# Ziskame datumy expiracii
expiry_dates <- as.Date(sapply(all_opts, function(x) {
  if (!is.null(x$calls) && nrow(x$calls) > 0) {
    as.character(as.Date(x$calls$Expiration[1]))
  } else NA
}))

# Pocet dni do expiracie
days_to_exp <- as.numeric(expiry_dates - Sys.Date())

# Vyhovujuce expiracie: 30-90 dni
good_idx <- which(days_to_exp >= 30 & days_to_exp <= 90 & !is.na(days_to_exp))

if (length(good_idx) == 0) {
  # Fallback: zoberieme tu, co je najblizsie k 60 dnom
  good_idx <- which.min(abs(days_to_exp - 60))
  message("      ziadne expiracie v okne 30-90 dni, beriem najblizsiu k 60 dnom")
}

# Vyber jednu konkretnu expiraciu - tu, co je najblizsie k 45 dnom
target_idx <- good_idx[which.min(abs(days_to_exp[good_idx] - 45))]
target_expiry <- expiry_dates[target_idx]
target_calls  <- all_opts[[target_idx]]$calls

message(sprintf("      vybrana expiracia: %s (T = %d dni)",
                target_expiry, days_to_exp[target_idx]))

# Filter na near-the-money: strike v rozsahu +/-25% od spot
strike_lo <- last_close * 0.75
strike_hi <- last_close * 1.25
filtered <- target_calls[
  target_calls$Strike >= strike_lo &
  target_calls$Strike <= strike_hi &
  target_calls$Bid > 0 &           # musia mat ziva kotaciu
  target_calls$Ask > 0 &
  target_calls$IV  > 0.01,         # rozumna IV
]

if (nrow(filtered) == 0) {
  message("      ziadne opcie s plnymi datami, beriem all options s nenulovou IV")
  filtered <- target_calls[target_calls$IV > 0.01, ]
}

# Pripravime na export
options_df <- data.frame(
  contract_id = filtered$ContractID,
  expiry      = as.Date(filtered$Expiration),
  strike      = filtered$Strike,
  bid         = filtered$Bid,
  ask         = filtered$Ask,
  mid         = (filtered$Bid + filtered$Ask) / 2,
  last        = filtered$Last,
  volume      = filtered$Vol,
  open_int    = filtered$OI,
  iv_yahoo    = filtered$IV
)

write.csv(options_df, "data/aapl_options.csv", row.names = FALSE)
message(sprintf("      ulozenych %d call opcii.", nrow(options_df)))

# -----------------------------------------------------------------
# Meta info
# -----------------------------------------------------------------
meta <- c(
  sprintf("ticker: %s", TICKER),
  sprintf("spot_price: %.4f", last_close),
  sprintf("spot_date: %s", last_date),
  sprintf("option_expiry: %s", target_expiry),
  sprintf("days_to_expiry: %d", days_to_exp[target_idx]),
  sprintf("years_to_expiry: %.4f", days_to_exp[target_idx] / 365),
  sprintf("n_options: %d", nrow(options_df)),
  sprintf("fetched_at: %s", Sys.time())
)
writeLines(meta, "data/meta.txt")

message("\nHotovo. Zhrnutie:")
cat(paste(meta, collapse = "\n"), "\n")
