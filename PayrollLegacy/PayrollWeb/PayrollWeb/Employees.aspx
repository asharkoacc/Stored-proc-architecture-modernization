<%@ Page Title="Employees" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Employees.aspx.cs" Inherits="PayrollWeb.Employees" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Employee Management</h2>

    <div class="panel">
        <h3>Search Employees</h3>
        <div class="form-row">
            <div class="form-group">
                <label>Search (name / employee #)</label>
                <asp:TextBox ID="txtSearch" runat="server" placeholder="Enter name or EMP#..." />
            </div>
            <div class="form-group">
                <label>Department</label>
                <asp:DropDownList ID="ddlDeptFilter" runat="server">
                    <asp:ListItem Value="" Text="-- All Departments --" />
                </asp:DropDownList>
            </div>
            <div class="form-group">
                <label>Status</label>
                <asp:DropDownList ID="ddlStatusFilter" runat="server">
                    <asp:ListItem Value="" Text="-- All Statuses --" />
                    <asp:ListItem Value="1" Text="Active" />
                    <asp:ListItem Value="2" Text="On Leave" />
                    <asp:ListItem Value="3" Text="Terminated" />
                    <asp:ListItem Value="4" Text="Suspended" />
                </asp:DropDownList>
            </div>
            <div class="form-group" style="padding-top:20px;">
                <asp:Button ID="btnSearch" runat="server" Text="Search" CssClass="btn"
                    OnClick="btnSearch_Click" />
                &nbsp;
                <asp:Button ID="btnClear" runat="server" Text="Clear" CssClass="btn"
                    OnClick="btnClear_Click" />
            </div>
        </div>
    </div>

    <asp:Literal ID="litMessage" runat="server" />

    <div class="panel">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
            <h3>Employee List
                (<asp:Literal ID="litCount" runat="server" Text="0" /> records)
            </h3>
            <a href="EmployeeDetail.aspx" class="btn btn-success">+ New Employee</a>
        </div>
        <asp:GridView ID="gvEmployees" runat="server" CssClass="grid" AutoGenerateColumns="false"
            EmptyDataText="No employees found matching search criteria."
            DataKeyNames="EmployeeId">
            <Columns>
                <asp:BoundField  DataField="EmployeeNumber" HeaderText="Emp #"       />
                <asp:BoundField  DataField="FullName"       HeaderText="Full Name"    />
                <asp:BoundField  DataField="DepartmentName" HeaderText="Department"   />
                <asp:BoundField  DataField="GradeCode"      HeaderText="Grade"        />
                <asp:BoundField  DataField="PositionTitle"  HeaderText="Title"        />
                <asp:BoundField  DataField="AnnualSalary"   HeaderText="Salary"       DataFormatString="{0:C}" />
                <asp:BoundField  DataField="HireDate"       HeaderText="Hire Date"    DataFormatString="{0:d}" />
                <asp:BoundField  DataField="StatusLabel"    HeaderText="Status"       />
                <asp:HyperLinkField DataNavigateUrlFields="EmployeeId"
                    DataNavigateUrlFormatString="EmployeeDetail.aspx?id={0}"
                    Text="Edit" HeaderText="Action" />
            </Columns>
        </asp:GridView>
    </div>
</asp:Content>
