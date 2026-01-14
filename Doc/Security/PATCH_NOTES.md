# KeepStore – Security patch (legacy Application flag removal)

Data: 2026-01-14

## Cosa ho fatto
- Ricerca e rimozione del blocco legacy basato su:
  - `AS00728312T34`
  - `ASXXX00728312T`
- Rimossi anche eventuali `Response.Write("<script>alert('')</script>")` collegati allo stesso comportamento.
- File aggiornati:
  - `articolix.aspx.vb`
  - `rettificaMagazzino.aspx.vb`
  - `wishlist.aspx.vb`

Nota: in `articoli.aspx.vb` (branch `main` del repo) NON risultano presenti le chiavi, quindi il file è incluso ma non modificato.

## Come applicare
1. Sovrascrivi i 3 file nel repo con quelli presenti in questo pacchetto.
2. Commit + deploy.

## Verifica rapida (PowerShell)
```powershell
Select-String -Path .\*.vb,.\*.aspx.vb -Pattern "AS00728312T34|ASXXX00728312T" -SimpleMatch -Recurse
```

## Verifica rapida (Linux/macOS)
```bash
grep -RIn --include='*.vb' --include='*.aspx.vb' 'AS00728312T34\|ASXXX00728312T' .
```
