Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration

Partial Class articolix
    Inherits System.Web.UI.Page

    '==========================================================
    ' PAGE LOAD
    '==========================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Memorizzo l’ultima pagina articoli visitata
        Session.Item("Pagina_visitata_Articoli") = Me.Request.Url.ToString()

        ' Pagina di provenienza per il carrello (logica storica)
        Session.Item("Carrello_Pagina") = "articoli.aspx"

        ' Flag applicativo legacy (non lo tocco, ma lo proteggo con un Try)
        Try
            If Application.Item("AS00728312T34") IsNot Nothing AndAlso
               CInt(Application.Item("AS00728312T34")) = 1 Then

                Application.Set("ASXXX00728312T", CInt(Application.Item("AS00728312T34")) - 1)
                Application.Set("AS00728312T34", 0)
                Response.Write("<script>alert('')</script>")
            End If
        Catch
            ' Non blocchiamo la pagina per queste porcherie legacy
        End Try

        ' Sempre: imposto la SelectCommand della SqlDataSource
        CaricaArticoli()

        ' Solo al primo load: registro la stringa di ricerca (se presente)
        If Not IsPostBack Then
            RegistraQueryRicerca()
        End If
    End Sub

    '==========================================================
    ' CARICAMENTO ARTICOLI
    ' Usa la query in Session("Stringa_articoli") se presente,
    ' altrimenti lascia il SelectCommand di default dell'ASPX
    '==========================================================
    Private Sub CaricaArticoli()
        Dim sql As String = Nothing

        If Session("Stringa_articoli") IsNot Nothing Then
            sql = Session("Stringa_articoli").ToString()
        End If

        If Not String.IsNullOrWhiteSpace(sql) Then
            sdsArticoli.SelectCommand = sql
        End If
    End Sub

    '==========================================================
    ' LOG QUERY DI RICERCA
    ' Scrive in query_string la Session("q"), in modo sicuro
    '==========================================================
    Private Sub RegistraQueryRicerca()
        Dim strCerca As String = TryCast(Session("q"), String)

        ' Niente ricerca = niente log
        If String.IsNullOrWhiteSpace(strCerca) Then
            Exit Sub
        End If

        ' Tolgo eventuale HTML
        Dim testo As String = Server.HtmlDecode(strCerca).Trim()

        ' Filtra parole palesemente sporche / con tag HTML
        ' (mantengo la logica originale ma corretta: PRIMA era un OR insensato)
        If testo.Contains("&") OrElse testo.Contains(";") Then
            Exit Sub
        End If

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Try
            Using conn As New MySqlConnection(connString)
                conn.Open()

                Using cmd As New MySqlCommand("INSERT INTO query_string (QString) VALUES (@QString)", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("@QString", testo)
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch
            ' Se il log fallisce non me ne frega niente, la pagina deve comunque funzionare
        End Try
    End Sub

    '==========================================================
    ' PAGINAZIONE GRIDVIEW
    '==========================================================
    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Articoli_PageIndex") = Me.GridView1.PageIndex
    End Sub

    '==========================================================
    ' EVENTI "VUOTI" LEGACY (wishlist / carrello / multiplo)
    ' Mantengo gli handler perché l’ASPX li richiama,
    ' ma non faccio nessuna logica reale su questa pagina.
    '==========================================================

    ' Aggiungi a wishlist
    Protected Sub BT_Aggiungi_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        ' Pagina legacy: qui potresti copiare, se vuoi, la logica della wishlist di articoli.aspx.vb
    End Sub

    ' Aggiungi al carrello (bottone singolo)
    Protected Sub ImageButton1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        ' Pagina legacy: nessun inserimento diretto nel carrello.
        ' Se un domani ti serve, copia qui il codice di ImageButton1_Click da articoli.aspx.vb
    End Sub

    ' Aggiungi multiplo al carrello (footer selezione multipla)
    Protected Sub Selezione_Multipla_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        ' Pagina legacy: selezione multipla non implementata.
        ' Idem: se vuoi la stessa funzione di articoli.aspx, la puoi incollare qui.
    End Sub


    '------------------------------------------------------------
    ' Helpers per binding markup (legacy)
    '------------------------------------------------------------
    Protected Function checkImg(ByVal value As Object) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then
            'fallback: lascia vuoto (o sostituisci con un placeholder se presente)
            Return String.Empty
        End If

        s = s.Trim()

        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        If s.StartsWith("/") Then
            Return s
        End If

        'Percorso legacy più comune
        Return ResolveUrl("~/public/immagini/" & s.TrimStart("/"c))
    End Function

    Protected Function sotto_stringa(ByVal value As Object) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrEmpty(s) Then Return String.Empty

        'rimuove HTML base
        s = System.Text.RegularExpressions.Regex.Replace(s, "<.*?>", String.Empty)

        'taglio descrizione
        If s.Length > 160 Then
            s = s.Substring(0, 160) & "..."
        End If

        Return s
    End Function

End Class
