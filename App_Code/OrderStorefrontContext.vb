Option Strict On
Option Explicit On

Imports System
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class OrderStorefrontIdentity
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property PriceListId As Integer

    Public ReadOnly Property IsComplete As Boolean
        Get
            Return Not String.IsNullOrEmpty(DatabaseScopeKey) AndAlso
                   CompanyId > 0 AndAlso LoginId > 0 AndAlso
                   UtentiId > 0 AndAlso PriceListId > 0
        End Get
    End Property
End Class

Public NotInheritable Class OrderStorefrontContext
    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal context As HttpContext) As OrderStorefrontIdentity
        Dim owner As CartStorefrontOwnerScope = CartStorefrontOwnerContext.Resolve(context)
        If owner Is Nothing OrElse Not owner.IsAuthenticated OrElse
           owner.CompanyId <= 0 OrElse owner.LoginId <= 0 OrElse
           owner.Listino <= 0 OrElse String.IsNullOrEmpty(owner.DatabaseScopeKey) Then
            Return Nothing
        End If

        Dim utentiId As Long = SessionLong(context, "UtentiId", SessionLong(context, "UtentiID", 0L))
        Return New OrderStorefrontIdentity() With {
            .DatabaseScopeKey = owner.DatabaseScopeKey,
            .CompanyId = owner.CompanyId,
            .LoginId = owner.LoginId,
            .UtentiId = utentiId,
            .PriceListId = owner.Listino
        }
    End Function

    Public Shared Function VerifyAccount(ByVal connection As MySqlConnection,
                                         ByVal transaction As MySqlTransaction,
                                         ByVal identity As OrderStorefrontIdentity) As Boolean
        If connection Is Nothing OrElse identity Is Nothing OrElse
           String.IsNullOrEmpty(identity.DatabaseScopeKey) OrElse
           identity.CompanyId <= 0 OrElse identity.LoginId <= 0 Then Return False

        Const sql As String =
            "SELECT DISTINCT utentiid, COALESCE(listino,0) AS listino " &
            "FROM vlogin WHERE id=?loginId AND AziendeID=?aziendaId LIMIT 2"
        Using command As New MySqlCommand(sql, connection, transaction)
            command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = identity.LoginId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = identity.CompanyId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return False
                Dim persistedUtentiId As Long = Convert.ToInt64(reader("utentiid"), CultureInfo.InvariantCulture)
                Dim persistedListino As Integer = Convert.ToInt32(reader("listino"), CultureInfo.InvariantCulture)
                If reader.Read() OrElse persistedUtentiId <= 0 OrElse persistedListino <= 0 Then Return False
                If identity.UtentiId > 0 AndAlso identity.UtentiId <> persistedUtentiId Then Return False
                If identity.PriceListId > 0 AndAlso identity.PriceListId <> persistedListino Then Return False
                identity.UtentiId = persistedUtentiId
                identity.PriceListId = persistedListino
            End Using
        End Using
        Return identity.IsComplete
    End Function

    Public Shared Function BuildCheckoutFingerprint(ByVal identity As OrderStorefrontIdentity,
                                                    ByVal tipoDocumentiId As Integer,
                                                    ByVal optionsFingerprint As String,
                                                    ByVal cartFingerprint As String) As String
        If identity Is Nothing OrElse Not identity.IsComplete OrElse tipoDocumentiId <= 0 Then Return String.Empty
        Return OrderDurableIdempotencyService.ComputePayloadFingerprint(
            "checkout-v3", identity.DatabaseScopeKey, identity.CompanyId,
            identity.LoginId, identity.UtentiId, identity.PriceListId,
            tipoDocumentiId, optionsFingerprint, cartFingerprint)
    End Function

    Public Shared Function CanAccessDocument(ByVal identity As OrderStorefrontIdentity,
                                             ByVal documentCompanyId As Integer,
                                             ByVal documentUtentiId As Long) As Boolean
        Return identity IsNot Nothing AndAlso identity.IsComplete AndAlso
               documentCompanyId = identity.CompanyId AndAlso
               documentUtentiId = identity.UtentiId
    End Function

    Private Shared Function SessionLong(ByVal context As HttpContext,
                                        ByVal key As String,
                                        ByVal fallback As Long) As Long
        Dim parsed As Long
        If context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso
           Long.TryParse(Convert.ToString(context.Session(key)), NumberStyles.Integer,
                         CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
    End Function
End Class
