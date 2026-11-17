Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Text.RegularExpressions

' KS-MYACCOUNT-1A. Regole PURE (nessun accesso a database o sessione) per l'avanzamento dell'ordine e per i numeri di tracking mostrati al cliente nel dettaglio ordine.
' Il passo dipende SOLO da documenti.StatiId: il gestionale salva il tracking senza cambiare lo stato, quindi un numero di tracking non prova che l'ordine sia stato spedito.
' Nessuna data di spedizione: documentipie.DataTrasporto e la data di creazione del documento, non quella della spedizione.
Public NotInheritable Class OrderProgress
    ' False = stato non riconosciuto: nessuna barra, resta il testo dello stato scritto nel database.
    Public Property Known As Boolean
    Public Property Cancelled As Boolean
    ' 0 = nessun passo (stato ignoto o ordine annullato); 1 Ricevuto, 2 In lavorazione, 3 Pronto, 4 Spedito o consegnato.
    Public Property StepNumber As Integer
End Class

Public NotInheritable Class TrackingToken
    Private ReadOnly _text As String
    Private ReadOnly _linkable As Boolean

    Public Sub New(ByVal text As String, ByVal linkable As Boolean)
        _text = text
        _linkable = linkable
    End Sub

    ' Testo da mostrare (da codificare per HTML dal chiamante).
    Public ReadOnly Property Text As String
        Get
            Return _text
        End Get
    End Property

    ' True solo per un codice di forma sicura: puo diventare un collegamento al corriere.
    Public ReadOnly Property Linkable As Boolean
        Get
            Return _linkable
        End Get
    End Property
End Class

Public Module KeepStoreOrderProgress
    Public Const MaxTrackingTokens As Integer = 10
    Public Const MaxTokenLength As Integer = 60
    Private Const Probe As String = "ksprobe0token0x"
    Private ReadOnly LinkablePattern As New Regex("^[A-Za-z0-9_-]{3,40}$", RegexOptions.CultureInvariant)
    Private ReadOnly SeparatorPattern As New Regex("[;,\s]+", RegexOptions.CultureInvariant)
    Private ReadOnly WhitespacePattern As New Regex("[\s\x00-\x1F\x7F]", RegexOptions.CultureInvariant)

    Public Function Resolve(ByVal statiId As Integer) As OrderProgress
        Dim p As New OrderProgress()
        Select Case statiId
            Case 1, 6
                p.Known = True
                p.StepNumber = 1
            Case 2
                p.Known = True
                p.StepNumber = 2
            Case 5
                p.Known = True
                p.StepNumber = 3
            Case 4
                p.Known = True
                p.StepNumber = 4
            Case 3
                p.Known = True
                p.Cancelled = True
            Case Else
                p.Known = False
        End Select
        Return p
    End Function

    ' Il gestionale separa i numeri con ";", ma i dati reali contengono anche "," e ", " e caratteri di controllo ai bordi: sono tutti separatori.
    Public Function ParseTracking(ByVal tracking As String) As List(Of TrackingToken)
        Dim result As New List(Of TrackingToken)()
        If tracking Is Nothing Then Return result
        Dim sb As New StringBuilder(tracking.Length)
        For Each ch As Char In tracking
            If Char.IsControl(ch) Then sb.Append(" "c) Else sb.Append(ch)
        Next
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each raw As String In SeparatorPattern.Split(sb.ToString())
            Dim token As String = raw.Trim()
            If token.Length = 0 Then Continue For
            If token.Length > MaxTokenLength Then
                token = token.Substring(0, MaxTokenLength)
            End If
            If seen.Contains(token) Then Continue For
            seen.Add(token)
            Dim linkable As Boolean = LinkablePattern.IsMatch(token)
            result.Add(New TrackingToken(token, linkable))
            If result.Count >= MaxTrackingTokens Then Exit For
        Next
        Return result
    End Function

    ' Collegamento al corriere: il modello (vettori.Link_Tracking) deve essere un URL assoluto http o https con "#ID#", senza userinfo e con "#ID#" mai nell'host; il codice e
    ' di forma sicura e si codifica come parte di URL. Ogni altro caso restituisce "" (si mostra solo il testo).
    Public Function BuildTrackingUrl(ByVal template As String, ByVal code As String) As String
        If template Is Nothing OrElse code Is Nothing Then Return ""
        If Not LinkablePattern.IsMatch(code) Then Return ""
        Dim t As String = template.Trim()
        If t.Length = 0 OrElse WhitespacePattern.IsMatch(t) Then Return ""
        If t.IndexOf("#ID#", StringComparison.Ordinal) < 0 Then Return ""
        Dim u As Uri = Nothing
        If Not Uri.TryCreate(t.Replace("#ID#", Probe), UriKind.Absolute, u) Then Return ""
        If u.Scheme <> Uri.UriSchemeHttp AndAlso u.Scheme <> Uri.UriSchemeHttps Then Return ""
        If Not String.IsNullOrEmpty(u.UserInfo) OrElse String.IsNullOrEmpty(u.Host) OrElse u.Host.IndexOf(Probe, StringComparison.OrdinalIgnoreCase) >= 0 Then Return ""
        Return t.Replace("#ID#", Uri.EscapeDataString(code))
    End Function
End Module
