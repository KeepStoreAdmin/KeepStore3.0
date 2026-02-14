<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Contattaci.aspx.vb" Inherits="Contattaci" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Contattaci
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <%-- NOTE: stili Contattaci spostati in /Public/assets/keepstore/css/keepstore.css --%>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-contact">

        <!-- Breakcrumbs (ONSUS) -->
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <ul class="breakcrumbs">
                    <li>
                        <a href="<%= ResolveUrl("~/Default.aspx") %>" class="body-small link">Home</a>
                    </li>
                    <li class="d-flex align-items-center">
                        <i class="icon icon-arrow-right"></i>
                    </li>
                    <li>
                        <span class="body-small">Contattaci</span>
                    </li>
                </ul>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">

                <iframe id="iframeMap" runat="server"
                        src="https://www.google.com/maps?q=Italy&output=embed"
                        height="585" style="border:0;"
                        allowfullscreen="allowfullscreen"
                        referrerpolicy="no-referrer-when-downgrade">
                </iframe>

                <div class="bottom">
                    <div class="row g-3">

                        <!-- Form -->
                        <div class="col-lg-7">
                            <div class="contact-wrap">
                                <div class="box-title mb-3">
                                    <h5 class="fw-semibold mb-10">Contattaci</h5>
                                    <p class="body-text-3 mb-0">
                                        Compila il form: ti risponderemo entro 24 ore lavorative.
                                    </p>
                                </div>

                                <asp:Panel ID="pnlAlert" runat="server" Visible="false" CssClass="alert alert-danger mb-3">
                                    <asp:Label ID="lblAlert" runat="server" EnableViewState="false" />
                                </asp:Panel>

                                <div class="form-contact def">
                                    <fieldset>
                                        <label>Nome</label>
                                        <asp:TextBox ID="txtNome" runat="server" CssClass="def" />
                                        <asp:RequiredFieldValidator ID="rfvNome" runat="server"
                                            ControlToValidate="txtNome" Display="Dynamic"
                                            ErrorMessage="Inserisci il nome." />
                                    </fieldset>

                                    <fieldset>
                                        <label>Email</label>
                                        <asp:TextBox ID="txtEmail" runat="server" CssClass="def" TextMode="Email" />
                                        <asp:RequiredFieldValidator ID="rfvEmail" runat="server"
                                            ControlToValidate="txtEmail" Display="Dynamic"
                                            ErrorMessage="Inserisci l'email." />
                                    </fieldset>

                                    <fieldset>
                                        <label>Oggetto</label>
                                        <asp:TextBox ID="txtOggetto" runat="server" CssClass="def" />
                                        <asp:RequiredFieldValidator ID="rfvOggetto" runat="server"
                                            ControlToValidate="txtOggetto" Display="Dynamic"
                                            ErrorMessage="Inserisci l'oggetto." />
                                    </fieldset>

                                    <fieldset class="d-flex flex-column">
                                        <label>Messaggio</label>
                                        <asp:TextBox ID="txtMessaggio" runat="server" CssClass="def" TextMode="MultiLine" />
                                        <asp:RequiredFieldValidator ID="rfvMessaggio" runat="server"
                                            ControlToValidate="txtMessaggio" Display="Dynamic"
                                            ErrorMessage="Inserisci il messaggio." />
                                    </fieldset>

                                    <div class="box-btn-submit mt-3">
                                        <asp:Button ID="btnInvia" runat="server" Text="Invia messaggio"
                                            CssClass="tf-btn text-white w-100"
                                            OnClick="btnInvia_Click" CausesValidation="true" />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Info -->
                        <div class="col-lg-5">
                            <div class="contact-info">
                                <h5 class="fw-semibold mb-10">Informazioni</h5>
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
                                            <asp:Literal ID="litPhone" runat="server" />
                                        </a>
                                    </li>
                                    <li>
                                        <span class="icon"><i class="icon-direction"></i></span>
                                        <a id="lnkEmail" runat="server" class="link">
                                            <asp:Literal ID="litEmail" runat="server" />
                                        </a>
                                    </li>
                                </ul>
                            </div>
                        </div>

                    </div>
                </div>

            </div>
        </section>
    </div>

</asp:Content>
