using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace PayrollWeb
{
    public partial class Employees : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                LoadDepartments();
                SearchEmployees();
            }
        }

        private void LoadDepartments()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Department_GetAll", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                ddlDeptFilter.DataSource     = dt;
                ddlDeptFilter.DataTextField  = "DepartmentName";
                ddlDeptFilter.DataValueField = "DepartmentId";
                ddlDeptFilter.DataBind();
                ddlDeptFilter.Items.Insert(0, new ListItem("-- All Departments --", ""));
            }
        }

        private void SearchEmployees()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Employee_Search", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;

                string searchTerm  = txtSearch.Text.Trim();
                string deptFilter  = ddlDeptFilter.SelectedValue;
                string statFilter  = ddlStatusFilter.SelectedValue;

                cmd.Parameters.AddWithValue("@SearchTerm",   string.IsNullOrEmpty(searchTerm) ? (object)DBNull.Value : searchTerm);
                cmd.Parameters.AddWithValue("@DepartmentId", string.IsNullOrEmpty(deptFilter) ? (object)DBNull.Value : (object)int.Parse(deptFilter));
                cmd.Parameters.AddWithValue("@Status",       string.IsNullOrEmpty(statFilter) ? (object)DBNull.Value : (object)int.Parse(statFilter));
                cmd.Parameters.AddWithValue("@PayGradeId",   DBNull.Value);

                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);

                // Map status code to label in memory -- magic numbers duplicated from DB
                dt.Columns.Add("StatusLabel", typeof(string));
                foreach (DataRow row in dt.Rows)
                {
                    int status = Convert.ToInt32(row["Status"]);
                    row["StatusLabel"] = status == 1 ? "Active"
                                       : status == 2 ? "Leave"
                                       : status == 3 ? "Terminated"
                                       : status == 4 ? "Suspended"
                                       : "Unknown";
                }

                gvEmployees.DataSource = dt;
                gvEmployees.DataBind();
                litCount.Text = dt.Rows.Count.ToString();
            }
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            SearchEmployees();
        }

        protected void btnClear_Click(object sender, EventArgs e)
        {
            txtSearch.Text             = "";
            ddlDeptFilter.SelectedIndex = 0;
            ddlStatusFilter.SelectedIndex = 0;
            SearchEmployees();
        }
    }
}
