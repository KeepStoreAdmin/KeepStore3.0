# Loghi dei pagamenti: provenienza e regole d'uso

Cartella dei file: `Public/assets/images/pagamenti/`. Richiesta del PO del 2026-11-19: «fai un check online e trovami i nuovi loghi e li mettiamo nella cartella e li pubblichiamo online»; il 2026-11-19 il PO ha autorizzato lo scaricamento di Mastercard, Maestro e PayPal dai siti ufficiali accettando le loro condizioni d'uso («Si, scarica»).

**Stato:** i file ufficiali sono nella cartella ma **nessuna pagina li mostra ancora**. Farli comparire nel sito e il task `PAYMENT-LOGOS-1A` (Roadmap), con la regola: un logo si mostra solo se quel metodo e davvero attivo per l'azienda dell'host.

## File ufficiali scaricati il 2026-11-19 (copiati senza alcuna modifica)

| File nella cartella | Marchio | File originale | Fonte ufficiale | Condizioni |
| --- | --- | --- | --- | --- |
| `mastercard.svg` | Mastercard, Simbolo (due cerchi, senza scritta) | `ma_symbol.svg` nell'archivio `mc_symbol_SVG.zip` | Centro del marchio Mastercard, pagina «Download Artwork» (`mastercard.com/brandcenter`) | Accettato il «Download Artwork Agreement» della pagina |
| `maestro.svg` | Maestro, marchio verticale per sfondi chiari | `ms_vrt_pos.svg` nell'archivio `ms_white_light_bkgs_SVG.zip` | Stessa pagina Mastercard | Stesso accordo |
| `paypal-logo-2024.png` | PayPal, scritta nera (logo 2024) | `PayPal-Logo-Black-RGB.png` nell'archivio `PayPal-Logo-Black-2024.zip` | Area stampa ufficiale PayPal, «Media Resources» (`newsroom.paypal-corp.com`) | Materiale dell'area stampa; la pagina per i negozianti non e piu raggiungibile |
| `paypal-monogram-2024.png` | PayPal, monogramma a colori (2024) | `PayPal-Monogram-FullColor-RGB.png` nell'archivio `PayPal-Monogram-Logo-2024.zip` | Stessa area stampa PayPal | Come sopra |

Controlli fatti prima di copiarli: archivi estratti in una cartella isolata; i due SVG non contengono script, collegamenti esterni ne contenuto attivo; ogni file copiato e identico all'originale (impronta SHA-256 confrontata).

## File precedenti (gia nel repository, non ufficiali verificati)
`visa.svg`, `master.svg`, `paypal.svg`, `discover.svg`: presenti da prima, provenienza non documentata. `master.svg` e `paypal.svg` sono superati dai file nuovi; non vanno usati nelle pagine nuove. `discover.svg` non corrisponde a un metodo attivo.

## Regole d'uso (dai siti dei marchi)
- **Mai modificare** colori, proporzioni o forma; non aggiungere effetti, ombre o cornici. Si puo solo ridimensionare mantenendo le proporzioni.
- **Spazio libero** attorno a ogni marchio (Mastercard: almeno un quarto della larghezza di un cerchio).
- **Parita:** tutti i marchi dei pagamenti con la stessa evidenza (stessa altezza visiva, stessa riga, stessa frequenza); nessuno piu piccolo degli altri.
- **Solo se attivo:** un marchio si mostra soltanto se il metodo e davvero accettato dal negozio.
- **Sfondo:** `mastercard.svg` e `maestro.svg` sono le versioni per sfondi chiari; `paypal-logo-2024.png` e la scritta nera per sfondi chiari.

## Che cosa manca (richiede un passaggio del PO)
- **Visa:** il sito ufficiale (`globalclient.visa.com/brand-mark`) chiede un modulo con nome, azienda, e-mail aziendale e l'accettazione dei termini: lo compila il titolare. Logo attuale: scritta in blu pieno; la vecchia «bandierina» non va piu usata.
- **PagoBANCOMAT / BANCOMAT Pay, PostePay:** nessuna pagina pubblica di download; i file si chiedono alla banca o ad Axerve.
- **American Express, Apple Pay, Google Pay, Satispay, Klarna, Scalapay:** pagine ufficiali disponibili, ma i marchi vanno mostrati solo con il metodo attivo (contratto in essere).
- **Circuiti del contratto Banca Sella per il sito:** da leggere sul contratto o nel pannello della banca (di solito Visa, Mastercard, Maestro; altri su richiesta).
