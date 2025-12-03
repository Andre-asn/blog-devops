from flask import Flask
from config import Config
from repositories.database import DatabaseConnection
from repositories.blog_repository import BlogRepository
from controllers.blog_controller import BlogController
from monitoring.metrics import metrics_endpoint, update_blog_posts_count


class BlogApplication:
    """Main application class following Application Factory pattern"""
    
    def __init__(self, config_class=Config, repository=None):
        """
        Initialize the blog application
        
        Args:
            config_class: Configuration class to use (default: Config)
            repository: Optional BlogRepository instance (for testing)
        """
        self.config = config_class
        self.app = Flask(__name__)
        self.db_connection = None
        self.blog_repository = repository
        self.blog_controller = None
        self._setup()
    
    def _setup(self):
        """Setup the Flask application with configuration and routes"""
        # Configure Flask app
        self.app.config['SECRET_KEY'] = self.config.get_secret_key()
        self.app.config['DEBUG'] = self.config.FLASK_DEBUG
        self.app.config['ENV'] = self.config.FLASK_ENV
        
        # Setup database connection if repository not provided
        if not self.blog_repository:
            self.db_connection = DatabaseConnection(
                mongo_uri=self.config.get_mongo_uri(),
                database_name=self.config.get_database_name()
            )
            posts_collection = self.db_connection.get_collection(self.config.COLLECTION_NAME)
            self.blog_repository = BlogRepository(posts_collection)
        
        # Setup controllers and register blueprints
        self.blog_controller = BlogController(self.blog_repository)
        self.app.register_blueprint(self.blog_controller.blueprint)
        
        # Register metrics endpoint
        self.app.add_url_rule('/metrics', 'metrics', metrics_endpoint)
        
        # Register health check endpoint
        @self.app.route('/health')
        def health_check():
            return {'status': 'healthy', 'service': 'blog-app'}, 200
        
        @self.app.route('/hello')
        def hello():
            return {'message': 'Hello, world!'}, 200
        
        # Update metrics on startup
        if self.blog_repository:
            update_blog_posts_count(self.blog_repository)
        
        # Store repository reference for testing
        self.app.extensions['blog_repository'] = self.blog_repository
    
    def get_app(self) -> Flask:
        """Get the Flask application instance"""
        return self.app
    
    def close(self):
        """Close database connections"""
        if self.db_connection:
            self.db_connection.close()


def create_app(config_class=Config, repository=None) -> Flask:
    """
    Application factory function to create Flask app instance
    
    Args:
        config_class: Configuration class to use
        repository: Optional BlogRepository instance (for testing)
        
    Returns:
        Flask application instance
    """
    blog_app = BlogApplication(config_class, repository)
    return blog_app.get_app()


# Create the application instance
app = create_app()


if __name__ == '__main__':
    app.run(debug=Config.FLASK_DEBUG, host='0.0.0.0', port=5000)
