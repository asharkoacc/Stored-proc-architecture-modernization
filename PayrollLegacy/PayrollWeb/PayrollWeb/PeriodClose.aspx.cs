using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace PayrollWeb
{
    public partial class PeriodClose : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadPayPeriods();
        }

        private void LoadPayPeriods()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_PayPeriod_GetAll", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FiscalYear",    DateTime.Now.Year);
                cmd.Parameters.AddWithValue("@FrequencyType", "BiWeekly");
                cmd.Parameters.AddWithValue("@StatusFilter",  DBNull.Value);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);

                ddlPeriodToClose.Items.Clear();
                ddlPeriodToClose.Items.Add(new ListItem("-- Select Period --", ""));
                ddlAccrualPeriod.Items.Clear();
                ddlAccrualPeriod.Items.Add(new ListItem("-- Select Period --", ""));

                foreach (DataRow row in dt.Rows)
                {
                    int status = Convert.ToInt32(row["Status"]);
                    string label = row["PeriodName"] + " [" + row["StatusLabel"] + "]";
                    string val   = row["PayPeriodId"].ToString();

                    // Only open/processing periods can be closed
                    if (status == 1 || status == 2)
                        ddlPeriodToClose.Items.Add(new ListItem(label, val));

                    ddlAccrualPeriod.Items.Add(new ListItem(label, val));
                }
            }
        }

        protected void btnClosePeriod_Click(object sender, EventArgs e)
        {
            int ppId = 0;
            if (!int.TryParse(ddlPeriodToClose.SelectedValue, out ppId) || ppId == 0)
            { litMessage.Text = "<div class='alert alert-error'>Please select a pay period.</div>"; return; }

            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_PayPeriod_Close", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@PayPeriodId", ppId);
                    cmd.Parameters.AddWithValue("@ClosedBy",    user);
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                litMessage.Text = "<div class='alert alert-success'>Pay period closed successfully.</div>";
                LoadPayPeriods();
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Error closing period: " + ex.Message + "</div>";
            }
        }

        protected void btnRunAccruals_Click(object sender, EventArgs e)
        {
            int ppId = 0;
            if (!int.TryParse(ddlAccrualPeriod.SelectedValue, out ppId) || ppId == 0)
            { litMessage.Text = "<div class='alert alert-error'>Please select a pay period.</div>"; return; }

            try
            {
                using (var con = new SqlConnection(_conn))
                {
                    con.Open();
                    using (var cmd = new SqlCommand("usp_Accrual_ProcessVacation", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PayPeriodId", ppId);
                        cmd.ExecuteNonQuery();
                    }
                    using (var cmd = new SqlCommand("usp_Accrual_ProcessSickTime", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@PayPeriodId", ppId);
                        cmd.ExecuteNonQuery();
                    }
                }
                litMessage.Text = "<div class='alert alert-success'>Vacation and sick accruals processed.</div>";
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Error processing accruals: " + ex.Message + "</div>";
            }
        }

        protected void btnYearEnd_Click(object sender, EventArgs e)
        {
            int year = int.Parse(ddlTaxYear.SelectedValue);
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_YearEnd_Process", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 300;
                    cmd.Parameters.AddWithValue("@TaxYear",     year);
                    cmd.Parameters.AddWithValue("@ProcessedBy", user);
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                litMessage.Text = "<div class='alert alert-success'>Year-end processing complete for " + year + ". W-2 records generated and YTD balances reset.</div>";
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Year-end error: " + ex.Message + "</div>";
            }
        }

        protected void btnViewW2_Click(object sender, EventArgs e)
        {
            int year = int.Parse(ddlW2Year.SelectedValue);
            // Direct SQL query -- no proc for simple lookup (legacy inline SQL)
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand(
                "SELECT w.*, e.EmployeeNumber, e.FirstName + ' ' + e.LastName AS FullName " +
                "FROM W2Records w " +
                "JOIN Employees e ON e.EmployeeId = w.EmployeeId " +
                "WHERE w.TaxYear = " + year + " " +   // string concatenation -- legacy
                "ORDER BY e.LastName, e.FirstName", con))
            {
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                gvW2.DataSource = dt;
                gvW2.DataBind();
                if (dt.Rows.Count == 0)
                    litMessage.Text = "<div class='alert alert-info'>No W-2 records for " + year + ". Run Year-End Processing first.</div>";
                else
                    litMessage.Text = "";
            }
        }
    }
}
