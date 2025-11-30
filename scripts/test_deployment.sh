#!/bin/bash
# Comprehensive deployment testing script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Update these with your actual IPs
DROPLET1_IP="${DROPLET1_IP:-}"
DROPLET2_IP="${DROPLET2_IP:-}"
MONITORING_IP="${MONITORING_IP:-}"
JENKINS_IP="${JENKINS_IP:-}"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Function to check if a URL is accessible
check_url() {
    local url=$1
    local description=$2
    local expected_status=${3:-200}
    
    print_info "Testing $description..."
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 10); then
        if [ "$response" -eq "$expected_status" ]; then
            print_success "$description is accessible (HTTP $response)"
            return 0
        else
            print_error "$description returned HTTP $response (expected $expected_status)"
            return 1
        fi
    else
        print_error "$description is not accessible"
        return 1
    fi
}

# Function to check if metrics endpoint works
check_metrics() {
    local host=$1
    local droplet_name=$2
    
    print_info "Checking metrics endpoint for $droplet_name..."
    
    if metrics=$(curl -s "http://$host/metrics" --max-time 10); then
        if echo "$metrics" | grep -q "blog_http_requests_total"; then
            print_success "$droplet_name metrics endpoint is working"
            return 0
        else
            print_error "$droplet_name metrics endpoint doesn't contain expected metrics"
            return 1
        fi
    else
        print_error "$droplet_name metrics endpoint is not accessible"
        return 1
    fi
}

# Function to check Prometheus targets
check_prometheus_targets() {
    print_info "Checking Prometheus targets..."
    
    if targets=$(curl -s "http://$MONITORING_IP:9090/api/v1/targets" --max-time 10); then
        active_targets=$(echo "$targets" | grep -o '"health":"up"' | wc -l)
        print_success "Prometheus has $active_targets active targets"
        
        if [ "$active_targets" -ge 2 ]; then
            print_success "Both application targets are being monitored"
            return 0
        else
            print_error "Not all application targets are active"
            return 1
        fi
    else
        print_error "Cannot connect to Prometheus"
        return 1
    fi
}

# Function to create a test blog post
test_create_post() {
    local host=$1
    local droplet_name=$2
    
    print_info "Testing blog post creation on $droplet_name..."
    
    response=$(curl -s -X POST "http://$host/create" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "title=Test Post $(date +%s)" \
        -d "content=This is a test post created by the deployment script" \
        -d "author=Deployment Test" \
        -w "%{http_code}" \
        --max-time 10)
    
    if echo "$response" | grep -q "302\|200"; then
        print_success "Successfully created test post on $droplet_name"
        return 0
    else
        print_error "Failed to create test post on $droplet_name"
        return 1
    fi
}

# Main testing function
main() {
    echo ""
    echo "=========================================="
    echo "  Blog DevOps Deployment Test Suite"
    echo "=========================================="
    echo ""
    
    # Check if IPs are provided
    if [ -z "$DROPLET1_IP" ] || [ -z "$DROPLET2_IP" ] || [ -z "$MONITORING_IP" ]; then
        print_error "Please set environment variables:"
        echo "  export DROPLET1_IP=your_droplet1_ip"
        echo "  export DROPLET2_IP=your_droplet2_ip"
        echo "  export MONITORING_IP=your_monitoring_ip"
        echo "  export JENKINS_IP=your_jenkins_ip (optional)"
        exit 1
    fi
    
    total_tests=0
    passed_tests=0
    
    # Test Droplet 1
    echo ""
    echo "Testing Droplet 1 (GitHub Actions)..."
    echo "--------------------------------------"
    
    ((total_tests++))
    if check_url "http://$DROPLET1_IP" "Droplet 1 homepage"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_url "http://$DROPLET1_IP/health" "Droplet 1 health endpoint"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_metrics "$DROPLET1_IP" "Droplet 1"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if test_create_post "$DROPLET1_IP" "Droplet 1"; then
        ((passed_tests++))
    fi
    
    # Test Droplet 2
    echo ""
    echo "Testing Droplet 2 (Jenkins)..."
    echo "--------------------------------------"
    
    ((total_tests++))
    if check_url "http://$DROPLET2_IP" "Droplet 2 homepage"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_url "http://$DROPLET2_IP/health" "Droplet 2 health endpoint"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_metrics "$DROPLET2_IP" "Droplet 2"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if test_create_post "$DROPLET2_IP" "Droplet 2"; then
        ((passed_tests++))
    fi
    
    # Test Monitoring
    echo ""
    echo "Testing Monitoring Server..."
    echo "--------------------------------------"
    
    ((total_tests++))
    if check_url "http://$MONITORING_IP:9090" "Prometheus"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_url "http://$MONITORING_IP:3000" "Grafana"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_url "http://$MONITORING_IP:9091" "Pushgateway"; then
        ((passed_tests++))
    fi
    
    ((total_tests++))
    if check_prometheus_targets; then
        ((passed_tests++))
    fi
    
    # Test Jenkins (if provided)
    if [ -n "$JENKINS_IP" ]; then
        echo ""
        echo "Testing Jenkins..."
        echo "--------------------------------------"
        
        ((total_tests++))
        if check_url "http://$JENKINS_IP:8080" "Jenkins" "200"; then
            ((passed_tests++))
        fi
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo "Total tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $((total_tests - passed_tests))"
    echo ""
    
    if [ $passed_tests -eq $total_tests ]; then
        print_success "All tests passed! 🎉"
        echo ""
        echo "Your deployment is working correctly!"
        echo ""
        echo "Access URLs:"
        echo "  Droplet 1: http://$DROPLET1_IP"
        echo "  Droplet 2: http://$DROPLET2_IP"
        echo "  Prometheus: http://$MONITORING_IP:9090"
        echo "  Grafana: http://$MONITORING_IP:3000"
        [ -n "$JENKINS_IP" ] && echo "  Jenkins: http://$JENKINS_IP:8080"
        echo ""
        exit 0
    else
        print_error "Some tests failed. Please check the output above."
        echo ""
        echo "Troubleshooting tips:"
        echo "1. Check if all services are running:"
        echo "   ssh root@$DROPLET1_IP 'sudo systemctl status blog-app'"
        echo "   ssh root@$DROPLET2_IP 'sudo systemctl status blog-app'"
        echo ""
        echo "2. Check application logs:"
        echo "   ssh root@$DROPLET1_IP 'sudo journalctl -u blog-app -n 50'"
        echo "   ssh root@$DROPLET2_IP 'sudo journalctl -u blog-app -n 50'"
        echo ""
        echo "3. Check if MongoDB is running:"
        echo "   ssh root@$DROPLET1_IP 'sudo systemctl status mongod'"
        echo "   ssh root@$DROPLET2_IP 'sudo systemctl status mongod'"
        echo ""
        exit 1
    fi
}

# Run main function
main
