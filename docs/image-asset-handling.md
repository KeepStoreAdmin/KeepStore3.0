# Image Asset Handling

## Percorsi asset

- `Public/assets/images/`: percorso base per asset immagine pubblici.
- `Public/assets/images/articoli/`: percorso operativo per immagini articoli/prodotti.

## Regola immagini prodotto

Le immagini prodotto in `Public/assets/images/articoli/` sono asset operativi non versionati nel repository applicativo.

Sono gestite tramite filesystem, server o processo di deploy operativo. Non devono essere committate in massa nel repository, per evitare di appesantire la history Git e contaminare branch o pull request applicative.

## Verifica immagini mancanti

Quando una ProductCard o una pagina prodotto mostra un'immagine mancante:

1. Controllare l'URL pubblico dell'immagine.
2. Controllare che il file fisico esista in `Public/assets/images/articoli/`.
3. Controllare il campo prodotto `Img1` o il campo immagine equivalente.
4. Se il file manca, caricare l'asset con il nome esatto atteso oppure correggere il dato prodotto verso un file esistente o verso fallback previsto.

## Regole Git

- Non eseguire `git add Public/assets/images/articoli/`.
- Se le immagini prodotto appaiono come `untracked`, non e' automaticamente un problema.
- Prima di qualunque commit verificare sempre `git diff --stat`.
- Prima di qualunque commit verificare sempre `git status --short`.
- Se compare un commit con migliaia di file `.jpg`, fermarsi e diagnosticare prima di pushare.

## Procedura safe

- Non usare `git add .` in questo repository quando sono presenti asset immagine non tracciati.
- Aggiungere allo stage solo file espliciti e attesi.
- Verificare i file staged prima del commit.
- Verificare che la PR non includa asset immagini non richiesti.

## Nota futura

Valutare in un task separato una regola `.gitignore` o una strategia asset dedicata. Questo documento non modifica `.gitignore` e non cambia il processo di deploy degli asset.
