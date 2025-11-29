# Blog DevOps Project

A blog website built with Flask and MongoDB, designed with DevOps practices in mind.

## Features

- **Home Page**: View all blog posts in reverse chronological order
- **Create Post**: Create new blog posts with title, author, and content
- **View Post**: Read individual blog posts in detail

## Tech Stack

- **Backend**: Python Flask
- **Database**: MongoDB
- **Frontend**: Flask Templates (HTML/CSS)
- **Testing**: Pytest 
- **CI/CD**: GitHub Actions 
- **Deployment**: DigitalOcean 

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
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── env.example            # Environment variables template
├── .gitignore            # Git ignore file
├── README.md             # This file
└── templates/            # Flask HTML templates
    ├── base.html         # Base template
    ├── index.html        # Home page
    ├── create.html       # Create post page
    └── view.html         # View post page
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

## Future Enhancements

- [ ] Pytest test suite
- [ ] GitHub Actions CI/CD pipeline
- [ ] DigitalOcean deployment configuration
- [ ] Prometheus monitoring setup
- [ ] Grafana dashboards
- [ ] Docker containerization
- [ ] Nginx reverse proxy configuration

## License

MIT License

