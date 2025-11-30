from typing import Optional, List
from pymongo.collection import Collection
from bson import ObjectId
from models.blog_post import BlogPost
from monitoring.metrics import track_database_operation


class BlogRepository:
    """Repository class for blog post database operations"""
    
    def __init__(self, collection: Collection):
        """
        Initialize the repository with a MongoDB collection
        
        Args:
            collection: MongoDB collection for blog posts
        """
        self.collection = collection
    
    @track_database_operation('create')
    def create(self, blog_post: BlogPost) -> str:
        """
        Create a new blog post in the database
        
        Args:
            blog_post: BlogPost instance to create
            
        Returns:
            String representation of the inserted document ID
        """
        post_dict = blog_post.to_dict()
        # Remove _id if present to let MongoDB generate it
        post_dict.pop('_id', None)
        
        result = self.collection.insert_one(post_dict)
        return str(result.inserted_id)
    
    @track_database_operation('get_by_id')
    def get_by_id(self, post_id: str) -> Optional[BlogPost]:
        """
        Retrieve a blog post by its ID
        
        Args:
            post_id: String representation of the post ID
            
        Returns:
            BlogPost instance if found, None otherwise
        """
        try:
            object_id = ObjectId(post_id)
            post_dict = self.collection.find_one({'_id': object_id})
            
            if post_dict:
                return BlogPost.from_dict(post_dict)
            return None
        except (ValueError, TypeError, Exception):
            return None
    
    @track_database_operation('get_all')
    def get_all(self, sort_by: str = 'created_at', order: int = -1) -> List[BlogPost]:
        """
        Retrieve all blog posts
        
        Args:
            sort_by: Field to sort by (default: 'created_at')
            order: Sort order -1 for descending, 1 for ascending (default: -1)
            
        Returns:
            List of BlogPost instances
        """
        posts = list(self.collection.find().sort(sort_by, order))
        return [BlogPost.from_dict(post) for post in posts]
    
    @track_database_operation('delete')
    def delete(self, post_id: str) -> bool:
        """
        Delete a blog post by its ID
        
        Args:
            post_id: String representation of the post ID
            
        Returns:
            True if deleted, False otherwise
        """
        try:
            object_id = ObjectId(post_id)
            result = self.collection.delete_one({'_id': object_id})
            return result.deleted_count > 0
        except (ValueError, TypeError, Exception):
            return False
    
    @track_database_operation('update')
    def update(self, post_id: str, blog_post: BlogPost) -> bool:
        """
        Update an existing blog post
        
        Args:
            post_id: String representation of the post ID
            blog_post: BlogPost instance with updated data
            
        Returns:
            True if updated, False otherwise
        """
        try:
            object_id = ObjectId(post_id)
            post_dict = blog_post.to_dict()
            # Update the updated_at timestamp
            post_dict['updated_at'] = blog_post.updated_at
            # Remove _id from update dict
            post_dict.pop('_id', None)
            
            result = self.collection.update_one(
                {'_id': object_id},
                {'$set': post_dict}
            )
            return result.modified_count > 0
        except (ValueError, TypeError, Exception):
            return False
    
    def count(self) -> int:
        """
        Get the total count of blog posts
        
        Returns:
            Number of blog posts in the collection
        """
        return self.collection.count_documents({})
