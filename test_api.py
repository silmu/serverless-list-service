"""Tests for the Serverless List Service API endpoints"""
import os
import requests

API_URL = os.environ.get("API_URL")
API_KEY = os.environ.get("API_KEY")

def test_head():
    """Basic test for the /head endpoint"""
    url = f"{API_URL}/head"
    headers = {"x-api-key": API_KEY}
    response = requests.get(url, headers=headers, timeout=10)
    assert response.status_code == 200
    data = response.json()
    assert data["operation"] == "head"
    assert "item" in data

def test_tail():
    """Basic test for the /tail endpoint"""
    url = f"{API_URL}/tail"
    headers = {"x-api-key": API_KEY}
    response = requests.get(url, headers=headers, timeout=10)
    assert response.status_code == 200
    data = response.json()
    assert data["operation"] == "tail"
    assert "item" in data

if __name__ == "__main__":
    test_head()
    print("Head endpoint test passed.")
    test_tail()
    print("Tail endpoint test passed.")