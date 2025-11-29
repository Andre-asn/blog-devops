import pytest
from pymongo import MongoClient
from datetime import datetime, timezone
import os
from config import TestConfig
from repositories.blog_repository import BlogRepository
from app import create_app

# Test database configuration
TEST_DATABASE_NAME = 'blog_test_db'


@pytest.fixture
def test_db():
    """Fixture to set up and tear down test database"""
    # Get test database connection
    mongo_uri = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/')
    client = MongoClient(mongo_uri)
    db = client[TEST_DATABASE_NAME]
    collection = db.posts
    
    # Clear the collection before each test
    collection.delete_many({})
    
    yield collection
    
    # Clean up after test
    collection.delete_many({})
    client.drop_database(TEST_DATABASE_NAME)


@pytest.fixture
def repository(test_db):
    """Create a BlogRepository instance for testing"""
    return BlogRepository(test_db)


@pytest.fixture
def app_instance(repository):
    """Create Flask app instance with test configuration and repository"""
    app = create_app(TestConfig, repository)
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-secret-key'
    yield app


@pytest.fixture
def client(app_instance):
    """Create a test client for the Flask app"""
    with app_instance.test_client() as client:
        yield client


@pytest.fixture
def sample_post(test_db):
    """Create a sample blog post for testing (raw dict format)"""
    post = {
        'title': 'Test Blog Post',
        'content': 'This is a test blog post content.',
        'author': 'Test Author',
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc)
    }
    result = test_db.insert_one(post)
    post['_id'] = result.inserted_id
    return post


@pytest.fixture
def sample_post_oop(repository):
    """Create a sample blog post using the repository (OOP approach)"""
    from models.blog_post import BlogPost
    post = BlogPost(
        title='Test Blog Post OOP',
        content='This is a test blog post created via repository.',
        author='Test Author OOP'
    )
    post_id = repository.create(post)
    # Retrieve to get the full post with ID
    return repository.get_by_id(post_id)


@pytest.fixture
def multiple_posts(test_db):
    """Create multiple sample blog posts for testing"""
    posts = [
        {
            'title': 'First Post',
            'content': 'Content of first post',
            'author': 'Author One',
            'created_at': datetime(2024, 1, 1, 12, 0, 0),
            'updated_at': datetime(2024, 1, 1, 12, 0, 0)
        },
        {
            'title': 'Second Post',
            'content': 'Content of second post',
            'author': 'Author Two',
            'created_at': datetime(2024, 1, 2, 12, 0, 0),
            'updated_at': datetime(2024, 1, 2, 12, 0, 0)
        },
        {
            'title': 'Third Post',
            'content': 'Content of third post',
            'author': 'Author Three',
            'created_at': datetime(2024, 1, 3, 12, 0, 0),
            'updated_at': datetime(2024, 1, 3, 12, 0, 0)
        }
    ]
    inserted_ids = test_db.insert_many(posts).inserted_ids
    for i, post in enumerate(posts):
        post['_id'] = inserted_ids[i]
    return posts
