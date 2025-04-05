import hmac
import hashlib
import os

class Anonymizer:
    def __init__(self, secret):
        self.secret = secret.encode()
        
    def hash_field(self, value):
        return hmac.new(self.secret, value.encode(), hashlib.sha256).hexdigest()[:16]
