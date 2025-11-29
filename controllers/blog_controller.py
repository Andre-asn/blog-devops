from flask import Blueprint, render_template, request, redirect, url_for, flash
from datetime import datetime
from repositories.blog_repository import BlogRepository
from models.blog_post import BlogPost


class BlogController:
    """Controller class for blog post routes"""
    
    def __init__(self, repository: BlogRepository):
        """
        Initialize the controller with a repository
        
        Args:
            repository: BlogRepository instance for database operations
        """
        self.repository = repository
        self.blueprint = Blueprint('blog', __name__)
        self._register_routes()
    
    def _register_routes(self):
        """Register all routes for the blog blueprint"""
        self.blueprint.add_url_rule('/', 'index', self.index, methods=['GET'])
        self.blueprint.add_url_rule('/create', 'create_post', self.create_post, 
                                    methods=['GET', 'POST'])
        self.blueprint.add_url_rule('/post/<post_id>', 'view_post', self.view_post, 
                                    methods=['GET'])
    
    def index(self):
        """Handle home page request - displays all blog posts"""
        try:
            posts = self.repository.get_all(sort_by='created_at', order=-1)
            # Convert BlogPost objects to dicts for template rendering
            posts_data = []
            for post in posts:
                post_dict = post.to_dict()
                # Ensure _id is available for template
                if '_id' in post_dict:
                    post_dict['id'] = str(post_dict['_id'])
                posts_data.append(post_dict)
            return render_template('index.html', posts=posts_data)
        except Exception as e:
            flash(f'An error occurred while loading posts: {str(e)}', 'error')
            return render_template('index.html', posts=[])
    
    def create_post(self):
        """Handle blog post creation (GET and POST)"""
        if request.method == 'POST':
            return self._handle_post_creation()
        return render_template('create.html')
    
    def _handle_post_creation(self):
        """Handle POST request for creating a new blog post"""
        title = request.form.get('title', '').strip()
        content = request.form.get('content', '').strip()
        author = request.form.get('author', 'Anonymous').strip() or 'Anonymous'
        
        # Create BlogPost instance
        blog_post = BlogPost(
            title=title,
            content=content,
            author=author
        )
        
        # Validate the post
        is_valid, error_message = blog_post.validate()
        if not is_valid:
            flash(error_message or 'Title and content are required!', 'error')
            return render_template('create.html')
        
        try:
            # Save to database
            post_id = self.repository.create(blog_post)
            flash('Blog post created successfully!', 'success')
            return redirect(url_for('blog.view_post', post_id=post_id))
        except Exception as e:
            flash(f'An error occurred while creating the post: {str(e)}', 'error')
            return render_template('create.html')
    
    def view_post(self, post_id: str):
        """Handle viewing a single blog post"""
        try:
            blog_post = self.repository.get_by_id(post_id)
            
            if not blog_post:
                flash('Post not found!', 'error')
                return redirect(url_for('blog.index'))
            
            # Convert BlogPost to dict for template rendering
            post_data = blog_post.to_dict()
            # Ensure _id is available for template
            if '_id' in post_data:
                post_data['id'] = str(post_data['_id'])
            return render_template('view.html', post=post_data)
        except Exception as e:
            flash('Invalid post ID!', 'error')
            return redirect(url_for('blog.index'))

