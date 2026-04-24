<%@ Page Title="Deductions" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Deductions.aspx.cs" Inherits="PayrollWeb.Deductions" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Employee Deductions</h2>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel">
        <h3>Select Employee</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Employee</label>
                <asp:DropDownList ID="ddlEmployee" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="ddlEmployee_Changed">
                    <asp:ListItem Value="" Text="-- Select Employee --" />
                </asp:DropDownList>
            </div>
        </div>
    </div>

    <div class="panel" id="panelDeductions" runat="server" visible="false">
        <h3>Current Enrollments for: <asp:Literal ID="litEmpName" runat="server" /></h3>
        <asp:GridView ID="gvDeductions" runat="server" CssClass="grid" AutoGenerateColumns="false"
            DataKeyNames="EnrollmentId" EmptyDataText="No active deductions."
            OnRowCommand="gvDeductions_RowCommand">
            <Columns>
                <asp:BoundField DataField="TypeCode"      HeaderText="Code"         />
                <asp:BoundField DataField="TypeName"      HeaderText="Deduction"    />
                <asp:BoundField DataField="IsPreTax"      HeaderText="Pre-Tax"      />
                <asp:BoundField DataField="Amount"        HeaderText="Amount/Rate"  DataFormatString="{0:F2}" />
                <asp:BoundField DataField="IsPercentage"  HeaderText="Is %"         />
                <asp:BoundField DataField="EffectiveDate" HeaderText="Effective"    DataFormatString="{0:d}" />
                <asp:BoundField DataField="EndDate"       HeaderText="End Date"     DataFormatString="{0:d}" />
                <asp:BoundField DataField="Notes"         HeaderText="Notes"        />
                <asp:ButtonField Text="Deactivate" CommandName="Deactivate" ButtonType="Link" />
            </Columns>
        </asp:GridView>

        <div style="margin-top:16px;">
            <h3>Add / Update Enrollment</h3>
            <asp:HiddenField ID="hfEnrollmentId" runat="server" Value="0" />
            <div class="form-row">
                <div class="form-group">
                    <label>Deduction Type</label>
                    <asp:DropDownList ID="ddlDeductionType" runat="server" />
                </div>
                <div class="form-group">
                    <label>Amount or Rate</label>
                    <asp:TextBox ID="txtAmount" runat="server" />
                </div>
                <div class="form-group">
                    <label>Is Percentage?</label>
                    <asp:CheckBox ID="chkIsPercentage" runat="server" />
                </div>
                <div class="form-group">
                    <label>Effective Date</label>
                    <asp:TextBox ID="txtEffectiveDate" runat="server" TextMode="Date" />
                </div>
                <div class="form-group">
                    <label>Notes</label>
                    <asp:TextBox ID="txtNotes" runat="server" MaxLength="500" />
                </div>
                <div class="form-group" style="padding-top:20px;">
                    <asp:Button ID="btnEnroll" runat="server" Text="Enroll / Update" CssClass="btn btn-success"
                        OnClick="btnEnroll_Click" />
                </div>
            </div>
        </div>
    </div>

    <div class="panel">
        <h3>Available Deduction Types</h3>
        <asp:GridView ID="gvDeductionTypes" runat="server" CssClass="grid" AutoGenerateColumns="false"
            EmptyDataText="No deduction types found.">
            <Columns>
                <asp:BoundField DataField="TypeCode"       HeaderText="Code"         />
                <asp:BoundField DataField="TypeName"       HeaderText="Name"         />
                <asp:BoundField DataField="IsPreTax"       HeaderText="Pre-Tax"      />
                <asp:BoundField DataField="IsPercentage"   HeaderText="Is %"         />
                <asp:BoundField DataField="DefaultAmount"  HeaderText="Default"      DataFormatString="{0:F2}" />
                <asp:BoundField DataField="MaxAnnualAmount" HeaderText="Annual Max"  DataFormatString="{0:C}" />
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
