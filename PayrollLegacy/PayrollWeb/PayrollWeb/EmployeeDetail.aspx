<%@ Page Title="Employee Detail" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="EmployeeDetail.aspx.cs" Inherits="PayrollWeb.EmployeeDetail" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2><asp:Literal ID="litPageTitle" runat="server" Text="New Employee" /></h2>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel">
        <h3>Personal Information</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Employee Number *</label>
                <asp:TextBox ID="txtEmpNumber" runat="server" MaxLength="20" />
            </div>
            <div class="form-group">
                <label>First Name *</label>
                <asp:TextBox ID="txtFirstName" runat="server" MaxLength="50" />
            </div>
            <div class="form-group">
                <label>Middle Name</label>
                <asp:TextBox ID="txtMiddleName" runat="server" MaxLength="50" />
            </div>
            <div class="form-group">
                <label>Last Name *</label>
                <asp:TextBox ID="txtLastName" runat="server" MaxLength="50" />
            </div>
        </div>
        <div class="form-row">
            <div class="form-group">
                <label>SSN (xxx-xx-xxxx)</label>
                <asp:TextBox ID="txtSSN" runat="server" MaxLength="11" />
            </div>
            <div class="form-group">
                <label>Date of Birth *</label>
                <asp:TextBox ID="txtDOB" runat="server" TextMode="Date" />
            </div>
            <div class="form-group">
                <label>Email</label>
                <asp:TextBox ID="txtEmail" runat="server" MaxLength="255" />
            </div>
            <div class="form-group">
                <label>Phone</label>
                <asp:TextBox ID="txtPhone" runat="server" MaxLength="20" />
            </div>
        </div>
        <div class="form-row">
            <div class="form-group" style="flex:2;">
                <label>Address</label>
                <asp:TextBox ID="txtAddress" runat="server" MaxLength="200" />
            </div>
            <div class="form-group">
                <label>City</label>
                <asp:TextBox ID="txtCity" runat="server" MaxLength="100" />
            </div>
            <div class="form-group">
                <label>State</label>
                <asp:TextBox ID="txtStateAddr" runat="server" MaxLength="2" style="width:50px;" />
            </div>
            <div class="form-group">
                <label>Zip</label>
                <asp:TextBox ID="txtZip" runat="server" MaxLength="10" />
            </div>
        </div>
    </div>

    <div class="panel">
        <h3>Employment Information</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Hire Date *</label>
                <asp:TextBox ID="txtHireDate" runat="server" TextMode="Date" />
            </div>
            <div class="form-group">
                <label>Department *</label>
                <asp:DropDownList ID="ddlDepartment" runat="server" />
            </div>
            <div class="form-group">
                <label>Pay Grade *</label>
                <asp:DropDownList ID="ddlPayGrade" runat="server" />
            </div>
            <div class="form-group">
                <label>Position Title *</label>
                <asp:TextBox ID="txtTitle" runat="server" MaxLength="100" />
            </div>
        </div>
        <div class="form-row">
            <div class="form-group">
                <label>Annual Salary *</label>
                <asp:TextBox ID="txtSalary" runat="server" />
            </div>
            <div class="form-group">
                <label>Hourly Rate (if applicable)</label>
                <asp:TextBox ID="txtHourlyRate" runat="server" />
            </div>
            <div class="form-group">
                <label>Pay Frequency *</label>
                <asp:DropDownList ID="ddlPayFrequency" runat="server">
                    <asp:ListItem Value="Weekly"      Text="Weekly" />
                    <asp:ListItem Value="BiWeekly"    Text="Bi-Weekly" Selected="True" />
                    <asp:ListItem Value="SemiMonthly" Text="Semi-Monthly" />
                    <asp:ListItem Value="Monthly"     Text="Monthly" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Employment Type *</label>
                <asp:DropDownList ID="ddlEmpType" runat="server">
                    <asp:ListItem Value="1" Text="Full-Time" Selected="True" />
                    <asp:ListItem Value="2" Text="Part-Time" />
                    <asp:ListItem Value="3" Text="Contractor" />
                    <asp:ListItem Value="4" Text="Seasonal" />
                </asp:DropDownList>
            </div>
        </div>
    </div>

    <div class="panel">
        <h3>Tax Information</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Filing Status</label>
                <asp:DropDownList ID="ddlFilingStatus" runat="server">
                    <asp:ListItem Value="Single"  Text="Single" Selected="True" />
                    <asp:ListItem Value="Married" Text="Married Filing Jointly" />
                    <asp:ListItem Value="MarriedSeparate" Text="Married Filing Separately" />
                    <asp:ListItem Value="HeadOfHousehold" Text="Head of Household" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Federal Allowances</label>
                <asp:TextBox ID="txtAllowances" runat="server" Text="1" />
            </div>
            <div class="form-group">
                <label>Home State</label>
                <asp:TextBox ID="txtStateCode" runat="server" MaxLength="2" Text="CA" style="width:50px;" />
            </div>
            <div class="form-group">
                <label>Work State</label>
                <asp:TextBox ID="txtWorkState" runat="server" MaxLength="2" Text="CA" style="width:50px;" />
            </div>
        </div>
        <div class="panel" style="background:#fffbe6; border:1px solid #e0c040; margin-top:10px;">
            <strong>Estimated Per-Period Tax (calculated locally):</strong>
            Federal: <asp:Literal ID="litEstFedTax" runat="server" Text="$0.00" /> &nbsp;|&nbsp;
            State: <asp:Literal ID="litEstStateTax" runat="server" Text="$0.00" /> &nbsp;|&nbsp;
            FICA: <asp:Literal ID="litEstFICA" runat="server" Text="$0.00" />
            <br /><small style="color:#888;">Note: estimate uses hardcoded 2024 brackets in code-behind (duplicated from stored procedures)</small>
        </div>
    </div>

    <div class="panel">
        <asp:HiddenField ID="hfEmployeeId" runat="server" Value="0" />
        <asp:Button ID="btnSave" runat="server" Text="Save Employee" CssClass="btn btn-success" OnClick="btnSave_Click" />
        &nbsp;
        <asp:Button ID="btnEstimate" runat="server" Text="Estimate Tax" CssClass="btn" OnClick="btnEstimate_Click" />
        &nbsp;
        <asp:Button ID="btnTerminate" runat="server" Text="Terminate" CssClass="btn btn-danger" Visible="false"
            OnClick="btnTerminate_Click"
            OnClientClick="return confirm('Are you sure you want to terminate this employee?');" />
        &nbsp;
        <a href="Employees.aspx" class="btn">Cancel</a>

        <div style="margin-top:10px;" id="terminateDiv" runat="server" visible="false">
            <label>Termination Date:</label>
            <asp:TextBox ID="txtTermDate" runat="server" TextMode="Date" style="width:160px;" />
            &nbsp;
            <label>Reason:</label>
            <asp:TextBox ID="txtTermReason" runat="server" style="width:260px;" />
        </div>
    </div>
</asp:Content>
