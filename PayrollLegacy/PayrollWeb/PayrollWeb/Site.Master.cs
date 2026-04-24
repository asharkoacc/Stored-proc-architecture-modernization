using System;
using System.Web.UI;

namespace PayrollWeb
{
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            litUser.Text = Session["CurrentUser"]?.ToString() ?? "Unknown";
        }
    }
}
