@{
Mutants = @(
    @{ Name='M01-applies-flag'; File='PayPalPayFirst.vb'; Find='confirmBeforePayment = 0 AndAlso'; Replace='confirmBeforePayment = 1 AndAlso'; ExpectedKill=@('P01') }
    @{ Name='M02-applies-quote'; File='PayPalPayFirst.vb'; Find='documentType <> QuoteDocumentType AndAlso'; Replace='True AndAlso'; ExpectedKill=@('P04') }
    @{ Name='M03-applies-coupon'; File='PayPalPayFirst.vb'; Find='documentType <> QuoteDocumentType AndAlso Not hasCoupon'; Replace='documentType <> QuoteDocumentType'; ExpectedKill=@('P05') }
    @{ Name='M04-applies-online'; File='PayPalPayFirst.vb'; Find='Return paymentOnline = PayPalOnlineValue AndAlso '; Replace='Return '; ExpectedKill=@('P03') }
    @{ Name='M05-coupon-article'; File='PayPalPayFirst.vb'; Find=' OrElse couponArticleId > 0'; Replace=''; ExpectedKill=@('P08') }
    @{ Name='M06-coupon-code'; File='PayPalPayFirst.vb'; Find='Return Not String.IsNullOrEmpty(Convert.ToString(couponControlCode)) OrElse'; Replace='Return False OrElse'; ExpectedKill=@('P07') }
    @{ Name='M07-route-authorized'; File='PayPalPayFirst.vb'; Find='Return PayFirstRoute.CreateOrder'; Replace='Return PayFirstRoute.Finish'; ExpectedKill=@('P11') }
    @{ Name='M08-route-doc'; File='PayPalPayFirst.vb'; Find='Return PayFirstRoute.Finish'; Replace='Return PayFirstRoute.StartPayment'; ExpectedKill=@('P12') }
    @{ Name='M09-route-voiding'; File='PayPalPayFirst.vb'; Find='Return PayFirstRoute.Busy'; Replace='Return PayFirstRoute.StartPayment'; ExpectedKill=@('P13') }
    @{ Name='M10-route-orphan'; File='PayPalPayFirst.vb'; Find='Return PayFirstRoute.Manual'; Replace='Return PayFirstRoute.StartPayment'; ExpectedKill=@('P13') }
    @{ Name='M11-route-unknown'; File='PayPalPayFirst.vb'; Find='If previous = PayPalPaymentAttemptStates.DocCommitted OrElse previous = PayPalPaymentAttemptStates.Capturing Then'; Replace='If False Then'; ExpectedKill=@('P14') }
    @{ Name='M12-context-login'; File='PayPalPayFirst.vb'; Find='found.LoginId <> loginId OrElse '; Replace=''; ExpectedKill=@('X03') }
    @{ Name='M13-context-expiry'; File='PayPalPayFirst.vb'; Find=' OrElse found.DraftExpiresUtc <= nowUtc'; Replace=''; ExpectedKill=@('X06') }
    @{ Name='M14-context-scope'; File='PayPalPayFirst.vb'; Find='Not String.Equals(found.DatabaseScopeKey, databaseScopeKey, StringComparison.Ordinal) OrElse '; Replace=''; ExpectedKill=@('X05') }
    @{ Name='M15-context-single-key'; File='PayPalPayFirst.vb'; Find='Return SessionPrefix & normalized'; Replace='Return SessionPrefix'; ExpectedKill=@('X01', 'X02') }
    @{ Name='M16-context-remove-all'; File='PayPalPayFirst.vb'; Find='If key.Length > 0 Then session.Remove(key)'; Replace='If key.Length > 0 Then session.Remove(SessionPrefix)'; ExpectedKill=@('X08') }
    @{ Name='M17-context-amount'; File='PayPalPayFirst.vb'; Find='context.Amount <= 0D OrElse '; Replace=''; ExpectedKill=@('X07') }
    @{ Name='M18-start-no-time-check'; File='PayPalPayFirst.vb'; Find='AndAlso Not hasTime Then Return Result(PayFirstOutcome.BackToCart, "DRAFT_EXPIRING"'; Replace='AndAlso False Then Return Result(PayFirstOutcome.BackToCart, "DRAFT_EXPIRING"'; ExpectedKill=@('S08') }
    @{ Name='M19-start-time-threshold'; File='PayPalPayFirst.vb'; Find='>= TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToStart)'; Replace='>= TimeSpan.FromMinutes(0)'; ExpectedKill=@('S08') }
    @{ Name='M20-start-orphan'; File='PayPalPayFirst.vb'; Find='= PayFirstRoute.Manual Then Return Result'; Replace='= PayFirstRoute.Manual AndAlso False Then Return Result'; ExpectedKill=@('S15') }
    @{ Name='M21-create-request-id'; File='PayPalPayFirst.vb'; Find='attempt.CreateRequestId,'; Replace='Guid.NewGuid().ToString("N"),'; ExpectedKill=@('S03', 'S07') }
    @{ Name='M22-create-uncertain'; File='PayPalPayFirst.vb'; Find='If PayPalOrdersV2Client.IsOutcomeUncertain(response) Then'; Replace='If False Then'; ExpectedKill=@('S06') }
    @{ Name='M23-create-not-recorded'; File='PayPalPayFirst.vb'; Find='If Not PayPalPaymentAttempts.RecordOrderCreated('; Replace='If False AndAlso Not PayPalPaymentAttempts.RecordOrderCreated('; ExpectedKill=@('V03', 'S02') }
    @{ Name='M24-always-create'; File='PayPalPayFirst.vb'; Find='If attempt.Stato = PayPalPaymentAttemptStates.Creating Then Return CreateRemote('; Replace='If True Then Return CreateRemote('; ExpectedKill=@('S05') }
    @{ Name='M25-blocked-created'; File='PayPalPayFirst.vb'; Find='If PayPalPaymentAttempts.RecordFailed(old.Id, old.AziendeId, "DRAFT_CHANGED") Then Return Nothing'; Replace='If True Then Return Nothing'; ExpectedKill=@('S11') }
    @{ Name='M26-blocked-authorized-no-void'; File='PayPalPayFirst.vb'; Find='If VoidAuthorized(old, cfg, client) Then Return Nothing'; Replace='If True Then Return Nothing'; ExpectedKill=@('S12') }
    @{ Name='M27-void-generic'; File='PayPalPayFirst.vb'; Find='PayPalPaymentAttempts.RecordVoidingUnbound(attempt.Id, attempt.AziendeId, "SUPERSEDED")'; Replace='PayPalPaymentAttempts.RecordVoiding(attempt.Id, attempt.AziendeId, "SUPERSEDED")'; ExpectedKill=@('S20') }
    @{ Name='M28-void-not-recorded'; File='PayPalPayFirst.vb'; Find='Return PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId)'; Replace='Return True'; ExpectedKill=@('S12') }
    @{ Name='M29-authorization-id'; File='PayPalPayFirst.vb'; Find='authorization.Id, expires)'; Replace='"KSWRONGAUTHID", expires)'; ExpectedKill=@('Z02', 'R03') }
    @{ Name='M30-skip-authorize'; File='PayPalPayFirst.vb'; Find='If String.Equals(order.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then'; Replace='If False Then'; ExpectedKill=@('Z02', 'R01') }
    @{ Name='M31-always-authorize'; File='PayPalPayFirst.vb'; Find='If String.Equals(order.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then'; Replace='If True Then'; ExpectedKill=@('R06') }
    @{ Name='M32-authorize-request-id'; File='PayPalPayFirst.vb'; Find='client.AuthorizeOrder(attempt.PayPalOrderId, attempt.AuthorizeRequestId)'; Replace='client.AuthorizeOrder(attempt.PayPalOrderId, Guid.NewGuid().ToString("N"))'; ExpectedKill=@('R02') }
    @{ Name='M33-cancel'; File='PayPalPayFirst.vb'; Find='If isCancel Then Return Result(PayFirstOutcome.BackToCart, "CUSTOMER_CANCELED"'; Replace='If False Then Return Result(PayFirstOutcome.BackToCart, "CUSTOMER_CANCELED"'; ExpectedKill=@('R07') }
    @{ Name='M34-return-token'; File='PayPalPayFirst.vb'; Find='OrElse Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawToken, attempt.PayPalOrderId) Then'; Replace='Then'; ExpectedKill=@('R08') }
    @{ Name='M35-no-context'; File='PayPalPayFirst.vb'; Find='If ctx Is Nothing OrElse ctx.DraftExpiresUtc.AddMinutes(-PayPalPayFirstPolicy.ReserveMinutes) - nowUtc < TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToAuthorize) Then'; Replace='If False Then'; ExpectedKill=@('R09') }
    @{ Name='M36-authorize-threshold'; File='PayPalPayFirst.vb'; Find='< TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToAuthorize) Then'; Replace='< TimeSpan.FromMinutes(0) Then'; ExpectedKill=@('R10') }
    @{ Name='M37-authorize-uncertain'; File='PayPalPayFirst.vb'; Find='If Not PayPalOrdersV2Client.IsOutcomeUncertain(authorized) Then'; Replace='If True Then'; ExpectedKill=@('R11') }
    @{ Name='M38-authorize-refused'; File='PayPalPayFirst.vb'; Find='PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "AUTHORIZE_REFUSED")'; Replace='Dim unusedRefused As Boolean = False'; ExpectedKill=@('R12') }
    @{ Name='M39-not-approved'; File='PayPalPayFirst.vb'; Find='If PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot).Length = 0 AndAlso'; Replace='If False AndAlso'; Occurrence=2; ExpectedKill=@('R17') }
    @{ Name='M40-orphan-void'; File='PayPalPayFirst.vb'; Find='client.VoidAuthorization(authorization.Id, attempt.VoidRequestId)'; Replace='Dim unusedOrphan As Boolean = False'; ExpectedKill=@('R15') }
    @{ Name='M41-resume-approved'; File='PayPalPayFirst.vb'; Find='Return Result(PayFirstOutcome.ReturnRedirect, "RESUME_APPROVED"'; Replace='Return Result(PayFirstOutcome.ApprovalRedirect, "RESUME_APPROVED"'; ExpectedKill=@('S16') }
    @{ Name='M42-resume-invalid'; File='PayPalPayFirst.vb'; Find='PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "RESUME_ORDER_STATE")'; Replace='Dim unusedResume As Boolean = False'; ExpectedKill=@('S17') }
    @{ Name='M43-latest-login'; File='PayPalPaymentAttempts.vb'; Find='WHERE AziendeId=@az AND LoginId=@login AND DraftRequestId=@draft ORDER BY TentativoNo DESC'; Replace='WHERE AziendeId=@az AND DraftRequestId=@draft ORDER BY TentativoNo DESC'; ExpectedKill=@('V02') }
    @{ Name='M44-latest-order'; File='PayPalPaymentAttempts.vb'; Find='ORDER BY TentativoNo DESC LIMIT 1"'; Replace='ORDER BY TentativoNo ASC LIMIT 1"'; ExpectedKill=@('S10') }
    @{ Name='M45-void-unbound-doc'; File='PayPalPaymentAttempts.vb'; Find='New String() {PayPalPaymentAttemptStates.Authorized}, reason, String.Empty, Nothing, "RecordVoidingUnbound")'; Replace='New String() {PayPalPaymentAttemptStates.Authorized, PayPalPaymentAttemptStates.DocCommitted}, reason, String.Empty, Nothing, "RecordVoidingUnbound")'; ExpectedKill=@('V04') }
    @{ Name='M46-latest-company'; File='PayPalPaymentAttempts.vb'; Find='WHERE AziendeId=@az AND LoginId=@login AND DraftRequestId=@draft ORDER BY TentativoNo DESC'; Replace='WHERE LoginId=@login AND DraftRequestId=@draft ORDER BY TentativoNo DESC'; ExpectedKill=@('V02') }
    @{ Name='M47-proceed-authorized'; File='PayPalPayFirst.vb'; Find='Return Result(PayFirstOutcome.ProceedToOrder, "AUTHORIZED", attemptKey:=attempt.AttemptKey)'; Replace='Return Result(PayFirstOutcome.Finish, "AUTHORIZED", attemptKey:=attempt.AttemptKey)'; ExpectedKill=@('S13') }
    @{ Name='M48-authorized-no-context'; File='PayPalPayFirst.vb'; Find='If ctx Is Nothing Then Return Result(PayFirstOutcome.BackToCart, "AUTHORIZED_NO_CONTEXT"'; Replace='If False Then Return Result(PayFirstOutcome.BackToCart, "AUTHORIZED_NO_CONTEXT"'; ExpectedKill=@('R19') }
    @{ Name='M49-config-match'; File='PayPalPayFirst.vb'; Find='cfg.IsConfigured AndAlso cfg.AziendeId = aziendeId AndAlso cfg.PagamentiTipoId = pagamentiTipoId'; Replace='cfg.IsConfigured'; ExpectedKill=@('S19') }
    @{ Name='M50-return-ctx-expiry'; File='PayPalPayFirst.vb'; Find='ctx.DraftExpiresUtc.AddMinutes(-PayPalPayFirstPolicy.ReserveMinutes) - nowUtc < TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToAuthorize)'; Replace='ctx.DraftExpiresUtc - nowUtc < TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToAuthorize)'; ExpectedKill=@('R10') }
    @{ Name='M51-host-create'; File='PayPalPayFirst.vb'; Find='If String.IsNullOrWhiteSpace(returnUrl) OrElse String.IsNullOrWhiteSpace(cancelUrl) Then'; Replace='If False Then'; ExpectedKill=@('S21') }
    @{ Name='M52-host-resume'; File='PayPalPayFirst.vb'; Find='If String.IsNullOrWhiteSpace(approvedUrl) Then'; Replace='If False Then'; ExpectedKill=@('S22') }
)
}
