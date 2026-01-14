# Proposta: feature flag / kill-switch “esplicita e sicura”

L’implementazione precedente era un “Application flag” opaco, senza auditing e con output JS.

## Obiettivo
- Nome chiaro (semantico), gestibile da admin
- Nessun output HTML/JS “inline”
- Logging obbligatorio (chi, cosa, quando, IP)
- Accesso solo admin + antiforgery/CSRF
- Persistenza su storage controllato (DB / config), non su chiavi misteriose in Application

## Pattern consigliato (VB.NET, WebForms)

1) Tabella DB `FeatureFlags` (esempio):
- `FlagName` (PK, nvarchar)
- `IsEnabled` (bit)
- `UpdatedAt` (datetime)
- `UpdatedBy` (nvarchar)
- `Notes` (nvarchar)

2) Helper centralizzato (App_Code o classe dedicata):

```vbnet
Imports System
Imports System.Data.SqlClient
Imports System.Web

Public Module FeatureFlags
    Public Function IsEnabled(flagName As String) As Boolean
        ' TODO: caching con scadenza breve + key esplicita
        Using cn As New SqlConnection(ConfigurationManager.ConnectionStrings("...").ConnectionString)
            cn.Open()
            Using cmd As New SqlCommand("SELECT IsEnabled FROM FeatureFlags WHERE FlagName=@n", cn)
                cmd.Parameters.Add("@n", SqlDbType.NVarChar, 128).Value = flagName
                Dim o = cmd.ExecuteScalar()
                If o Is Nothing OrElse o Is DBNull.Value Then Return False
                Return Convert.ToBoolean(o)
            End Using
        End Using
    End Function
End Module
```

3) Uso pagina (esempio):
- comportamento “kill-switch” = redirect o messaggio server-side (no `Response.Write("<script>")`)

```vbnet
If FeatureFlags.IsEnabled("KillSwitch.Articoli") Then
    ' Esempio: mostra un banner server-side o reindirizza
    Response.Redirect("~/maintenance.aspx", True)
End If
```

4) Admin UI:
- pagina accessibile solo a ruoli admin, con logging su DB (tabella `AuditLog`).
- POST protetto con antiforgery/CSRF.

Se vuoi, nel prossimo step posso produrre:
- la tabella FeatureFlags + AuditLog
- la pagina admin di gestione flags (UI minima)
- caching + invalidazione
- log strutturato con correlazione richiesta
