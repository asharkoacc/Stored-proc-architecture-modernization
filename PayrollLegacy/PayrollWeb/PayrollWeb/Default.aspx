<%@ Page Title="Dashboard" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="PayrollWeb.Default" %>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Payroll Dashboard</h2>

    <div class="stats-row">
        <div class="stat-card">
            <div class="value"><asp:Literal ID="litActiveEmployees" runat="server" Text="—" /></div>
            <div class="label">Active Employees</div>
        </div>
        <div class="stat-card">
            <div class="value"><asp:Literal ID="litCurrentPeriod" runat="server" Text="—" /></div>
            <div class="label">Current Pay Period</div>
        </div>
        <div class="stat-card">
            <div class="value"><asp:Literal ID="litLastRunStatus" runat="server" Text="—" /></div>
            <div class="label">Last Run Status</div>
        </div>
        <div class="stat-card">
            <div class="value"><asp:Literal ID="litYTDPayroll" runat="server" Text="—" /></div>
            <div class="label">YTD Total Payroll</div>
        </div>
        <div class="stat-card">
            <div class="value"><asp:Literal ID="litYTDTax" runat="server" Text="—" /></div>
            <div class="label">YTD Total Tax</div>
        </div>
    </div>

    <div style="display:flex; gap:16px; flex-wrap:wrap;">
        <div class="panel" style="flex:2; min-width:340px;">
            <h3>Recent Payroll Runs</h3>
            <asp:GridView ID="gvRecentRuns" runat="server" CssClass="grid" AutoGenerateColumns="false"
                EmptyDataText="No payroll runs found.">
                <Columns>
                    <asp:BoundField DataField="PeriodName"   HeaderText="Period"     />
                    <asp:BoundField DataField="RunType"      HeaderText="Type"       />
                    <asp:BoundField DataField="RunStatus"    HeaderText="Status"     />
                    <asp:BoundField DataField="EmployeeCount" HeaderText="Employees" />
                    <asp:BoundField DataField="TotalGross"   HeaderText="Gross"      DataFormatString="{0:C}" />
                    <asp:BoundField DataField="TotalNetPay"  HeaderText="Net Pay"    DataFormatString="{0:C}" />
                    <asp:BoundField DataField="PostedDate"   HeaderText="Posted"     DataFormatString="{0:d}" />
                </Columns>
            </asp:GridView>
        </div>

        <div class="panel" style="flex:1; min-width:220px;">
            <h3>Open Pay Periods</h3>
            <asp:GridView ID="gvOpenPeriods" runat="server" CssClass="grid" AutoGenerateColumns="false"
                EmptyDataText="No open periods.">
                <Columns>
                    <asp:BoundField DataField="PeriodName" HeaderText="Period"    />
                    <asp:BoundField DataField="PayDate"    HeaderText="Pay Date"  DataFormatString="{0:d}" />
                    <asp:BoundField DataField="StatusLabel" HeaderText="Status"   />
                </Columns>
            </asp:GridView>
        </div>
    </div>

    <div class="panel">
        <h3>Quick Links</h3>
        <a href="Employees.aspx" class="btn">Manage Employees</a>&nbsp;
        <a href="PayrollRun.aspx" class="btn btn-success">Run Payroll</a>&nbsp;
        <a href="Reports.aspx" class="btn">Reports</a>&nbsp;
        <a href="PeriodClose.aspx" class="btn btn-warning">Period Close</a>
    </div>
</asp:Content>
