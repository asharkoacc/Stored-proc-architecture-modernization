using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace PayrollWeb
{
    public partial class EmployeeDetail : Page
    {
        private static readonly string _conn = ConfigurationManager.ConnectionStrings["PayrollDB"].ConnectionString;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                LoadLookups();
                int id = 0;
                if (int.TryParse(Request.QueryString["id"], out id) && id > 0)
                {
                    hfEmployeeId.Value = id.ToString();
                    LoadEmployee(id);
                    litPageTitle.Text   = "Edit Employee";
                    btnTerminate.Visible = true;
                    terminateDiv.Visible = true;
                }
            }
        }

        private void LoadLookups()
        {
            using (var con = new SqlConnection(_conn))
            {
                con.Open();
                using (var cmd = new SqlCommand("usp_Department_GetAll", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    var da = new SqlDataAdapter(cmd);
                    var dt = new DataTable();
                    da.Fill(dt);
                    ddlDepartment.DataSource     = dt;
                    ddlDepartment.DataTextField  = "DepartmentName";
                    ddlDepartment.DataValueField = "DepartmentId";
                    ddlDepartment.DataBind();
                    ddlDepartment.Items.Insert(0, new ListItem("-- Select Department --", ""));
                }
                using (var cmd = new SqlCommand("usp_PayGrade_GetAll", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    var da = new SqlDataAdapter(cmd);
                    var dt = new DataTable();
                    da.Fill(dt);
                    ddlPayGrade.DataSource     = dt;
                    ddlPayGrade.DataTextField  = "GradeTitle";
                    ddlPayGrade.DataValueField = "PayGradeId";
                    ddlPayGrade.DataBind();
                    ddlPayGrade.Items.Insert(0, new ListItem("-- Select Grade --", ""));
                }
            }
        }

        private void LoadEmployee(int id)
        {
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Employee_GetById", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@EmployeeId", id);
                con.Open();
                var da = new SqlDataAdapter(cmd);
                var dt = new DataTable();
                da.Fill(dt);
                if (dt.Rows.Count == 0) { Response.Redirect("Employees.aspx"); return; }
                var row = dt.Rows[0];
                txtEmpNumber.Text = row["EmployeeNumber"].ToString();
                txtFirstName.Text = row["FirstName"].ToString();
                txtMiddleName.Text = row["MiddleName"]?.ToString() ?? "";
                txtLastName.Text  = row["LastName"].ToString();
                txtSSN.Text       = row["SSN"].ToString();
                txtDOB.Text       = Convert.ToDateTime(row["DateOfBirth"]).ToString("yyyy-MM-dd");
                txtEmail.Text     = row["Email"]?.ToString() ?? "";
                txtPhone.Text     = row["Phone"]?.ToString() ?? "";
                txtAddress.Text   = row["Address1"]?.ToString() ?? "";
                txtCity.Text      = row["City"]?.ToString() ?? "";
                txtStateAddr.Text = row["StateAddr"]?.ToString() ?? "";
                txtZip.Text       = row["Zip"]?.ToString() ?? "";
                txtHireDate.Text  = Convert.ToDateTime(row["HireDate"]).ToString("yyyy-MM-dd");
                txtTitle.Text     = row["PositionTitle"].ToString();
                txtSalary.Text    = Convert.ToDecimal(row["AnnualSalary"]).ToString("F2");
                txtHourlyRate.Text = row["HourlyRate"] == DBNull.Value ? "" : Convert.ToDecimal(row["HourlyRate"]).ToString("F4");
                txtAllowances.Text = row["FederalAllowances"].ToString();
                txtStateCode.Text  = row["StateCode"].ToString();
                txtWorkState.Text  = row["WorkState"].ToString();
                SetDropDown(ddlPayFrequency, row["PayFrequency"].ToString());
                SetDropDown(ddlFilingStatus, row["FilingStatus"].ToString());
                SetDropDown(ddlEmpType,  row["EmploymentType"].ToString());
                SetDropDown(ddlDepartment, row["DepartmentId"].ToString());
                SetDropDown(ddlPayGrade,   row["PayGradeId"].ToString());
                CalculateEstimatedTax();
            }
        }

        private void SetDropDown(DropDownList ddl, string value)
        {
            var item = ddl.Items.FindByValue(value);
            if (item != null) item.Selected = true;
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!ValidateForm()) return;
            int id = int.Parse(hfEmployeeId.Value);
            string currentUser = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            try
            {
                using (var con = new SqlConnection(_conn))
                {
                    con.Open();
                    if (id == 0)
                    {
                        var cmd = new SqlCommand("usp_Employee_Insert", con);
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@EmployeeNumber", txtEmpNumber.Text.Trim());
                        cmd.Parameters.AddWithValue("@FirstName",      txtFirstName.Text.Trim());
                        cmd.Parameters.AddWithValue("@LastName",       txtLastName.Text.Trim());
                        cmd.Parameters.AddWithValue("@MiddleName",     string.IsNullOrEmpty(txtMiddleName.Text) ? (object)DBNull.Value : txtMiddleName.Text.Trim());
                        cmd.Parameters.AddWithValue("@SSN",            txtSSN.Text.Trim());
                        cmd.Parameters.AddWithValue("@DateOfBirth",    DateTime.Parse(txtDOB.Text));
                        cmd.Parameters.AddWithValue("@HireDate",       DateTime.Parse(txtHireDate.Text));
                        cmd.Parameters.AddWithValue("@DepartmentId",   int.Parse(ddlDepartment.SelectedValue));
                        cmd.Parameters.AddWithValue("@PayGradeId",     int.Parse(ddlPayGrade.SelectedValue));
                        cmd.Parameters.AddWithValue("@PositionTitle",  txtTitle.Text.Trim());
                        cmd.Parameters.AddWithValue("@AnnualSalary",   decimal.Parse(txtSalary.Text));
                        cmd.Parameters.AddWithValue("@HourlyRate",     string.IsNullOrEmpty(txtHourlyRate.Text) ? (object)DBNull.Value : decimal.Parse(txtHourlyRate.Text));
                        cmd.Parameters.AddWithValue("@PayFrequency",   ddlPayFrequency.SelectedValue);
                        cmd.Parameters.AddWithValue("@FilingStatus",   ddlFilingStatus.SelectedValue);
                        cmd.Parameters.AddWithValue("@FederalAllowances", int.Parse(txtAllowances.Text));
                        cmd.Parameters.AddWithValue("@StateCode",      txtStateCode.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@WorkState",      txtWorkState.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@EmploymentType", int.Parse(ddlEmpType.SelectedValue));
                        cmd.Parameters.AddWithValue("@Email",          string.IsNullOrEmpty(txtEmail.Text) ? (object)DBNull.Value : txtEmail.Text.Trim());
                        cmd.Parameters.AddWithValue("@Phone",          string.IsNullOrEmpty(txtPhone.Text) ? (object)DBNull.Value : txtPhone.Text.Trim());
                        cmd.Parameters.AddWithValue("@Address1",       string.IsNullOrEmpty(txtAddress.Text) ? (object)DBNull.Value : txtAddress.Text.Trim());
                        cmd.Parameters.AddWithValue("@City",           string.IsNullOrEmpty(txtCity.Text) ? (object)DBNull.Value : txtCity.Text.Trim());
                        cmd.Parameters.AddWithValue("@StateAddr",      string.IsNullOrEmpty(txtStateAddr.Text) ? (object)DBNull.Value : (object)txtStateAddr.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@Zip",            string.IsNullOrEmpty(txtZip.Text) ? (object)DBNull.Value : txtZip.Text.Trim());
                        cmd.Parameters.AddWithValue("@CreatedBy",      currentUser);
                        var newId = cmd.Parameters.Add("@NewEmployeeId", SqlDbType.Int);
                        newId.Direction = ParameterDirection.Output;
                        cmd.ExecuteNonQuery();
                        int createdId = (int)newId.Value;
                        Response.Redirect("EmployeeDetail.aspx?id=" + createdId + "&saved=1");
                    }
                    else
                    {
                        var cmd = new SqlCommand("usp_Employee_Update", con);
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@EmployeeId",    id);
                        cmd.Parameters.AddWithValue("@FirstName",     txtFirstName.Text.Trim());
                        cmd.Parameters.AddWithValue("@LastName",      txtLastName.Text.Trim());
                        cmd.Parameters.AddWithValue("@MiddleName",    string.IsNullOrEmpty(txtMiddleName.Text) ? (object)DBNull.Value : txtMiddleName.Text.Trim());
                        cmd.Parameters.AddWithValue("@DepartmentId",  int.Parse(ddlDepartment.SelectedValue));
                        cmd.Parameters.AddWithValue("@PayGradeId",    int.Parse(ddlPayGrade.SelectedValue));
                        cmd.Parameters.AddWithValue("@PositionTitle", txtTitle.Text.Trim());
                        cmd.Parameters.AddWithValue("@AnnualSalary",  decimal.Parse(txtSalary.Text));
                        cmd.Parameters.AddWithValue("@HourlyRate",    string.IsNullOrEmpty(txtHourlyRate.Text) ? (object)DBNull.Value : decimal.Parse(txtHourlyRate.Text));
                        cmd.Parameters.AddWithValue("@PayFrequency",  ddlPayFrequency.SelectedValue);
                        cmd.Parameters.AddWithValue("@FilingStatus",  ddlFilingStatus.SelectedValue);
                        cmd.Parameters.AddWithValue("@FederalAllowances", int.Parse(txtAllowances.Text));
                        cmd.Parameters.AddWithValue("@StateCode",     txtStateCode.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@WorkState",     txtWorkState.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@EmploymentType",int.Parse(ddlEmpType.SelectedValue));
                        cmd.Parameters.AddWithValue("@Email",         string.IsNullOrEmpty(txtEmail.Text) ? (object)DBNull.Value : txtEmail.Text.Trim());
                        cmd.Parameters.AddWithValue("@Phone",         string.IsNullOrEmpty(txtPhone.Text) ? (object)DBNull.Value : txtPhone.Text.Trim());
                        cmd.Parameters.AddWithValue("@Address1",      string.IsNullOrEmpty(txtAddress.Text) ? (object)DBNull.Value : txtAddress.Text.Trim());
                        cmd.Parameters.AddWithValue("@City",          string.IsNullOrEmpty(txtCity.Text) ? (object)DBNull.Value : txtCity.Text.Trim());
                        cmd.Parameters.AddWithValue("@StateAddr",     string.IsNullOrEmpty(txtStateAddr.Text) ? (object)DBNull.Value : (object)txtStateAddr.Text.Trim().ToUpper());
                        cmd.Parameters.AddWithValue("@Zip",           string.IsNullOrEmpty(txtZip.Text) ? (object)DBNull.Value : txtZip.Text.Trim());
                        cmd.Parameters.AddWithValue("@ModifiedBy",    currentUser);
                        cmd.ExecuteNonQuery();
                        litMessage.Text = "<div class='alert alert-success'>Employee updated successfully.</div>";
                    }
                }
            }
            catch (Exception ex)
            {
                litMessage.Text = "<div class='alert alert-error'>Error saving employee: " + ex.Message + "</div>";
            }
        }

        protected void btnEstimate_Click(object sender, EventArgs e)
        {
            CalculateEstimatedTax();
        }

        // LEGACY: Tax calculation logic duplicated here from usp_Tax_CalculateFederal / usp_Tax_CalculateState.
        // Any change to tax brackets requires updating BOTH the stored procedures AND this method.
        private void CalculateEstimatedTax()
        {
            decimal salary = 0;
            if (!decimal.TryParse(txtSalary.Text, out salary) || salary <= 0) return;
            string filing = ddlFilingStatus.SelectedValue;
            string state  = txtWorkState.Text.Trim().ToUpper();
            int periodsPerYear = ddlPayFrequency.SelectedValue == "Weekly" ? 52
                               : ddlPayFrequency.SelectedValue == "SemiMonthly" ? 24
                               : ddlPayFrequency.SelectedValue == "Monthly" ? 12 : 26;

            decimal perPeriodGross = salary / periodsPerYear;

            // Federal tax -- 2024 brackets hard-coded (duplicated from FederalTaxBrackets table)
            decimal annualFed = 0;
            if (filing == "Single")
            {
                if      (salary <= 11600)  annualFed = salary * 0.10m;
                else if (salary <= 47150)  annualFed = 1160m  + (salary - 11600) * 0.12m;
                else if (salary <= 100525) annualFed = 5426m  + (salary - 47150) * 0.22m;
                else if (salary <= 191950) annualFed = 17168.50m + (salary - 100525) * 0.24m;
                else if (salary <= 243725) annualFed = 39110.50m + (salary - 191950) * 0.32m;
                else if (salary <= 609350) annualFed = 55678.50m + (salary - 243725) * 0.35m;
                else                       annualFed = 183647.25m + (salary - 609350) * 0.37m;
            }
            else  // Married
            {
                if      (salary <= 23200)  annualFed = salary * 0.10m;
                else if (salary <= 94300)  annualFed = 2320m  + (salary - 23200) * 0.12m;
                else if (salary <= 201050) annualFed = 10852m + (salary - 94300) * 0.22m;
                else if (salary <= 383900) annualFed = 34337m + (salary - 201050) * 0.24m;
                else if (salary <= 487450) annualFed = 78221m + (salary - 383900) * 0.32m;
                else if (salary <= 731200) annualFed = 111357m + (salary - 487450) * 0.35m;
                else                       annualFed = 196669.50m + (salary - 731200) * 0.37m;
            }
            decimal perPeriodFed = Math.Round(annualFed / periodsPerYear, 2);

            // State tax -- flat rate table hard-coded (duplicated from StateTaxRates)
            decimal stateRate = 0m;
            decimal stateStdDed = 0m;
            switch (state)
            {
                case "CA": stateRate = 0.0930m; stateStdDed = 5202m;  break;
                case "NY": stateRate = 0.0685m; stateStdDed = 8000m;  break;
                case "IL": stateRate = 0.0495m; stateStdDed = 2425m;  break;
                case "GA": stateRate = 0.0549m; stateStdDed = 5400m;  break;
                case "OH": stateRate = 0.0399m; stateStdDed = 2400m;  break;
                default:   stateRate = 0m;      stateStdDed = 0m;     break; // TX, FL, WA = no income tax
            }
            decimal annualState = salary > stateStdDed ? (salary - stateStdDed) * stateRate : 0m;
            decimal perPeriodState = Math.Round(annualState / periodsPerYear, 2);

            // FICA -- magic numbers: 0.062 SS + 0.0145 Medicare
            decimal perPeriodFICA = Math.Round(perPeriodGross * (0.062m + 0.0145m), 2);

            litEstFedTax.Text   = perPeriodFed.ToString("C");
            litEstStateTax.Text = perPeriodState.ToString("C");
            litEstFICA.Text     = perPeriodFICA.ToString("C");
        }

        protected void btnTerminate_Click(object sender, EventArgs e)
        {
            int id = int.Parse(hfEmployeeId.Value);
            if (id == 0) return;
            if (string.IsNullOrEmpty(txtTermDate.Text)) { litMessage.Text = "<div class='alert alert-error'>Termination date is required.</div>"; return; }
            string currentUser = Session["CurrentUser"]?.ToString() ?? "SYSTEM";
            using (var con = new SqlConnection(_conn))
            using (var cmd = new SqlCommand("usp_Employee_Terminate", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@EmployeeId",      id);
                cmd.Parameters.AddWithValue("@TerminationDate", DateTime.Parse(txtTermDate.Text));
                cmd.Parameters.AddWithValue("@Reason",          string.IsNullOrEmpty(txtTermReason.Text) ? (object)DBNull.Value : txtTermReason.Text.Trim());
                cmd.Parameters.AddWithValue("@FinalPayBonus",   0);
                cmd.Parameters.AddWithValue("@ProcessedBy",     currentUser);
                con.Open();
                cmd.ExecuteNonQuery();
            }
            Response.Redirect("Employees.aspx");
        }

        private bool ValidateForm()
        {
            if (string.IsNullOrEmpty(txtFirstName.Text) || string.IsNullOrEmpty(txtLastName.Text) ||
                string.IsNullOrEmpty(txtHireDate.Text) || string.IsNullOrEmpty(txtSalary.Text) ||
                ddlDepartment.SelectedValue == "" || ddlPayGrade.SelectedValue == "")
            {
                litMessage.Text = "<div class='alert alert-error'>Please fill in all required fields (*).</div>";
                return false;
            }
            decimal salary;
            if (!decimal.TryParse(txtSalary.Text, out salary) || salary <= 0)
            {
                litMessage.Text = "<div class='alert alert-error'>Annual salary must be a positive number.</div>";
                return false;
            }
            return true;
        }
    }
}
