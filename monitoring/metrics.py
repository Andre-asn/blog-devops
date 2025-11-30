from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
from flask import Response
from functools import wraps
import time

# Metrics definitions
request_count = Counter(
    'blog_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'blog_http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

active_requests = Gauge(
    'blog_active_requests',
    'Number of active requests'
)

blog_posts_total = Gauge(
    'blog_posts_total',
    'Total number of blog posts in database'
)

blog_posts_created = Counter(
    'blog_posts_created_total',
    'Total number of blog posts created'
)

blog_posts_viewed = Counter(
    'blog_posts_viewed_total',
    'Total number of blog post views'
)

database_operations = Counter(
    'blog_database_operations_total',
    'Total database operations',
    ['operation', 'status']
)

database_operation_duration = Histogram(
    'blog_database_operation_duration_seconds',
    'Database operation duration in seconds',
    ['operation']
)


def track_request_metrics(f):
    """Decorator to track request metrics"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        active_requests.inc()
        start_time = time.time()
        
        try:
            response = f(*args, **kwargs)
            status = response.status_code if hasattr(response, 'status_code') else 200
            
            # Track metrics
            from flask import request
            request_count.labels(
                method=request.method,
                endpoint=request.endpoint or 'unknown',
                status=status
            ).inc()
            
            duration = time.time() - start_time
            request_duration.labels(
                method=request.method,
                endpoint=request.endpoint or 'unknown'
            ).observe(duration)
            
            return response
        except Exception as e:
            request_count.labels(
                method=request.method,
                endpoint=request.endpoint or 'unknown',
                status=500
            ).inc()
            raise
        finally:
            active_requests.dec()
    
    return decorated_function


def track_database_operation(operation_name):
    """Decorator to track database operations"""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            status = 'success'
            
            try:
                result = f(*args, **kwargs)
                return result
            except Exception as e:
                status = 'error'
                raise
            finally:
                duration = time.time() - start_time
                database_operations.labels(
                    operation=operation_name,
                    status=status
                ).inc()
                database_operation_duration.labels(
                    operation=operation_name
                ).observe(duration)
        
        return wrapper
    return decorator


def update_blog_posts_count(repository):
    """Update the blog posts count metric"""
    try:
        count = repository.count()
        blog_posts_total.set(count)
    except Exception as e:
        print(f"Error updating blog posts count: {e}")


def metrics_endpoint():
    """Endpoint to expose Prometheus metrics"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain')
