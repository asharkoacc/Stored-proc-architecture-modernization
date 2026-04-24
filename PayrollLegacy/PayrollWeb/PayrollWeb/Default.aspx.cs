using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;

namespace PayrollWeb
{
    public partial class Default : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadDashboard();
        }

        private void LoadDashboard()
        {
            using (var con = new SqlConnection(_conn))
            {
                con.Open();

                // Active employee count
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Employees WHERE Status = 1", con))
                    litActiveEmployees.Text = cmd.ExecuteScalar()?.ToString() ?? "0";

                // Current open period
                using (var cmd = new SqlCommand(
                    "SELECT TOP 1 PeriodName FROM PayPeriods WHERE Status IN (1,2,4) ORDER BY FiscalYear DESC, PeriodNumber DESC", con))
                {
                    var result = cmd.ExecuteScalar();
                    litCurrentPeriod.Text = result?.ToString() ?? "None Open";
                }

                // Last run status
                using (var cmd = new SqlCommand(
                    "SELECT TOP 1 CASE Status WHEN 1 THEN 'Draft' WHEN 2 THEN 'Processing' " +
                    "WHEN 3 THEN 'Calculated' WHEN 4 THEN 'Approved' WHEN 5 THEN 'Posted' " +
                    "WHEN 6 THEN 'Voided' ELSE '?' END " +
                    "FROM PayrollRuns ORDER BY RunId DESC", con))
                {
                    litLastRunStatus.Text = cmd.ExecuteScalar()?.ToString() ?? "No Runs";
                }

                // YTD totals from posted runs
                using (var cmd = new SqlCommand(
                    "SELECT ISNULL(SUM(TotalGross),0), ISNULL(SUM(TotalFederalTax+TotalStateTax+TotalSSEmployee+TotalMedicare),0) " +
                    "FROM PayrollRuns WHERE Status=5 AND PayPeriodId IN (SELECT PayPeriodId FROM PayPeriods WHERE FiscalYear=" + DateTime.Now.Year + ")", con))
                using (var reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        litYTDPayroll.Text = ((decimal)reader[0]).ToString("C");
                        litYTDTax.Text = ((decimal)reader[1]).ToString("C");
                    }
                }

                // Recent runs
                using (var cmd = new SqlCommand("usp_Report_PayrollSummary", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@FiscalYear", DateTime.Now.Year);
                    var da = new SqlDataAdapter(cmd);
                    var dt = new DataTable();
                    da.Fill(dt);
                    gvRecentRuns.DataSource = dt;
                    gvRecentRuns.DataBind();
                }

                // Open periods
                using (var cmd = new SqlCommand("usp_PayPeriod_GetAll", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@FiscalYear", DateTime.Now.Year);
                    cmd.Parameters.AddWithValue("@FrequencyType", "BiWeekly");
                    cmd.Parameters.AddWithValue("@StatusFilter", DBNull.Value);
                    var da = new SqlDataAdapter(cmd);
                    var dt = new DataTable();
                    da.Fill(dt);
                    // Filter to open/processing in memory -- legacy pattern
                    var openPeriods = dt.Select("Status IN (1, 2, 4)");
                    var dtOpen = dt.Clone();
                    foreach (var row in openPeriods) dtOpen.ImportRow(row);
                    gvOpenPeriods.DataSource = dtOpen;
                    gvOpenPeriods.DataBind();
                }
            }
        }
    }
}
