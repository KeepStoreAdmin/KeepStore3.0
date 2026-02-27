Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Class _Default
    Inherits System.Web.UI.Page

    ' --- FindControl ricorsivo (VB2012-safe) ---
    Private Function FindCtrl(Of T As Control)(ByVal id As String) As T
        Return TryCast(FindCtrlRecursive(Me, id), T)
    End Function

    Private Function FindCtrlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing Then Return Nothing
        Dim c As Control = root.FindControl(id)
        If c IsNot Nothing Then Return c
        For Each child As Control In root.Controls
            Dim found As Control = FindCtrlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next
        Return Nothing
    End Function

    ' VB2012-safe helper: read integer session values with a default fallback.
    Private Function GetSessionInt(ByVal key As String, ByVal defaultValue As Integer) As Integer
        Try
            Dim raw As Object = Session(key)
            If raw Is Nothing Then Return defaultValue
            Dim n As Integer
            If Integer.TryParse(Convert.ToString(raw), n) Then
                If n > 0 Then Return n
            End If
        Catch
            ' swallow and use default
        End Try
        Return defaultValue
    End Function

    Dim IvaTipo As Integer
    Public cont As Integer = 0
    Dim valoreIva As Integer

    Enum SqlExecutionType
        nonQuerya
        scalar
    End Enum

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Me.Session("InOfferta") = 0

        Dim sdsNew As SqlDataSource = FindCtrl(Of SqlDataSource)("SdsNewArticoli")
        Dim sdsVetrina As SqlDataSource = FindCtrl(Of SqlDataSource)("SdsArticoliInVetrina")
        Dim sdsBest As SqlDataSource = FindCtrl(Of SqlDataSource)("sdsPiuAcquistati")

        If sdsNew Is Nothing OrElse sdsVetrina Is Nothing OrElse sdsBest Is Nothing Then
            ' Fail-safe: non bloccare la home se il controllo non è presente.
            Return
        End If

        Dim sqlString As String
        Dim sqlBaseTable As String
        Dim table1 As String
        Dim table2 As String

        ' NOTA SICUREZZA/BUGFIX:
        ' - Uso sempre lo stesso nome parametro @ivaUtente in tutte le espressioni (prima c'era @IvaUtente)
        Dim prezzoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.Prezzo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoIvato) AS PrezzoIvato"
        Dim prezzoPromoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.PrezzoPromo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato) AS PrezzoPromoIvato"
        Dim iva As String = "IF(@ivaUtente>0,@ivaUtente,iva.valore) AS iva"

        Dim vsuperarticoliFieldsAndIvaFromVsuperarticoli As String =
            "vsuperarticoli.id as Articoliid, vsuperarticoli.TCId, vsuperarticoli.Codice, vsuperarticoli.Ean, vsuperarticoli.Descrizione1, vsuperarticoli.Descrizione2, " &
            "vsuperarticoli.MarcheId, vsuperarticoli.Marche_img, vsuperarticoli.SettoriId, vsuperarticoli.CategorieId, vsuperarticoli.TipologieId, vsuperarticoli.GruppiId, vsuperarticoli.SottoGruppiId, " &
            "vsuperarticoli.iva as ivaId, vsuperarticoli.UmId, vsuperarticoli.ListinoUfficiale, vsuperarticoli.img1, vsuperarticoli.Prezzo, " &
            prezzoIvato & ", " &
            "vsuperarticoli.PrezzoPromo, " &
            prezzoPromoIvato & ", vsuperarticoli.InOfferta, vsuperarticoli.speditoGratis, " &
            iva & " " &
            "FROM vsuperarticoli LEFT OUTER JOIN iva ON iva.id = vsuperarticoli.iva"

        Dim tagliecoloriJoin As String =
            "AS finalTable LEFT OUTER JOIN articoli_tagliecolori ON finalTable.TCId = articoli_tagliecolori.id " &
            "LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id " &
            "LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        Dim id As String
        Dim vsuperarticoliId As String
        Dim TC As Integer = 0

        If Session("TC") IsNot Nothing Then Integer.TryParse(Session("TC").ToString(), TC)
        If TC = 1 Then
            id = "TCId"
            vsuperarticoliId = id
        Else
            id = "Articoliid"
            vsuperarticoliId = "id"
        End If

        ' -------------------------------
        ' Nuovi arrivi (SdsNewArticoli)
        ' -------------------------------
        sqlBaseTable = "(SELECT * FROM documenti WHERE tipoDocumentiid=11 OR tipoDocumentiid=22 ORDER BY id DESC LIMIT 20) AS documentibase"
        sqlBaseTable = "(SELECT articoliid, TCId FROM " & sqlBaseTable & " INNER JOIN documentirighe ON documentibase.id = documentirighe.DocumentiId GROUP BY " & id & " ORDER BY RAND()) AS articoliidTCIdTable"
        sqlBaseTable = "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli & " INNER JOIN " & sqlBaseTable & " ON articoliidTCIdTable." & id & " = vsuperarticoli." & vsuperarticoliId & " WHERE nlistino=@listino ORDER BY vsuperarticoli.PrezzoPromoIvato ASC) AS vsuperarticoliOrdered"
        table1 = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id

        If TC = 1 Then
            sqlBaseTable = "(SELECT * FROM articoli_tagliecolori ORDER BY id DESC LIMIT 20) As articolibase"
        Else
            sqlBaseTable = "(SELECT * FROM articoli ORDER BY id DESC LIMIT 20) As articolibase"
        End If

        table2 = "SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli & " INNER JOIN " & sqlBaseTable & " ON articolibase.id = vsuperarticoli." & vsuperarticoliId & " WHERE nlistino=@listino"
        sqlString = "SELECT * FROM (" & table1 & " UNION ALL " & table2 & ") AS united ORDER BY RAND() LIMIT " & (GetSessionInt("VetrinaArticoliUltimiArriviPuntoVendita", 2) * 3).ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        sdsNew.SelectCommand = sqlString
        sdsNew.SelectParameters.Clear()
        sdsNew.SelectParameters.Add("@listino", Session("listino"))
        sdsNew.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))

        ' -------------------------------
        ' Articoli in vetrina (SdsArticoliInVetrina)
        ' -------------------------------
        sqlBaseTable = "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
                       " INNER JOIN (SELECT articoli_listini.id FROM articoli_listini INNER JOIN articoli ON articoli_listini.`ArticoliId` = articoli.id " &
                       "WHERE articoli_listini.`NListino` = @listino AND articoli.vetrina = 1 ORDER BY id DESC LIMIT 50) AS vsuperarticoliids " &
                       "ON vsuperarticoliids.id = vsuperarticoli.`ArticoliListiniId` ORDER BY " & id & " DESC, PrezzoPromo ASC) AS vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id & " ORDER BY RAND() LIMIT " & (GetSessionInt("VetrinaArticoliImpatto", 2) * 3).ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        sdsVetrina.SelectCommand = sqlString
        sdsVetrina.SelectParameters.Clear()
        sdsVetrina.SelectParameters.Add("@listino", Session("listino"))
        sdsVetrina.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))

        ' -------------------------------
        ' Più venduti (sdsPiuAcquistati)
        ' -------------------------------
        sqlBaseTable = "(SELECT documentirighe.ArticoliId, documentirighe.TCId, COUNT(documentirighe.ArticoliId) AS Conteggio_Vendite, " &
                       "DATEDIFF(CURDATE(),documenti.DataDocumento) AS Giorni " &
                       "FROM documenti INNER JOIN documentirighe ON documentirighe.DocumentiId=documenti.id " &
                       "WHERE articoliid>0 AND DATEDIFF(CURDATE(),documenti.DataDocumento)<15 " &
                       "GROUP BY " & id & " ORDER BY conteggio_vendite DESC LIMIT 50) AS documentiTable"

        sqlBaseTable = "(SELECT Conteggio_Vendite, " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
                       " INNER JOIN " & sqlBaseTable &
                       " ON documentiTable." & id & "=vsuperarticoli." & vsuperarticoliId &
                       " WHERE NListino=@listino ORDER BY Conteggio_vendite DESC, PrezzoPromoIvato ASC) as vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id & " ORDER BY conteggio_vendite DESC LIMIT " & (GetSessionInt("VetrinaArticoliPiuVenduti", 2) * 4).ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        sdsBest.SelectCommand = sqlString
        sdsBest.SelectParameters.Clear()
        sdsBest.SelectParameters.Add("@listino", Session("listino"))
        sdsBest.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))
    End Sub
End Class
