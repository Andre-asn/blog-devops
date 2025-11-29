import os
from dotenv import load_dotenv


class Config:
    """Configuration class to manage application settings"""
    
    # Load environment variables
    load_dotenv()
    
    # Flask Configuration
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    FLASK_ENV = os.environ.get('FLASK_ENV', 'development')
    FLASK_DEBUG = os.environ.get('FLASK_DEBUG', 'True').lower() == 'true'
    
    # MongoDB Configuration
    MONGO_URI = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/')
    DATABASE_NAME = os.environ.get('DATABASE_NAME', 'blog_db')
    COLLECTION_NAME = 'posts'
    
    @classmethod
    def get_mongo_uri(cls) -> str:
        """Get MongoDB connection URI"""
        return cls.MONGO_URI
    
    @classmethod
    def get_database_name(cls) -> str:
        """Get database name"""
        return cls.DATABASE_NAME
    
    @classmethod
    def get_secret_key(cls) -> str:
        """Get Flask secret key"""
        return cls.SECRET_KEY


class TestConfig(Config):
    """Configuration class for testing environment"""
    DATABASE_NAME = 'blog_test_db'

