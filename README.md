# Oceňovanie európskych opcií: Black-Scholes vs Monte Carlo

**Autor:** Ian Spika
**Predmet:** Softvér na analýzu údajov

Projekt porovnáva analytickú Black-Scholesovu formulu s Monte Carlo
simuláciou na úlohe oceňovania európskej kúpnej opcie. Empiricky overuje
rýchlosť konvergencie odhadu $\mathcal{O}(1/\sqrt{n})$ a ukazuje použitie
Monte Carla na ázijskej opcii, kde analytické riešenie neexistuje.

🌐 **Online verzia:** _doplň URL po prvom deploy-i_

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

## Publikácia

Push na `main` automaticky spustí GitHub Actions, ktorý vyrendruje
projekt a publikuje ho na GitHub Pages (vetva `gh-pages`).

```bash
git add .
git commit -m "update report"
git push
```

URL bude vo formáte `https://<username>.github.io/<repo-name>/`.
