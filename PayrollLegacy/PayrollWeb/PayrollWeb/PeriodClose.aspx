<%@ Page Title="Period Close" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="PeriodClose.aspx.cs" Inherits="PayrollWeb.PeriodClose" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Period Close &amp; Year-End Processing</h2>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel">
        <h3>Period Close</h3>
        <p style="color:#666; margin-bottom:10px;">
            Close a pay period after all payroll runs are posted or voided.
            Closing prevents new runs from being initiated for the period.
        </p>
        <div class="form-row">
            <div class="form-group">
                <label>Select Pay Period to Close</label>
                <asp:DropDownList ID="ddlPeriodToClose" runat="server">
                    <asp:ListItem Value="" Text="-- Select Period --" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnClosePeriod" runat="server" Text="Close Period" CssClass="btn btn-warning"
                    OnClick="btnClosePeriod_Click"
                    OnClientClick="return confirm('Close this pay period? No new runs can be initiated after closing.');" />
            </div>
        </div>
    </div>

    <div class="panel">
        <h3>Vacation / Sick Accruals</h3>
        <p style="color:#666; margin-bottom:10px;">
            Run accruals for a pay period (normally executed automatically as part of payroll processing).
        </p>
        <div class="form-row">
            <div class="form-group">
                <label>Pay Period</label>
                <asp:DropDownList ID="ddlAccrualPeriod" runat="server">
                    <asp:ListItem Value="" Text="-- Select Period --" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnRunAccruals" runat="server" Text="Run Accruals" CssClass="btn"
                    OnClick="btnRunAccruals_Click" />
            </div>
        </div>
    </div>

    <div class="panel" style="border-left:4px solid #c0392b;">
        <h3>Year-End Processing</h3>
        <p style="color:#666; margin-bottom:10px;">
            Generates W-2 records for all employees and resets YTD balances to zero.
            <strong>This action cannot be undone.</strong> Run only after the final payroll of the year is posted.
        </p>
        <div class="form-row">
            <div class="form-group">
                <label>Tax Year for W-2 Generation</label>
                <asp:DropDownList ID="ddlTaxYear" runat="server">
                    <asp:ListItem Value="2024" Text="2024" Selected="True" />
                    <asp:ListItem Value="2023" Text="2023" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnYearEnd" runat="server" Text="Run Year-End Process" CssClass="btn btn-danger"
                    OnClick="btnYearEnd_Click"
                    OnClientClick="return confirm('WARNING: This will generate W2 records and reset ALL employee YTD balances. Are you absolutely sure?');" />
            </div>
        </div>
    </div>

    <div class="panel">
        <h3>W-2 Records Generated</h3>
        <div class="form-row">
            <div class="form-group">
                <label>View W-2s for Year</label>
                <asp:DropDownList ID="ddlW2Year" runat="server">
                    <asp:ListItem Value="2024" Text="2024" Selected="True" />
                    <asp:ListItem Value="2023" Text="2023" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnViewW2" runat="server" Text="View W-2s" CssClass="btn"
                    OnClick="btnViewW2_Click" />
            </div>
        </div>
        <asp:GridView ID="gvW2" runat="server" CssClass="grid" AutoGenerateColumns="false"
            EmptyDataText="No W-2 records found for the selected year.">
            <Columns>
                <asp:BoundField DataField="EmployeeId"   HeaderText="Emp ID"   />
                <asp:BoundField DataField="TaxYear"      HeaderText="Year"     />
                <asp:BoundField DataField="Box1_Wages"   HeaderText="Box 1 Wages"    DataFormatString="{0:C}" />
                <asp:BoundField DataField="Box2_FedTax"  HeaderText="Box 2 Fed Tax"  DataFormatString="{0:C}" />
                <asp:BoundField DataField="Box4_SS_Tax"  HeaderText="Box 4 SS Tax"   DataFormatString="{0:C}" />
                <asp:BoundField DataField="Box6_Med_Tax" HeaderText="Box 6 Med Tax"  DataFormatString="{0:C}" />
                <asp:BoundField DataField="Box12a_Code"  HeaderText="Box 12 Code"    />
                <asp:BoundField DataField="Box12a_Amount" HeaderText="Box 12 Amt"   DataFormatString="{0:C}" />
                <asp:BoundField DataField="Box17_StateTax" HeaderText="Box 17 St Tax" DataFormatString="{0:C}" />
                <asp:BoundField DataField="GeneratedDate" HeaderText="Generated"     DataFormatString="{0:d}" />
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
