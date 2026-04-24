using System;
using System.Web;
using System.Web.Routing;

namespace PayrollWeb
{
    public class Global : HttpApplication
    {
        void Application_Start(object sender, EventArgs e)
        {
            // Legacy: no DI container, no middleware pipeline
        }

        void Session_Start(object sender, EventArgs e)
        {
            // Default session user for demo (production would use Windows auth principal)
            if (Session["CurrentUser"] == null)
                Session["CurrentUser"] = "DEMO\\payroll_admin";
        }

        void Application_Error(object sender, EventArgs e)
        {
            // Legacy: errors swallowed or written to Response -- no structured logging
            Exception ex = Server.GetLastError();
            System.Diagnostics.Debug.WriteLine("Unhandled error: " + ex?.Message);
        }
    }
}
