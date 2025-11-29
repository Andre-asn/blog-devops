import pytest
from bson import ObjectId
from models.blog_post import BlogPost


class TestIndexRoute:
    """Tests for the home page (index route)"""
    
    def test_index_empty_database(self, client):
        """Test home page with no blog posts"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'No blog posts yet' in response.data or b'Create Your First Post' in response.data
    
    def test_index_with_posts(self, client, multiple_posts):
        """Test home page displays all blog posts"""
        response = client.get('/')
        assert response.status_code == 200
        
        # Check that all posts are displayed
        for post in multiple_posts:
            assert post['title'].encode() in response.data
            assert post['author'].encode() in response.data
        
        # Check that posts are in reverse chronological order (newest first)
        # Third post (created on Jan 3) should appear before Second (Jan 2) before First (Jan 1)
        content = response.data.decode()
        third_pos = content.find(multiple_posts[2]['title'])
        second_pos = content.find(multiple_posts[1]['title'])
        first_pos = content.find(multiple_posts[0]['title'])
        
        # All should be found
        assert third_pos != -1
        assert second_pos != -1
        assert first_pos != -1
        
        # Third post appears before second, which appears before first
        assert third_pos < second_pos < first_pos


class TestCreatePostRoute:
    """Tests for the create post route"""
    
    def test_create_post_get(self, client):
        """Test GET request to create post page"""
        response = client.get('/create')
        assert response.status_code == 200
        assert b'Create New Blog Post' in response.data
        assert b'Title' in response.data
        assert b'Content' in response.data
    
    def test_create_post_success(self, client, repository):
        """Test successfully creating a new blog post"""
        response = client.post('/create', data={
            'title': 'New Test Post',
            'content': 'This is the content of the new test post.',
            'author': 'Test Author'
        }, follow_redirects=True)
        
        assert response.status_code == 200
        
        # Check that post was created using the repository
        posts = repository.get_all()
        assert len(posts) == 1
        
        created_post = posts[0]
        assert isinstance(created_post, BlogPost)
        assert created_post.title == 'New Test Post'
        assert created_post.content == 'This is the content of the new test post.'
        assert created_post.author == 'Test Author'
        
        # Check success message
        assert b'successfully' in response.data.lower() or b'success' in response.data.lower()
    
    def test_create_post_without_title(self, client, repository):
        """Test creating post without title should fail"""
        response = client.post('/create', data={
            'content': 'Content without title',
            'author': 'Test Author'
        })
        
        assert response.status_code == 200
        assert b'required' in response.data.lower() or b'error' in response.data.lower()
        
        # Check that no post was created
        posts = repository.get_all()
        assert len(posts) == 0
    
    def test_create_post_without_content(self, client, repository):
        """Test creating post without content should fail"""
        response = client.post('/create', data={
            'title': 'Title without content',
            'author': 'Test Author'
        })
        
        assert response.status_code == 200
        assert b'required' in response.data.lower() or b'error' in response.data.lower()
        
        # Check that no post was created
        posts = repository.get_all()
        assert len(posts) == 0
    
    def test_create_post_anonymous_author(self, client, repository):
        """Test creating post without author name defaults to Anonymous"""
        response = client.post('/create', data={
            'title': 'Post with Anonymous Author',
            'content': 'Content here'
        }, follow_redirects=True)
        
        assert response.status_code == 200
        
        # Check that post was created with Anonymous author using repository
        posts = repository.get_all()
        assert len(posts) == 1
        assert posts[0].author == 'Anonymous'


class TestViewPostRoute:
    """Tests for the view post route"""
    
    def test_view_post_success(self, client, sample_post):
        """Test viewing an existing blog post"""
        post_id = str(sample_post['_id'])
        response = client.get(f'/post/{post_id}')
        
        assert response.status_code == 200
        assert sample_post['title'].encode() in response.data
        assert sample_post['content'].encode() in response.data
        assert sample_post['author'].encode() in response.data
    
    def test_view_post_not_found(self, client):
        """Test viewing a non-existent post"""
        fake_id = str(ObjectId())
        response = client.get(f'/post/{fake_id}', follow_redirects=True)
        
        assert response.status_code == 200
        assert b'not found' in response.data.lower() or b'error' in response.data.lower()
    
    def test_view_post_invalid_id(self, client):
        """Test viewing a post with invalid ID format"""
        response = client.get('/post/invalid-id-123', follow_redirects=True)
        
        assert response.status_code == 200
        assert b'invalid' in response.data.lower() or b'error' in response.data.lower()


class TestNavigation:
    """Tests for navigation and page links"""
    
    def test_navigation_links(self, client):
        """Test that navigation links are present"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Home' in response.data
        assert b'New Post' in response.data
    
    def test_back_to_home_link(self, client, sample_post):
        """Test back to home link on post view page"""
        post_id = str(sample_post['_id'])
        response = client.get(f'/post/{post_id}')
        assert response.status_code == 200
        assert b'Back to all posts' in response.data or b'Home' in response.data


class TestBlogPostModel:
    """Tests for the BlogPost model class"""
    
    def test_blog_post_creation(self):
        """Test creating a BlogPost instance"""
        post = BlogPost(
            title='Test Title',
            content='Test Content',
            author='Test Author'
        )
        
        assert post.title == 'Test Title'
        assert post.content == 'Test Content'
        assert post.author == 'Test Author'
        assert post._id is None  # New post has no ID yet
    
    def test_blog_post_validation_success(self):
        """Test BlogPost validation with valid data"""
        post = BlogPost(
            title='Valid Title',
            content='Valid Content',
            author='Author'
        )
        
        is_valid, error = post.validate()
        assert is_valid is True
        assert error is None
    
    def test_blog_post_validation_empty_title(self):
        """Test BlogPost validation with empty title"""
        post = BlogPost(
            title='',
            content='Valid Content',
            author='Author'
        )
        
        is_valid, error = post.validate()
        assert is_valid is False
        assert 'required' in error.lower()
    
    def test_blog_post_validation_empty_content(self):
        """Test BlogPost validation with empty content"""
        post = BlogPost(
            title='Valid Title',
            content='',
            author='Author'
        )
        
        is_valid, error = post.validate()
        assert is_valid is False
        assert 'required' in error.lower()
    
    def test_blog_post_to_dict(self):
        """Test converting BlogPost to dictionary"""
        post = BlogPost(
            title='Test Title',
            content='Test Content',
            author='Test Author'
        )
        
        post_dict = post.to_dict()
        
        assert post_dict['title'] == 'Test Title'
        assert post_dict['content'] == 'Test Content'
        assert post_dict['author'] == 'Test Author'
        assert 'created_at' in post_dict
        assert 'updated_at' in post_dict
    
    def test_blog_post_from_dict(self):
        """Test creating BlogPost from dictionary"""
        from datetime import datetime, timezone
        
        post_dict = {
            '_id': ObjectId(),
            'title': 'From Dict Title',
            'content': 'From Dict Content',
            'author': 'From Dict Author',
            'created_at': datetime.now(timezone.utc),
            'updated_at': datetime.now(timezone.utc)
        }
        
        post = BlogPost.from_dict(post_dict)
        
        assert post.title == 'From Dict Title'
        assert post.content == 'From Dict Content'
        assert post.author == 'From Dict Author'
        assert post._id == post_dict['_id']


class TestBlogRepository:
    """Tests for the BlogRepository class"""
    
    def test_repository_create(self, repository):
        """Test creating a post through repository"""
        post = BlogPost(
            title='Repository Test',
            content='Repository Content',
            author='Repository Author'
        )
        
        post_id = repository.create(post)
        assert post_id is not None
        
        # Retrieve and verify
        retrieved = repository.get_by_id(post_id)
        assert retrieved is not None
        assert retrieved.title == 'Repository Test'
        assert retrieved.content == 'Repository Content'
    
    def test_repository_get_all(self, repository):
        """Test retrieving all posts through repository"""
        # Create multiple posts
        post1 = BlogPost(title='Post 1', content='Content 1', author='Author 1')
        post2 = BlogPost(title='Post 2', content='Content 2', author='Author 2')
        
        repository.create(post1)
        repository.create(post2)
        
        all_posts = repository.get_all()
        assert len(all_posts) == 2
        assert all(isinstance(p, BlogPost) for p in all_posts)
    
    def test_repository_get_by_id_not_found(self, repository):
        """Test repository get_by_id returns None for non-existent post"""
        fake_id = str(ObjectId())
        result = repository.get_by_id(fake_id)
        assert result is None
    
    def test_repository_get_by_id_invalid(self, repository):
        """Test repository get_by_id handles invalid ID format"""
        result = repository.get_by_id('invalid-id')
        assert result is None
    
    def test_repository_count(self, repository):
        """Test repository count method"""
        assert repository.count() == 0
        
        post = BlogPost(title='Count Test', content='Content', author='Author')
        repository.create(post)
        
        assert repository.count() == 1
