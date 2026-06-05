<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="registrazioneok.aspx.vb" Inherits="registrazioneok" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Registrazione completata
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <%If Request.QueryString("state") = "coupon" Then%>
        <meta http-equiv="refresh" content="2; url='<%= "login.aspx?redirect=" & Request.QueryString("redirect") %>'" />
    <%Else%>
        <meta http-equiv="refresh" content="2; url=default.aspx" />
    <%End If%>

    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="login.aspx" class="text">Accedi</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Registrazione</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-xl-6 col-lg-7">
                    <div class="ks-auth-card text-center">
                        <h3 class="fw-semibold mb-10">Registrazione conclusa con successo!</h3>
                        <p class="mb-20">Ti abbiamo inviato una <b>mail di conferma registrazione</b>.</p>

                        <div class="d-flex align-items-center justify-content-center gap-2 mb-20">
                            <span class="icon icon-loader"></span>
                            <span class="body-text-3">Tra pochi secondi verrai reindirizzato allo shop…</span>
                        </div>

                        <div class="mt-3">
                            <a href="default.aspx" class="tf-btn btn-fill">Vai allo shop</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

</asp:Content>
