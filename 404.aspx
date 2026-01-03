<%@ Page Language="VB" AutoEventWireup="false" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>404</title>
    <meta name="robots" content="noindex,nofollow" />
</head>
<body>
<form id="form1" runat="server">
<div style="font-family: Arial; max-width: 900px; margin: 30px auto;">
    <h1>Pagina non trovata / Errore gestito</h1>
    <p>Se stai vedendo questa pagina in loop, ora dovrebbe essersi sbloccata.</p>

    <p><b>URL richiesto:</b> <%= Server.HtmlEncode(Request.Url.ToString()) %></p>

    <p>
        <a href="/diagnostic.aspx">Apri diagnostica (last_error.txt)</a>
    </p>

    <hr />

    <p style="color:#666; font-size: 12px;">
        Nota: in debug puoi forzare la visualizzazione dell'errore reale aprendo una pagina con <b>?debug=1</b>.
        Esempio: <b>/Default.aspx?debug=1</b>
    </p>
</div>
</form>
</body>
</html>