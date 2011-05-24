using System.Web.Mvc;
using System.Web.Routing;
using Castle.MicroKernel.Registration;
using Castle.Windsor;
using Component = Castle.MicroKernel.Registration.Component;

namespace MavenThought.MediaLibrary.WebClient
{
    /// <summary>
    /// Main application
    /// </summary>
    public class MediaLibraryApplication : System.Web.HttpApplication
    {
        /// <summary>
        /// Gets the container used
        /// </summary>
        protected IWindsorContainer Container { get; private set; }

        /// <summary>
        /// Registers the routes
        /// </summary>
        /// <param name="routes"></param>
        public static void RegisterRoutes(RouteCollection routes)
        {
            routes.IgnoreRoute("favicon.ico");

            routes.IgnoreRoute("{resource}.axd/{*pathInfo}");

            routes.MapRoute(
                "Default",                                              // Route name
                "{controller}/{action}/{id}",                           // URL with parameters
                new { controller = "Movies", action = "Index", id = string.Empty }); // Parameter defaults
        }

        /// <summary>
        /// Called when the application starts
        /// </summary>
        protected void Application_Start()
        {
            // Add nhaml engine
           // ViewEngines.Engines.Add(new NHamlMvcViewEngine());

            // Setup IoC container
            this.SetupContainer();

            // Register the routes
            RegisterRoutes(RouteTable.Routes);
        }

        /// <summary>
        /// Setup the IoC container and register needed types
        /// </summary>
        private void SetupContainer()
        {
            this.Container = new WindsorContainer();

            this.Container.Register(
                Component.For<IControllerFactory>().ImplementedBy<WindsorControllerFactory>(),
                Component.For<IWindsorContainer>().Instance(this.Container),
                AllTypes
                    .FromThisAssembly()
                    .BasedOn<Controller>()
                    .Configure(reg => reg.LifeStyle.Transient));
        }
    }
}