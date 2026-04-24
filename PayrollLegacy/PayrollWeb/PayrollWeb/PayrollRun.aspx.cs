using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;

namespace PayrollWeb
{
    public partial class PayrollRun : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        // LEGACY: business rule hard-coded in UI layer (should be in stored proc or config)
        private const int MaxOvertimeHoursPerPeriod = 80;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                LoadPayPeriods();
                // Load run from URL if provided
                int runId = 0;
                if (int.TryParse(Request.QueryString["runId"], out runId) && runId > 0)
                {
                    hfRunId.Value = runId.ToString();
                    LoadRunDetails(runId);
                    panelRunActions.Visible = true;
                    panelDetail.Visible     = true;
                }
            }
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
                ddlPayPeriod.Items.Clear();
                ddlPayPeriod.Items.Add(new System.Web.UI.WebControls.ListItem("-- Select Pay Period --", ""));
                foreach (DataRow row in dt.Rows)
                {
                    int status = Convert.ToInt32(row["Status"]);
                    string label = row["PeriodName"] + " (" + Convert.ToDateTime(row["PayDate"]).ToString("MMM d") + ")";
                    if (status == 3) label += " [Closed]";
                    ddlPayPeriod.Items.Add(new System.Web.UI.WebControls.ListItem(label, row["PayPeriodId"].ToString()));
                }
                // Select open period from URL if present
                string ppParam = Request.QueryString["ppId"];
                if (!string.IsNullOrEmpty(ppParam))
                {
                    var item = ddlPayPeriod.Items.FindByValue(ppParam);
                    if (item != null) { item.Selected = true; LoadExistingRuns(int.Parse(ppParam)); }
                }
            }
        }

        protected void ddlPayPeriod_Changed(object sender, EventArgs e)
        {
            int ppId = 0;
            if (int.TryParse(ddlPayPeriod.SelectedValue, out ppId) && ppId > 0)
                LoadExistingRuns(ppId);
        }

        private void LoadExistingRuns(int payPeriodId)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Report_PayrollSummary", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FiscalYear",  DateTime.Now.Year);
                cmd.Parameters.AddWithValue("@PayPeriodId", payPeriodId);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                gvExistingRuns.DataSource = dt;
                gvExistingRuns.DataBind();
            }
        }

        protected void btnInitiate_Click(object sender, EventArgs e)
        {
            int ppId = 0;
            if (!int.TryParse(ddlPayPeriod.SelectedValue, out ppId) || ppId == 0)
            {
                litMessage.Text = "<div class='alert alert-error'>Please select a pay period.</div>";
                return;
            }
            int runType = int.Parse(ddlRunType.SelectedValue);
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_Payroll_InitiateRun", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@PayPeriodId", ppId);
                    cmd.Parameters.AddWithValue("@RunType",     runType);
                    cmd.Parameters.AddWithValue("@Notes",       DBNull.Value);
                    cmd.Parameters.AddWithValue("@CreatedBy",   user);
                    var pOut = cmd.Parameters.Add("@NewRunId", SqlDbType.Int);
                    pOut.Direction = ParameterDirection.Output;
                    con.Open();
                    cmd.ExecuteNonQuery();
                    int newRunId = (int)pOut.Value;
                    Response.Redirect("PayrollRun.aspx?runId=" + newRunId + "&ppId=" + ppId);
                }
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Failed to initiate run: " + ex.Message + "</div>";
            }
        }

        protected void btnProcess_Click(object sender, EventArgs e)
        {
            int runId = GetRunId();
            if (runId == 0) return;
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_Payroll_ProcessRun", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 300;
                    cmd.Parameters.AddWithValue("@RunId",       runId);
                    cmd.Parameters.AddWithValue("@ProcessedBy", user);
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                litMessage.Text = "<div class='alert alert-success'>Payroll run processed successfully.</div>";
                LoadRunDetails(runId);
                panelRunActions.Visible = true;
                panelDetail.Visible     = true;
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Processing error: " + ex.Message + "</div>";
            }
        }

        protected void btnApprove_Click(object sender, EventArgs e)
        {
            int runId = GetRunId();
            if (runId == 0) return;
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_Payroll_ApproveRun", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@RunId",      runId);
                    cmd.Parameters.AddWithValue("@ApprovedBy", user);
                    cmd.Parameters.AddWithValue("@Notes",      DBNull.Value);
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                litMessage.Text = "<div class='alert alert-success'>Run approved.</div>";
                LoadRunDetails(runId);
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Approval error: " + ex.Message + "</div>";
            }
        }

        protected void btnPost_Click(object sender, EventArgs e)
        {
            int runId = GetRunId();
            if (runId == 0) return;
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                using (var cmd = new SqlCommand("usp_Payroll_PostRun", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@RunId",    runId);
                    cmd.Parameters.AddWithValue("@PostedBy", user);
                    con.Open();
                    cmd.ExecuteNonQuery();
                }
                litMessage.Text = "<div class='alert alert-success'>Run posted. YTD balances updated.</div>";
                LoadRunDetails(runId);
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Post error: " + ex.Message + "</div>";
            }
        }

        protected void btnVoid_Click(object sender, EventArgs e)
        {
            int runId = GetRunId();
            if (runId == 0) return;
            string user = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Payroll_VoidRun", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@RunId",     runId);
                cmd.Parameters.AddWithValue("@VoidedBy",  user);
                cmd.Parameters.AddWithValue("@VoidReason","Voided via web UI");
                con.Open();
                cmd.ExecuteNonQuery();
            }
            litMessage.Text = "<div class='alert alert-info'>Run voided.</div>";
            LoadRunDetails(runId);
        }

        private void LoadRunDetails(int runId)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_PayrollRun_GetDetails", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@RunId", runId);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var ds = new DataSet();
                da.Fill(ds);
                if (ds.Tables.Count == 0) return;

                // First table = run header
                if (ds.Tables[0].Rows.Count > 0)
                {
                    var row = ds.Tables[0].Rows[0];
                    litRunId.Text     = "Run #" + row["RunId"];
                    litRunStatus.Text = row["StatusLabel"].ToString();
                    litEmpCount.Text   = row["EmployeeCount"].ToString();
                    litTotalGross.Text = Convert.ToDecimal(row["TotalGross"]).ToString("C");
                    litTotalFed.Text   = Convert.ToDecimal(row["TotalFederalTax"]).ToString("C");
                    litTotalState.Text = Convert.ToDecimal(row["TotalStateTax"]).ToString("C");
                    litTotalFICA.Text  = (Convert.ToDecimal(row["TotalSSEmployee"]) + Convert.ToDecimal(row["TotalMedicare"])).ToString("C");
                    litTotalDed.Text   = Convert.ToDecimal(row["TotalDeductions"]).ToString("C");
                    litTotalNet.Text   = Convert.ToDecimal(row["TotalNetPay"]).ToString("C");
                    hfRunId.Value      = row["RunId"].ToString();
                }

                // Second table = employee detail lines
                if (ds.Tables.Count > 1)
                {
                    gvDetail.DataSource = ds.Tables[1];
                    gvDetail.DataBind();
                }
            }
        }

        private int GetRunId()
        {
            int id = 0;
            int.TryParse(hfRunId.Value, out id);
            if (id == 0)
                litMessage.Text = "<div class='alert alert-error'>No active run loaded.</div>";
            return id;
        }
    }
}
