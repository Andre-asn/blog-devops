from flask import Flask, render_template, request, redirect, url_for, flash
from pymongo import MongoClient
from datetime import datetime
import os
from bson import ObjectId
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# MongoDB connection
MONGO_URI = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/')
DATABASE_NAME = os.environ.get('DATABASE_NAME', 'blog_db')

client = MongoClient(MONGO_URI)
db = client[DATABASE_NAME]
posts_collection = db.posts


@app.route('/')
def index():
    """Home page - displays all blog posts"""
    posts = list(posts_collection.find().sort('created_at', -1))
    return render_template('index.html', posts=posts)


@app.route('/create', methods=['GET', 'POST'])
def create_post():
    """Blog post creation page"""
    if request.method == 'POST':
        title = request.form.get('title')
        content = request.form.get('content')
        author = request.form.get('author', 'Anonymous')
        
        if not title or not content:
            flash('Title and content are required!', 'error')
            return render_template('create.html')
        
        post = {
            'title': title,
            'content': content,
            'author': author,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        result = posts_collection.insert_one(post)
        flash('Blog post created successfully!', 'success')
        return redirect(url_for('view_post', post_id=str(result.inserted_id)))
    
    return render_template('create.html')


@app.route('/post/<post_id>')
def view_post(post_id):
    """View a single blog post"""
    try:
        post = posts_collection.find_one({'_id': ObjectId(post_id)})
        if not post:
            flash('Post not found!', 'error')
            return redirect(url_for('index'))
        return render_template('view.html', post=post)
    except Exception as e:
        flash('Invalid post ID!', 'error')
        return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
