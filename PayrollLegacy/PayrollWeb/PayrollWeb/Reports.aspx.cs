using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace PayrollWeb
{
    public partial class Reports : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                LoadDepartments();
                // Auto-run summary on first load
                RunSummaryReport(DateTime.Now.Year, null);
                panelResults.Visible  = true;
                litReportTitle.Text   = "Payroll Summary — " + DateTime.Now.Year;
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
                ddlDeptReport.DataSource     = dt;
                ddlDeptReport.DataTextField  = "DepartmentName";
                ddlDeptReport.DataValueField = "DepartmentId";
                ddlDeptReport.DataBind();
                ddlDeptReport.Items.Insert(0, new ListItem("-- All Departments --", ""));
            }
        }

        protected void btnRunReport_Click(object sender, EventArgs e)
        {
            int year = int.Parse(ddlYear.SelectedValue);
            string reportType = ddlReportType.SelectedValue;

            switch (reportType)
            {
                case "summary":
                    RunSummaryReport(year, null);
                    litReportTitle.Text = "Payroll Summary — " + year;
                    break;
                case "earnings":
                    RunEarningsReport(year);
                    litReportTitle.Text = "Employee Earnings — " + year;
                    break;
                case "tax":
                    int? quarter = null;
                    if (!string.IsNullOrEmpty(ddlQuarter.SelectedValue))
                        quarter = int.Parse(ddlQuarter.SelectedValue);
                    RunTaxReport(year, quarter);
                    litReportTitle.Text = "Tax Liability — " + year + (quarter.HasValue ? " Q" + quarter : " (Full Year)");
                    break;
                case "headcount":
                    RunHeadcountReport();
                    litReportTitle.Text = "Headcount by Department";
                    break;
                case "deductions":
                    RunDeductionsReport(year, null);
                    litReportTitle.Text = "Deductions Summary — " + year;
                    break;
            }
            panelResults.Visible = true;
        }

        private void RunSummaryReport(int year, int? periodId)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_PayrollSummary", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FiscalYear",  year);
                cmd.Parameters.AddWithValue("@PayPeriodId", periodId.HasValue ? (object)periodId.Value : DBNull.Value);
                con.Open();
                BindGrid(cmd);
            }
        }

        private void RunEarningsReport(int year)
        {
            int? deptId = null;
            if (!string.IsNullOrEmpty(ddlDeptReport.SelectedValue))
                deptId = int.Parse(ddlDeptReport.SelectedValue);

            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_EmployeeEarnings", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@EmployeeId",  DBNull.Value);
                cmd.Parameters.AddWithValue("@DepartmentId", deptId.HasValue ? (object)deptId.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("@StartPeriod", DBNull.Value);
                cmd.Parameters.AddWithValue("@EndPeriod",   DBNull.Value);
                cmd.Parameters.AddWithValue("@FiscalYear",  year);
                con.Open();
                BindGrid(cmd);
            }
        }

        private void RunTaxReport(int year, int? quarter)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_TaxLiability", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FiscalYear", year);
                cmd.Parameters.AddWithValue("@QuarterNum", quarter.HasValue ? (object)quarter.Value : DBNull.Value);
                con.Open();
                BindGrid(cmd);
            }
        }

        private void RunHeadcountReport()
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_HeadcountByDepartment", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@AsOfDate", DBNull.Value);
                con.Open();
                BindGrid(cmd);
            }
        }

        private void RunDeductionsReport(int year, int? periodId)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_DeductionsSummary", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FiscalYear",  year);
                cmd.Parameters.AddWithValue("@PayPeriodId", periodId.HasValue ? (object)periodId.Value : DBNull.Value);
                con.Open();
                BindGrid(cmd);
            }
        }

        private void BindGrid(SqlCommand cmd)
        {
            var da = new SqlDataAdapter(cmd);
            var dt = new DataTable();
            da.Fill(dt);
            gvReport.DataSource = dt;
            gvReport.DataBind();
            if (dt.Rows.Count == 0)
                litMessage.Text = "<div class='alert alert-info'>No data found for the selected criteria.</div>";
            else
                litMessage.Text = "";
        }
    }
}
