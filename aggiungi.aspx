<%@ Page Language="VB" AutoEventWireup="false" CodeFile="aggiungi.aspx.vb" Inherits="aggiungi" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>Inserimento nel carrello...</title>
</head>

<body>
<% For Each pairInidsFbPixelsSku In idsFbPixelsSku
       Dim facebook_pixel_id As String = System.Web.HttpUtility.JavaScriptStringEncode(pairInidsFbPixelsSku.Key)
       Dim sku As String = System.Web.HttpUtility.JavaScriptStringEncode(pairInidsFbPixelsSku.Value)
       Dim fnJs As String = System.Web.HttpUtility.JavaScriptStringEncode(firstName)
       Dim lnJs As String = System.Web.HttpUtility.JavaScriptStringEncode(lastName)
       Dim emJs As String = System.Web.HttpUtility.JavaScriptStringEncode(email)
       Dim phJs As String = System.Web.HttpUtility.JavaScriptStringEncode(phone)
       Dim countryJs As String = System.Web.HttpUtility.JavaScriptStringEncode(country)
       Dim provinceJs As String = System.Web.HttpUtility.JavaScriptStringEncode(province)
       Dim cityJs As String = System.Web.HttpUtility.JavaScriptStringEncode(city)
       Dim capJs As String = System.Web.HttpUtility.JavaScriptStringEncode(cap) %>
<!-- Facebook Pixel Code -->
<script>
  !function(f,b,e,v,n,t,s)
  {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
  n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];
  s.parentNode.insertBefore(t,s)}(window, document,'script',
  'https://connect.facebook.net/en_US/fbevents.js');
  fbq('init', '<%=facebook_pixel_id%>'<%If utenteId = "-1" Then%>);<%Else%>, {
	fn: '<%=fnJs%>',
    ln: '<%=lnJs%>',
	em: '<%=emJs%>',
    ph: '<%=phJs%>',
	country: '<%=countryJs%>',
	st: '<%=provinceJs%>',
	ct: '<%=cityJs%>',
	zp: '<%=capJs%>'
  });<%End If%>
  fbq('track', 'AddToCart', {
    content_ids: '<%=sku%>',
    content_type: 'product'
  });
</script>
<noscript><img height="1" width="1" style="display:none"
  src="https://www.facebook.com/tr?id=<%=facebook_pixel_id%>&ev=PageView&noscript=1"
/></noscript>
<!-- End Facebook Pixel Code -->
<% Next %>

<script>
  // Redirect client-side: consente ai pixel di partire prima del cambio pagina
  window.location.replace("carrello.aspx");
</script>

    <form id="form1" runat="server">
        <div>
            <!-- Pagina "di passaggio": fa solo logica server e poi redirect al carrello -->
        </div>
    </form>
</body>
</html>
