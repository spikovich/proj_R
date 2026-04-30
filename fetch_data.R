#!/usr/bin/env Rscript
# fetch_data.R
# Stiahne historicke ceny a aktualny option chain pre AAPL.
#
# POZN: getOptionChain z packagu quantmod nefunguje z GDPR krajin (EU)
# kvoli Yahoo crumb mechanizmu. Tento skript je preto urceny primarne
# na spustenie v GitHub Actions (runners su v US).

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
  getOptionChain(TICKER, NULL),
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
# 3) Vyber expiraciu a strikes pre kvalitnu analyzu
# -----------------------------------------------------------------
message("[3/3] Vyberam expiraciu a filtrujem opcie...")

expiry_dates <- as.Date(sapply(all_opts, function(x) {
  if (!is.null(x$calls) && nrow(x$calls) > 0) {
    as.character(as.Date(x$calls$Expiration[1]))
  } else NA
}))

days_to_exp <- as.numeric(expiry_dates - Sys.Date())

# Optimalne expiracie: 30-90 dni (likvidne, dost casu, mensia citlivost na T->0)
good_idx <- which(days_to_exp >= 30 & days_to_exp <= 90 & !is.na(days_to_exp))
if (length(good_idx) == 0) {
  good_idx <- which.min(abs(days_to_exp - 60))
}

target_idx <- good_idx[which.min(abs(days_to_exp[good_idx] - 60))]
target_expiry <- expiry_dates[target_idx]
target_calls  <- all_opts[[target_idx]]$calls

message(sprintf("      vybrana expiracia: %s (T = %d dni)",
                target_expiry, days_to_exp[target_idx]))
message(sprintf("      surovy chain ma %d call opcii", nrow(target_calls)))

# --- Strategia vyberu ceny ---
# Ked je trh OTVORENY: pouzivame mid = (Bid+Ask)/2 - najpresnejsia
# Ked je trh ZATVORENY: bid/ask su 0, pouzivame Last
# Detekcia: ak >50% opcii ma Bid>0, povazujeme trh za otvoreny

market_open <- mean(target_calls$Bid > 0, na.rm = TRUE) > 0.5
message(sprintf("      trh otvoreny: %s (%.0f%% opcii ma Bid>0)",
                ifelse(market_open, "ano", "nie"),
                100 * mean(target_calls$Bid > 0, na.rm = TRUE)))

target_calls$market_price <- if (market_open) {
  ifelse(target_calls$Bid > 0 & target_calls$Ask > 0,
         (target_calls$Bid + target_calls$Ask) / 2,
         target_calls$Last)
} else {
  target_calls$Last
}

# --- Filtrovanie ---
# 1. Strike v rozumnom okne okolo spot ceny (+/- 15%)
# 2. Pozitivna trhova cena
# 3. Pozitivna IV od Yahoo
# 4. Vylucujeme deep ITM (kde IV by mala byt deterministicka)
# 5. Aspon nejaky volume alebo open interest
strike_lo <- last_close * 0.85
strike_hi <- last_close * 1.15

filtered <- target_calls[
  target_calls$Strike   >= strike_lo &
  target_calls$Strike   <= strike_hi &
  target_calls$market_price > 0.05 &      # cena > 5 centov
  target_calls$IV       > 0.05 &           # rozumna IV (>5%)
  target_calls$IV       < 2.0 &            # < 200% (vylucuje fiktivne hodnoty)
  (target_calls$Vol > 0 | target_calls$OI > 0),  # nejaky obchod
]

message(sprintf("      po filtrovani: %d opcii", nrow(filtered)))

# Fallback: ak filter prilis pristny, povolime aspon casti
if (nrow(filtered) < 5) {
  message("      filter prilis pristny, relaxujem podmienky...")
  filtered <- target_calls[
    target_calls$Strike   >= strike_lo &
    target_calls$Strike   <= strike_hi &
    target_calls$market_price > 0.05 &
    target_calls$IV       > 0.05 &
    target_calls$IV       < 2.0,
  ]
  message(sprintf("      po relaxovani: %d opcii", nrow(filtered)))
}

# Pripravime na export
options_df <- data.frame(
  contract_id  = filtered$ContractID,
  expiry       = as.Date(filtered$Expiration),
  strike       = filtered$Strike,
  bid          = filtered$Bid,
  ask          = filtered$Ask,
  last         = filtered$Last,
  market_price = filtered$market_price,
  volume       = filtered$Vol,
  open_int     = filtered$OI,
  iv_yahoo     = filtered$IV
)

# Zoradenie podla strike
options_df <- options_df[order(options_df$strike), ]

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
  sprintf("market_was_open: %s", market_open),
  sprintf("price_source: %s", ifelse(market_open, "mid (bid+ask)/2", "last trade")),
  sprintf("fetched_at: %s", Sys.time())
)
writeLines(meta, "data/meta.txt")

message("\nHotovo. Zhrnutie:")
cat(paste(meta, collapse = "\n"), "\n")
