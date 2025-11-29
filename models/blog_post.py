from datetime import datetime, timezone
from typing import Optional, Tuple
from bson import ObjectId


class BlogPost:
    """Model class representing a blog post entity"""
    
    def __init__(self, title: str, content: str, author: str = "Anonymous", 
                 post_id: Optional[ObjectId] = None, 
                 created_at: Optional[datetime] = None,
                 updated_at: Optional[datetime] = None):
        """
        Initialize a BlogPost instance
        
        Args:
            title: The title of the blog post
            content: The content of the blog post
            author: The author name (defaults to "Anonymous")
            post_id: MongoDB ObjectId (optional, for existing posts)
            created_at: Creation timestamp (optional, defaults to now)
            updated_at: Last update timestamp (optional, defaults to now)
        """
        self._id = post_id
        self.title = title
        self.content = content
        self.author = author
        self.created_at = created_at if created_at else datetime.now(timezone.utc)
        self.updated_at = updated_at if updated_at else datetime.now(timezone.utc)
    
    @property
    def id(self) -> Optional[str]:
        """Get the post ID as a string"""
        return str(self._id) if self._id else None
    
    def to_dict(self) -> dict:
        """
        Convert BlogPost instance to dictionary format for MongoDB
        
        Returns:
            Dictionary representation of the blog post
        """
        post_dict = {
            'title': self.title,
            'content': self.content,
            'author': self.author,
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }
        
        if self._id:
            post_dict['_id'] = self._id
        
        return post_dict
    
    @classmethod
    def from_dict(cls, post_dict: dict) -> 'BlogPost':
        """
        Create a BlogPost instance from a MongoDB document dictionary
        
        Args:
            post_dict: Dictionary from MongoDB containing post data
            
        Returns:
            BlogPost instance
        """
        return cls(
            title=post_dict.get('title', ''),
            content=post_dict.get('content', ''),
            author=post_dict.get('author', 'Anonymous'),
            post_id=post_dict.get('_id'),
            created_at=post_dict.get('created_at', datetime.now(timezone.utc)),
            updated_at=post_dict.get('updated_at', datetime.now(timezone.utc))
        )
    
    def validate(self) -> Tuple[bool, Optional[str]]:
        """
        Validate the blog post data
        
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not self.title or not self.title.strip():
            return False, "Title is required"
        
        if not self.content or not self.content.strip():
            return False, "Content is required"
        
        return True, None
    
    def __repr__(self) -> str:
        """String representation of the BlogPost"""
        return f"BlogPost(id={self.id}, title='{self.title}', author='{self.author}')"

