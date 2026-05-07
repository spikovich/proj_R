[![Render and Publish](https://github.com/spikovich/proj_R/actions/workflows/publish.yml/badge.svg)](https://github.com/spikovich/proj_R/actions/workflows/publish.yml)
[![Live site](https://img.shields.io/badge/live-demo-success?logo=github)](https://spikovich.github.io/proj_R/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Made with Quarto](https://img.shields.io/badge/made%20with-Quarto-447099?logo=quarto)](https://quarto.org)
[![R](https://img.shields.io/badge/R-%E2%89%A54.4-276DC3?logo=r)](https://www.r-project.org/)
[![Data: AAPL](https://img.shields.io/badge/data-AAPL%20live-orange)](https://finance.yahoo.com/quote/AAPL)


# Oceňovanie európskych opcií: Black-Scholes vs Monte Carlo

**Autor:** Ian Spika
**Predmet:** Softvér na analýzu dat R

Projekt porovnáva analytickú Black-Scholesovu formulu s Monte Carlo
simuláciou na úlohe oceňovania európskej kúpnej opcie. Empiricky overuje
rýchlosť konvergencie odhadu $\mathcal{O}(1/\sqrt{n})$ a ukazuje použitie
Monte Carla na ázijskej opcii, kde analytické riešenie neexistuje.

🌐 **Online verzia:** _doplň URL po prvom deploy-i_

Link : https://spikovich.github.io/proj_R/

## Štruktúra

```
.
├── index.qmd              # úvodná stránka webu
├── report.qmd             # technická správa (HTML + PDF)
├── presentation.qmd       # prezentácia revealjs
├── dashboard.qmd          # Quarto dashboard
├── references.bib         # bibliografia
├── iso690-author-date-sk-sk.csl   # citačný štýl
├── _quarto.yml            # konfigurácia projektu
├── .github/workflows/     # auto-deploy na GitHub Pages
└── .gitignore
```

## Lokálny build

```bash
# 1. raz: doinstalovat zavislosti
rm -rf ~/R/x86_64-pc-linux-gnu-library/4.5/00LOCK-*
R -e 'install.packages(c("rmarkdown", "knitr"))'
quarto install tinytex

# 2. CSL subor (ak chyba)
wget https://raw.githubusercontent.com/citation-style-language/styles/master/iso690-author-date-sk-sk.csl

# 3. render celeho projektu
quarto render
```

Vygenerované HTML/PDF skončia v `_site/`.

Tento projekt je dostupný pod [MIT licenciou](LICENSE).
