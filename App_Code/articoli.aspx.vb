' ============================================================================
' HOTFIX (KeepStore) - 2026-01-21
'
' IMPORTANTE:
' Questo file NON deve stare in App_Code.
' Una patch precedente lo aveva inserito per errore e causava errori di
' compilazione (controlli CheckBox/GridView ecc. "non dichiarati").
'
' Soluzione consigliata: elimina fisicamente questi file:
'   - App_Code\articoli.aspx
'   - App_Code\articoli.aspx.vb
'
' Se non vuoi / non riesci ad eliminarli, lascia questo file così (vuoto):
' non compila alcuna classe e quindi non genera errori.
'
' La pagina corretta è in ROOT:
'   - /articoli.aspx
'   - /articoli.aspx.vb
' ============================================================================
