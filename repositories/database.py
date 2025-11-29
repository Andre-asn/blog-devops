from typing import Optional
from pymongo import MongoClient
from pymongo.database import Database
from pymongo.collection import Collection
import os


class DatabaseConnection:
    """Class to manage MongoDB database connection"""
    
    def __init__(self, mongo_uri: str, database_name: str):
        """
        Initialize database connection
        
        Args:
            mongo_uri: MongoDB connection URI
            database_name: Name of the database to connect to
        """
        self.mongo_uri = mongo_uri
        self.database_name = database_name
        self._client: Optional[MongoClient] = None
        self._database: Optional[Database] = None
    
    def connect(self) -> Database:
        """
        Establish connection to MongoDB database
        
        Returns:
            MongoDB database instance
        """
        if self._database is None:
            self._client = MongoClient(self.mongo_uri)
            self._database = self._client[self.database_name]
        return self._database
    
    def get_collection(self, collection_name: str) -> Collection:
        """
        Get a collection from the database
        
        Args:
            collection_name: Name of the collection
            
        Returns:
            MongoDB collection instance
        """
        database = self.connect()
        return database[collection_name]
    
    def close(self):
        """Close the database connection"""
        if self._client:
            self._client.close()
            self._client = None
            self._database = None
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()

