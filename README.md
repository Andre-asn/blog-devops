# Blog DevOps Project

A blog website built with Flask and MongoDB, designed with DevOps practices in mind.

## Features

- **Home Page**: View all blog posts in reverse chronological order
- **Create Post**: Create new blog posts with title, author, and content
- **View Post**: Read individual blog posts in detail

## Tech Stack

- **Backend**: Python Flask with Object-Oriented Design
- **Database**: MongoDB
- **Frontend**: Flask Templates (HTML/CSS)
- **Architecture**: MVC pattern with Repository pattern
- **Testing**: Pytest ✅

## Architecture

This project follows **Object-Oriented Design** principles:

- **Models** (`models/`): Domain entities (BlogPost class)
- **Repositories** (`repositories/`): Data access layer (BlogRepository, DatabaseConnection)
- **Controllers** (`controllers/`): Request handlers (BlogController with Flask Blueprint)
- **Configuration** (`config.py`): Configuration management classes
- **Application Factory**: `BlogApplication` class for app initialization 

## Prerequisites

- Python 3.8 or higher
- MongoDB (local or remote instance)
- pip (Python package manager)

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd blog-devops
   ```

2. **Create a virtual environment**
   ```bash
   python -m venv venv
   
   # On Windows
   venv\Scripts\activate
   
   # On macOS/Linux
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**
   ```bash
   # On Windows
   copy env.example .env
   
   # On macOS/Linux
   cp env.example .env
   ```
   
   Edit `.env` and configure:
   - `SECRET_KEY`: A random secret key for Flask sessions
   - `MONGO_URI`: Your MongoDB connection string (default: `mongodb://localhost:27017/`)
   - `DATABASE_NAME`: Name of your MongoDB database (default: `blog_db`)

5. **Start MongoDB**
   
   If using a local MongoDB instance:
   ```bash
   # Make sure MongoDB is running on your system
   # On Windows: MongoDB should start as a service
   # On macOS with Homebrew: brew services start mongodb-community
   # On Linux: sudo systemctl start mongod
   ```

6. **Run the application**
   ```bash
   python app.py
   ```

   The application will be available at `http://localhost:5000`

## Project Structure

```
blog-devops/
├── app.py                 # Main Flask application (Application Factory)
├── config.py             # Configuration classes
├── conftest.py           # Pytest configuration and fixtures
├── pytest.ini            # Pytest settings
├── requirements.txt       # Python dependencies
├── env.example            # Environment variables template
├── .gitignore            # Git ignore file
├── README.md             # This file
├── models/               # Data models (OOP)
│   ├── __init__.py
│   └── blog_post.py      # BlogPost model class
├── repositories/         # Data access layer (Repository pattern)
│   ├── __init__.py
│   ├── database.py       # DatabaseConnection class
│   └── blog_repository.py # BlogRepository class
├── controllers/          # Request handlers (MVC pattern)
│   ├── __init__.py
│   └── blog_controller.py # BlogController class with Blueprint
├── templates/            # Flask HTML templates
│   ├── base.html         # Base template
│   ├── index.html        # Home page
│   ├── create.html       # Create post page
│   └── view.html         # View post page
└── tests/                # Test files
    ├── __init__.py       # Test package init
    └── test_routes.py    # Route tests
```

## Usage

1. **View all posts**: Navigate to the home page (`/`)
2. **Create a post**: Click "New Post" in the navigation or go to `/create`
3. **View a post**: Click on any post title or "Read More" button

## Environment Variables

- `SECRET_KEY`: Flask secret key for session management
- `MONGO_URI`: MongoDB connection URI
- `DATABASE_NAME`: MongoDB database name
- `FLASK_ENV`: Flask environment (development/production)
- `FLASK_DEBUG`: Enable/disable debug mode

## Testing

The project includes a comprehensive Pytest test suite. Tests use a separate test database (`blog_test_db`) that is automatically created and cleaned up.

### Running Tests

1. **Make sure MongoDB is running** (tests need MongoDB connection)

2. **Run all tests:**
   ```bash
   pytest
   ```

3. **Run tests with verbose output:**
   ```bash
   pytest -v
   ```

4. **Run tests with coverage report:**
   ```bash
   pytest --cov=app --cov-report=html
   ```

5. **Run a specific test file:**
   ```bash
   pytest tests/test_routes.py
   ```

### Test Coverage

The test suite covers:
- Home page displaying all posts (empty and with posts)
- Creating new blog posts (success and validation)
- Viewing individual posts
- Error handling (invalid IDs, missing posts)
- Form validation

## License

MIT License



