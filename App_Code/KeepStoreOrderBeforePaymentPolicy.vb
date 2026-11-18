Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports MySql.Data.MySqlClient

' PAYMENT-PAY-FIRST-BY-FLAG-1A: il campo pagamentitipo.ConfermaOrdinePrimaPagamento decide, per metodo, se l'ordine puo nascere prima del pagamento
' (1, come sempre) oppure solo dopo (0). Il sito sa pagare prima soltanto con PayPal (PayPalPayFirstPolicy, stessa regola): per ogni altro metodo con
' flag 0 l'ordine NON viene creato e il cliente sceglie un altro metodo. Preventivi e coupon restano sul flusso di sempre.
' Il modulo non usa sessione, contesto web ne configurazione: decisione e confronto sono funzioni pure, il lettore riceve la connessione.

Public Enum OrderBeforePaymentDecision
    OrderFirst = 1
    PayFirstPayPal = 2
    NotSupported = 3
End Enum

Public Enum PaymentPolicyGateOutcome
    Allowed = 1
    Unreadable = 2
    Changed = 3
    NotAllowed = 4
End Enum

Public NotInheritable Class PaymentPolicySnapshot
    Public Property OnLine As Integer
    Public Property ConfirmBeforePayment As Integer
    Public Property AllowLaterPayment As Integer
    Public Property SendEmailBeforePayment As Integer
End Class

Public NotInheritable Class KeepStoreOrderBeforePaymentPolicy
    Private Sub New()
    End Sub

    Public Const PayPalOnlineValue As Integer = 2
    Public Const QuoteDocumentType As Integer = 2

    ' Una riga esatta per id E azienda, sulla tabella (la vista dei metodi non espone il flag). MAX rende numerico anche un eventuale tinyint(1).
    Public Const ReadSql As String =
        "SELECT COUNT(*) AS Righe, MAX(COALESCE(OnLine,0)) AS OnLine, MAX(COALESCE(ConfermaOrdinePrimaPagamento,1)) AS Conferma, " &
        "MAX(COALESCE(PermettiPagamentoSuccessivo,1)) AS Successivo, MAX(COALESCE(InviaEmailOrdinePrimaPagamento,1)) AS Email " &
        "FROM pagamentitipo WHERE id=?id AND AziendeID=?aziendaId"

    Public Shared Function Decide(ByVal paymentOnline As Integer, ByVal confirmBeforePayment As Integer, ByVal documentType As Integer, ByVal hasCoupon As Boolean) As OrderBeforePaymentDecision
        If documentType <= 0 OrElse documentType = QuoteDocumentType OrElse hasCoupon Then Return OrderBeforePaymentDecision.OrderFirst
        If confirmBeforePayment <> 0 Then Return OrderBeforePaymentDecision.OrderFirst
        If paymentOnline = PayPalOnlineValue Then Return OrderBeforePaymentDecision.PayFirstPayPal
        Return OrderBeforePaymentDecision.NotSupported
    End Function

    ' Controllo di una creazione NUOVA senza tentativo PayPal autorizzato: la lettura autorevole deve riuscire, coincidere con la bozza sigillata
    ' (altrimenti serve una nuova conferma) e permettere l'ordine prima del pagamento. Un PayPal con flag 0 senza tentativo non crea ordini: nuova conferma.
    Public Shared Function Evaluate(ByVal readOk As Boolean, ByVal snapshot As PaymentPolicySnapshot, ByVal draftPaymentOnline As Integer,
                                    ByVal draftConfirmBeforePayment As Integer, ByVal documentType As Integer, ByVal hasCoupon As Boolean) As PaymentPolicyGateOutcome
        If Not readOk OrElse snapshot Is Nothing Then Return PaymentPolicyGateOutcome.Unreadable
        If snapshot.OnLine <> draftPaymentOnline OrElse snapshot.ConfirmBeforePayment <> draftConfirmBeforePayment Then
            Return PaymentPolicyGateOutcome.Changed
        End If
        Select Case Decide(snapshot.OnLine, snapshot.ConfirmBeforePayment, documentType, hasCoupon)
            Case OrderBeforePaymentDecision.OrderFirst
                Return PaymentPolicyGateOutcome.Allowed
            Case OrderBeforePaymentDecision.PayFirstPayPal
                Return PaymentPolicyGateOutcome.Changed
            Case Else
                Return PaymentPolicyGateOutcome.NotAllowed
        End Select
    End Function

    ' True solo con una riga esatta del metodo per quell'azienda. Ogni errore = False e snapshot Nothing: chi chiama rifiuta, non assume valori.
    Public Shared Function TryRead(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal companyId As Integer,
                                   ByVal paymentId As Integer, ByRef snapshot As PaymentPolicySnapshot) As Boolean
        snapshot = Nothing
        If connection Is Nothing OrElse companyId <= 0 OrElse paymentId <= 0 Then Return False
        Try
            Using command As New MySqlCommand(ReadSql, connection, transaction)
                command.Parameters.Add("?id", MySqlDbType.Int32).Value = paymentId
                command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
                Using reader As MySqlDataReader = command.ExecuteReader()
                    If Not reader.Read() Then Return False
                    If Convert.ToInt64(reader("Righe"), CultureInfo.InvariantCulture) <> 1L Then Return False
                    Dim found As New PaymentPolicySnapshot()
                    found.OnLine = Convert.ToInt32(reader("OnLine"), CultureInfo.InvariantCulture)
                    found.ConfirmBeforePayment = Convert.ToInt32(reader("Conferma"), CultureInfo.InvariantCulture)
                    found.AllowLaterPayment = Convert.ToInt32(reader("Successivo"), CultureInfo.InvariantCulture)
                    found.SendEmailBeforePayment = Convert.ToInt32(reader("Email"), CultureInfo.InvariantCulture)
                    snapshot = found
                    Return True
                End Using
            End Using
        Catch
            snapshot = Nothing
            Return False
        End Try
    End Function
End Class
