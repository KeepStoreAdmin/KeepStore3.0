<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Contattaci.aspx.vb" Inherits="Contattaci" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- Contact page specific head (kept minimal on purpose) -->
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumb -->
    <section class="tf-breadcrumb">
        <div class="container">
            <div class="wrap-breadcrumb">
                <div class="breadcrumb-content">
                    <div class="title-breadcrumb">Contattaci</div>
                    <div class="breadcrumb-list">
                        <a href="/Default.aspx" class="breadcrumb-item">Home</a>
                        <div class="breadcrumb-item dot"><span></span></div>
                        <div class="breadcrumb-item">Contattaci</div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Contact (ONSUS) -->
    <section class="tf-sp-2">
        <div class="container">

            <asp:Panel ID="pnlAlert" runat="server" Visible="false">
                <asp:Label ID="lblAlert" runat="server"></asp:Label>
            </asp:Panel>

            <div class="wg-map">
                <iframe id="iframeMap" runat="server"
                        height="585" style="border-radius:8px; width: 100%; border:0;" allowfullscreen=""
                        referrerpolicy="no-referrer-when-downgrade">
                </iframe>

                <div class="bottom">
                    <div class="contact-wrap">
                        <div class="box-title">
                            <h5 class="fw-semibold">Richiedi informazioni</h5>
                            <p class="body-text-3">
                                Compila il form: ti risponderemo il prima possibile.
                            </p>
                        </div>

                        <asp:ValidationSummary ID="vsForm" runat="server"
                            CssClass="text-danger mb-3"
                            DisplayMode="BulletList"
                            HeaderText="Controlla i campi:" />

                        <div class="form-contact def">

                            <fieldset>
                                <label for="txtNome">Nome</label>
                                <asp:TextBox ID="txtNome" runat="server" />
                                <asp:RequiredFieldValidator ID="rfvNome" runat="server"
                                    ControlToValidate="txtNome"
                                    ErrorMessage="Inserisci il nome."
                                    Display="None" />
                            </fieldset>

                            <fieldset>
                                <label for="txtEmail">Email</label>
                                <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" />
                                <asp:RequiredFieldValidator ID="rfvEmail" runat="server"
                                    ControlToValidate="txtEmail"
                                    ErrorMessage="Inserisci l'email."
                                    Display="None" />
                                <asp:RegularExpressionValidator ID="revEmail" runat="server"
                                    ControlToValidate="txtEmail"
                                    ErrorMessage="Email non valida."
                                    ValidationExpression="^[^\s@]+@[^\s@]+\.[^\s@]+$"
                                    Display="None" />
                            </fieldset>

                            <fieldset>
                                <label for="txtOggetto">Oggetto</label>
                                <asp:TextBox ID="txtOggetto" runat="server" />
                                <asp:RequiredFieldValidator ID="rfvOggetto" runat="server"
                                    ControlToValidate="txtOggetto"
                                    ErrorMessage="Inserisci l'oggetto."
                                    Display="None" />
                            </fieldset>

                            <fieldset class="d-flex flex-column">
                                <label for="txtMessaggio">Messaggio</label>
                                <asp:TextBox ID="txtMessaggio" runat="server" TextMode="MultiLine" Style="height:170px;" />
                                <asp:RequiredFieldValidator ID="rfvMessaggio" runat="server"
                                    ControlToValidate="txtMessaggio"
                                    ErrorMessage="Inserisci il messaggio."
                                    Display="None" />
                            </fieldset>

                            <div class="box-btn-submit">
                                <asp:Button ID="btnInvia" runat="server"
                                    CssClass="tf-btn text-white w-100"
                                    Text="Invia messaggio"
                                    OnClick="btnInvia_Click" />
                            </div>

                        </div>
                    </div>

                    <div class="contact-info">
                        <h5 class="fw-semibold">Informazioni di contatto</h5>
                        <ul class="info-list">
                            <li>
                                <span class="icon"><i class="icon-location"></i></span>
                                <a id="lnkMap" runat="server" class="link" target="_blank">
                                    <asp:Literal ID="litAddress" runat="server" />
                                </a>
                            </li>
                            <li>
                                <span class="icon"><i class="icon-phone"></i></span>
                                <a id="lnkPhone" runat="server" class="product-title fw-semibold link">
                                    <span><asp:Literal ID="litPhone" runat="server" /></span>
                                </a>
                            </li>
                            <li>
                                <span class="icon"><i class="icon-direction"></i></span>
                                <a id="lnkEmail" runat="server" class="link">
                                    <span><asp:Literal ID="litEmail" runat="server" /></span>
                                </a>
                            </li>
                        </ul>
                    </div>
                </div>

            </div>
        </div>
    </section>

</asp:Content>
