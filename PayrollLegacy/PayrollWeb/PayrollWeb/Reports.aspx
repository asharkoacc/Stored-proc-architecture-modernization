<%@ Page Title="Reports" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Reports.aspx.cs" Inherits="PayrollWeb.Reports" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Payroll Reports</h2>

    <div class="panel">
        <h3>Report Parameters</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Report Type</label>
                <asp:DropDownList ID="ddlReportType" runat="server">
                    <asp:ListItem Value="summary"    Text="Payroll Summary by Period"     />
                    <asp:ListItem Value="earnings"   Text="Employee Earnings Detail"      />
                    <asp:ListItem Value="tax"        Text="Tax Liability by Quarter"      />
                    <asp:ListItem Value="headcount"  Text="Headcount by Department"       />
                    <asp:ListItem Value="deductions" Text="Deductions Summary"            />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Fiscal Year</label>
                <asp:DropDownList ID="ddlYear" runat="server">
                    <asp:ListItem Value="2024" Text="2024" Selected="True" />
                    <asp:ListItem Value="2023" Text="2023" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Quarter (tax report only)</label>
                <asp:DropDownList ID="ddlQuarter" runat="server">
                    <asp:ListItem Value="" Text="-- All Quarters --" />
                    <asp:ListItem Value="1" Text="Q1 (Jan-Mar)" />
                    <asp:ListItem Value="2" Text="Q2 (Apr-Jun)" />
                    <asp:ListItem Value="3" Text="Q3 (Jul-Sep)" />
                    <asp:ListItem Value="4" Text="Q4 (Oct-Dec)" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Department (earnings only)</label>
                <asp:DropDownList ID="ddlDeptReport" runat="server">
                    <asp:ListItem Value="" Text="-- All Departments --" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnRunReport" runat="server" Text="Run Report" CssClass="btn"
                    OnClick="btnRunReport_Click" />
            </div>
        </div>
    </div>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel" id="panelResults" runat="server" visible="false">
        <h3><asp:Literal ID="litReportTitle" runat="server" /></h3>
        <asp:GridView ID="gvReport" runat="server" CssClass="grid" AutoGenerateColumns="true"
            EmptyDataText="No data found for the selected parameters." />
    </div>
</asp:Content>
