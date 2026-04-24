<%@ Page Title="Payroll Run" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="PayrollRun.aspx.cs" Inherits="PayrollWeb.PayrollRun" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Payroll Run Processing</h2>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel">
        <h3>1. Select Pay Period</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Pay Period</label>
                <asp:DropDownList ID="ddlPayPeriod" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="ddlPayPeriod_Changed">
                    <asp:ListItem Value="" Text="-- Select Pay Period --" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Run Type</label>
                <asp:DropDownList ID="ddlRunType" runat="server">
                    <asp:ListItem Value="1" Text="Regular" />
                    <asp:ListItem Value="2" Text="Supplemental" />
                    <asp:ListItem Value="3" Text="Bonus" />
                    <asp:ListItem Value="4" Text="Correction" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnInitiate" runat="server" Text="Initiate Run" CssClass="btn btn-success"
                    OnClick="btnInitiate_Click" />
            </div>
        </div>
    </div>

    <div class="panel" id="panelRunActions" runat="server" visible="false">
        <h3>2. Manage Run
            — <asp:Literal ID="litRunId" runat="server" /> |
            Status: <strong><asp:Literal ID="litRunStatus" runat="server" /></strong>
        </h3>
        <asp:HiddenField ID="hfRunId" runat="server" />
        <div style="margin-bottom:10px;">
            <asp:Button ID="btnProcess" runat="server" Text="Process / Calculate" CssClass="btn"
                OnClick="btnProcess_Click"
                OnClientClick="return confirm('Process payroll for all active employees?');" />
            &nbsp;
            <asp:Button ID="btnApprove" runat="server" Text="Approve Run" CssClass="btn btn-success"
                OnClick="btnApprove_Click" />
            &nbsp;
            <asp:Button ID="btnPost" runat="server" Text="Post Run" CssClass="btn btn-success"
                OnClick="btnPost_Click"
                OnClientClick="return confirm('Post this payroll run? This will update all employee YTD balances.');" />
            &nbsp;
            <asp:Button ID="btnVoid" runat="server" Text="Void Run" CssClass="btn btn-danger"
                OnClick="btnVoid_Click"
                OnClientClick="return confirm('VOID this run? This will REVERSE YTD balances if already posted.');" />
        </div>

        <div class="panel" style="background:#f4f8ff;">
            <h3>Run Totals</h3>
            <table class="grid">
                <tr><th>Employees</th><th>Gross Pay</th><th>Federal Tax</th><th>State Tax</th><th>FICA</th><th>Deductions</th><th>Net Pay</th></tr>
                <tr>
                    <td><asp:Literal ID="litEmpCount"   runat="server" Text="0" /></td>
                    <td><asp:Literal ID="litTotalGross" runat="server" Text="$0.00" /></td>
                    <td><asp:Literal ID="litTotalFed"   runat="server" Text="$0.00" /></td>
                    <td><asp:Literal ID="litTotalState" runat="server" Text="$0.00" /></td>
                    <td><asp:Literal ID="litTotalFICA"  runat="server" Text="$0.00" /></td>
                    <td><asp:Literal ID="litTotalDed"   runat="server" Text="$0.00" /></td>
                    <td><asp:Literal ID="litTotalNet"   runat="server" Text="$0.00" /></td>
                </tr>
            </table>
        </div>
    </div>

    <div class="panel" id="panelDetail" runat="server" visible="false">
        <h3>3. Employee Detail Lines</h3>
        <asp:GridView ID="gvDetail" runat="server" CssClass="grid" AutoGenerateColumns="false"
            EmptyDataText="No detail lines calculated yet.">
            <Columns>
                <asp:BoundField DataField="EmployeeNumber" HeaderText="Emp #"     />
                <asp:BoundField DataField="FullName"       HeaderText="Name"      />
                <asp:BoundField DataField="DepartmentName" HeaderText="Dept"      />
                <asp:BoundField DataField="RegularHours"   HeaderText="Reg Hrs"   DataFormatString="{0:F2}" />
                <asp:BoundField DataField="OvertimeHours"  HeaderText="OT Hrs"    DataFormatString="{0:F2}" />
                <asp:BoundField DataField="GrossPay"       HeaderText="Gross"     DataFormatString="{0:C}" />
                <asp:BoundField DataField="FederalTax"     HeaderText="Fed Tax"   DataFormatString="{0:C}" />
                <asp:BoundField DataField="StateTax"       HeaderText="St Tax"    DataFormatString="{0:C}" />
                <asp:BoundField DataField="SocialSecurity" HeaderText="SS"        DataFormatString="{0:C}" />
                <asp:BoundField DataField="Medicare"       HeaderText="Med"       DataFormatString="{0:C}" />
                <asp:BoundField DataField="NetPay"         HeaderText="Net Pay"   DataFormatString="{0:C}" />
                <asp:BoundField DataField="StatusLabel"    HeaderText="Status"    />
                <asp:BoundField DataField="ErrorMessage"   HeaderText="Error"     />
            </Columns>
        </asp:GridView>
    </div>

    <div class="panel">
        <h3>Existing Runs for Selected Period</h3>
        <asp:GridView ID="gvExistingRuns" runat="server" CssClass="grid" AutoGenerateColumns="false"
            EmptyDataText="No runs for this period.">
            <Columns>
                <asp:BoundField DataField="RunId"        HeaderText="Run ID"    />
                <asp:BoundField DataField="RunType"      HeaderText="Type"      />
                <asp:BoundField DataField="StatusLabel"  HeaderText="Status"    />
                <asp:BoundField DataField="EmployeeCount" HeaderText="Employees" />
                <asp:BoundField DataField="TotalGross"   HeaderText="Gross"     DataFormatString="{0:C}" />
                <asp:BoundField DataField="TotalNetPay"  HeaderText="Net Pay"   DataFormatString="{0:C}" />
                <asp:BoundField DataField="ProcessedDate" HeaderText="Processed" DataFormatString="{0:g}" />
                <asp:BoundField DataField="ApprovedBy"   HeaderText="Approved By" />
                <asp:HyperLinkField Text="Load" DataNavigateUrlFields="RunId"
                    DataNavigateUrlFormatString="PayrollRun.aspx?runId={0}" HeaderText="" />
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
