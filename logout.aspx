<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="logout.aspx.vb"
    Inherits="logout" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Uscita effettuata
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        /* KS-QA-BROWSER-1B - pagina di uscita: un riquadro piatto, conferma chiara, due azioni con bersagli da 48 px. */
        .ks-logout {
            max-width: 620px;
            margin: 0 auto;
            padding: 32px 20px;
            background: #fff;
            box-shadow: 5px 6px 30px 0 rgba(0, 0, 0, .1);
            text-align: center;
        }

        .ks-logout__mark {
            position: relative;
            display: block;
            width: 56px;
            height: 56px;
            margin: 0 auto 16px;
            background: #1a7f37;
        }

        .ks-logout__mark::after {
            content: "";
            position: absolute;
            top: 17px;
            left: 15px;
            width: 26px;
            height: 13px;
            border-left: 4px solid #fff;
            border-bottom: 4px solid #fff;
            transform: rotate(-45deg);
        }

        .ks-logout__title {
            margin: 0 0 8px;
            font-size: 26px;
            font-weight: 600;
            line-height: 1.2;
        }

        .ks-logout__lead {
            margin: 0 0 6px;
            color: #333e48;
            font-size: 16px;
        }

        .ks-logout__note {
            margin: 0 0 24px;
            color: #595959;
            font-size: 14px;
        }

        .ks-logout__actions {
            display: grid;
            grid-template-columns: minmax(0, 1fr);
            gap: 12px;
        }

        .ks-logout__actions .tf-btn {
            min-height: 48px;
            border-radius: 0;
        }

        @media (min-width: 576px) {
            .ks-logout {
                padding: 40px;
            }

            .ks-logout__actions {
                grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
            }
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Uscita</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="ks-logout" role="status">
                <span class="ks-logout__mark" aria-hidden="true"></span>
                <h1 class="ks-logout__title">Hai effettuato l'uscita</h1>
                <p class="ks-logout__lead">La sessione su questo dispositivo &egrave; stata chiusa.</p>
                <p class="ks-logout__note">Il carrello del tuo account resta salvato: lo ritrovi al prossimo accesso.</p>
                <div class="ks-logout__actions">
                    <a id="hlLogoutHome" href="<%= ResolveUrl("~/Default.aspx") %>" class="tf-btn">Continua gli acquisti</a>
                    <a id="hlLogoutLogin" href="<%= ResolveUrl("~/login.aspx") %>" class="tf-btn btn-line">Accedi di nuovo</a>
                </div>
            </div>
        </div>
    </section>

</asp:Content>
