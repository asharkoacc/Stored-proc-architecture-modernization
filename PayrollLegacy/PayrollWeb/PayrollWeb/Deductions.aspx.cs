using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace PayrollWeb
{
    public partial class Deductions : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                LoadEmployees();
                LoadDeductionTypes();
                txtEffectiveDate.Text = DateTime.Today.ToString("yyyy-MM-dd");
            }
        }

        private void LoadEmployees()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Employee_GetAll", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IncludeTerminated", 0);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                ddlEmployee.DataSource     = dt;
                ddlEmployee.DataTextField  = "FullName";
                ddlEmployee.DataValueField = "EmployeeId";
                ddlEmployee.DataBind();
                ddlEmployee.Items.Insert(0, new ListItem("-- Select Employee --", ""));
            }
        }

        private void LoadDeductionTypes()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_DeductionType_GetAll", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IncludeInactive", 0);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);

                // Bind to deduction type dropdown and display grid
                ddlDeductionType.DataSource     = dt;
                ddlDeductionType.DataTextField  = "TypeName";
                ddlDeductionType.DataValueField = "DeductionTypeId";
                ddlDeductionType.DataBind();

                gvDeductionTypes.DataSource = dt;
                gvDeductionTypes.DataBind();
            }
        }

        protected void ddlEmployee_Changed(object sender, EventArgs e)
        {
            int empId = 0;
            if (!int.TryParse(ddlEmployee.SelectedValue, out empId) || empId == 0) return;
            LoadEmployeeDeductions(empId);
            panelDeductions.Visible = true;
            litEmpName.Text = ddlEmployee.SelectedItem.Text;
        }

        private void LoadEmployeeDeductions(int empId)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_EmployeeDeduction_GetByEmployee", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@EmployeeId", empId);
                cmd.Parameters.AddWithValue("@ActiveOnly", 0);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                gvDeductions.DataSource = dt;
                gvDeductions.DataBind();
            }
        }

        protected void gvDeductions_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "Deactivate")
            {
                int rowIdx = int.Parse(e.CommandArgument.ToString());
                int enrollId = (int)gvDeductions.DataKeys[rowIdx].Value;
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_EmployeeDeduction_Update", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@EnrollmentId",  enrollId);
                    cmd.Parameters.AddWithValue("@Amount",         0);
                    cmd.Parameters.AddWithValue("@IsPercentage",   0);
                    cmd.Parameters.AddWithValue("@EndDate",        DateTime.Today);
                    cmd.Parameters.AddWithValue("@IsActive",       0);
                    cmd.Parameters.AddWithValue("@Notes",          "Deactivated via web UI");
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                int empId = int.Parse(ddlEmployee.SelectedValue);
                LoadEmployeeDeductions(empId);
                litMessage.Text = "<div class='alert alert-info'>Deduction deactivated.</div>";
            }
        }

        protected void btnEnroll_Click(object sender, EventArgs e)
        {
            int empId = 0;
            if (!int.TryParse(ddlEmployee.SelectedValue, out empId) || empId == 0)
            { litMessage.Text = "<div class='alert alert-error'>Please select an employee.</div>"; return; }

            if (string.IsNullOrEmpty(txtAmount.Text) || string.IsNullOrEmpty(txtEffectiveDate.Text))
            { litMessage.Text = "<div class='alert alert-error'>Amount and Effective Date are required.</div>"; return; }

            decimal amount;
            if (!decimal.TryParse(txtAmount.Text, out amount))
            { litMessage.Text = "<div class='alert alert-error'>Amount must be a number.</div>"; return; }

            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_EmployeeDeduction_Enroll", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@EmployeeId",      empId);
                cmd.Parameters.AddWithValue("@DeductionTypeId", int.Parse(ddlDeductionType.SelectedValue));
                cmd.Parameters.AddWithValue("@Amount",          amount);
                cmd.Parameters.AddWithValue("@IsPercentage",    chkIsPercentage.Checked ? 1 : 0);
                cmd.Parameters.AddWithValue("@EffectiveDate",   DateTime.Parse(txtEffectiveDate.Text));
                cmd.Parameters.AddWithValue("@Notes",           string.IsNullOrEmpty(txtNotes.Text) ? (object)DBNull.Value : txtNotes.Text.Trim());
                var pOut = cmd.Parameters.Add("@EnrollmentId", SqlDbType.Int);
                pOut.Direction = ParameterDirection.Output;
                con.Open();
                cmd.ExecuteNonQuery();
            }
            LoadEmployeeDeductions(empId);
            litMessage.Text = "<div class='alert alert-success'>Deduction enrollment saved.</div>";
            txtAmount.Text  = "";
            txtNotes.Text   = "";
        }
    }
}
