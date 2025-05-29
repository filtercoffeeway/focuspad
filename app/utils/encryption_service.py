"""
Encryption service for FocusPad API.
Provides server-side encryption for sensitive note data.
"""

import os
import base64
import json
import logging
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from flask import current_app

logger = logging.getLogger(__name__)

class EncryptionService:
    """Service for encrypting and decrypting note data."""
    
    def __init__(self):
        self._master_key = None
    
    def _get_master_key(self):
        """Get or generate the master encryption key."""
        if self._master_key:
            return self._master_key
        
        # Get master key from environment (use default for demo)
        master_key_b64 = os.environ.get('FOCUSPAD_MASTER_KEY', 'rZz_YjZ0yK4S8QK9vKxEZ_L3gE8F7X1Q2W9sV5nP6M0=')
        self._master_key = base64.urlsafe_b64decode(master_key_b64)
        logger.info("Master key loaded for encryption")
        return self._master_key
    
    def _derive_user_key(self, user_id: int, salt: bytes = None):
        """Derive a user-specific encryption key."""
        if salt is None:
            salt = os.urandom(16)
        
        master_key = self._get_master_key()
        user_data = f'user_{user_id}'.encode('utf-8')
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000
        )
        
        combined_input = master_key + user_data
        derived_key = kdf.derive(combined_input)
        return derived_key, salt
    
    def _get_user_fernet(self, user_id: int, salt: bytes = None):
        """Get a Fernet instance for user-specific encryption."""
        derived_key, used_salt = self._derive_user_key(user_id, salt)
        fernet_key = base64.urlsafe_b64encode(derived_key)
        fernet = Fernet(fernet_key)
        return fernet, used_salt
    
    def encrypt_text(self, text: str, user_id: int) -> dict:
        """Encrypt text data for a specific user."""
        if not text:
            return {'encrypted_data': None, 'salt': None, 'is_encrypted': False}
        
        try:
            fernet, salt = self._get_user_fernet(user_id)
            encrypted_bytes = fernet.encrypt(text.encode('utf-8'))
            encrypted_b64 = base64.urlsafe_b64encode(encrypted_bytes).decode('utf-8')
            salt_b64 = base64.urlsafe_b64encode(salt).decode('utf-8')
            
            return {
                'encrypted_data': encrypted_b64,
                'salt': salt_b64,
                'is_encrypted': True,
                'encryption_version': '1.0'
            }
        except Exception as e:
            logger.error(f'Encryption failed for user {user_id}: {e}')
            raise EncryptionError(f'Failed to encrypt data: {e}')
    
    def decrypt_text(self, encrypted_data: str, salt: str, user_id: int) -> str:
        """Decrypt text data for a specific user."""
        if not encrypted_data or not salt:
            return ''
        
        try:
            salt_bytes = base64.urlsafe_b64decode(salt)
            fernet, _ = self._get_user_fernet(user_id, salt_bytes)
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_data)
            decrypted_bytes = fernet.decrypt(encrypted_bytes)
            return decrypted_bytes.decode('utf-8')
        except Exception as e:
            logger.error(f'Decryption failed for user {user_id}: {e}')
            raise EncryptionError(f'Failed to decrypt data: {e}')
    
    def encrypt_note_data(self, note_data: dict, user_id: int) -> dict:
        """Encrypt sensitive fields in note data."""
        encrypted_note = note_data.copy()
        sensitive_fields = ['title', 'content', 'raw_content', 'attendees', 'description']
        
        for field in sensitive_fields:
            if field in note_data and note_data[field]:
                field_value = note_data[field]
                if isinstance(field_value, (dict, list)):
                    field_value = json.dumps(field_value)
                
                encryption_result = self.encrypt_text(field_value, user_id)
                encrypted_note[f'{field}_encrypted'] = encryption_result['encrypted_data']
                encrypted_note[f'{field}_salt'] = encryption_result['salt']
                encrypted_note[f'{field}_is_encrypted'] = encryption_result['is_encrypted']
        
        return encrypted_note
    
    def decrypt_note_data(self, encrypted_note_data: dict, user_id: int) -> dict:
        """Decrypt sensitive fields in note data."""
        decrypted_note = encrypted_note_data.copy()
        sensitive_fields = ['title', 'content', 'raw_content', 'attendees', 'description']
        
        for field in sensitive_fields:
            encrypted_field = f'{field}_encrypted'
            salt_field = f'{field}_salt'
            is_encrypted_field = f'{field}_is_encrypted'
            
            if (encrypted_field in encrypted_note_data and 
                salt_field in encrypted_note_data and 
                encrypted_note_data.get(is_encrypted_field)):
                
                try:
                    decrypted_text = self.decrypt_text(
                        encrypted_note_data[encrypted_field],
                        encrypted_note_data[salt_field],
                        user_id
                    )
                    
                    if field == 'content' and decrypted_text:
                        try:
                            decrypted_note[field] = json.loads(decrypted_text)
                        except json.JSONDecodeError:
                            decrypted_note[field] = decrypted_text
                    else:
                        decrypted_note[field] = decrypted_text
                    
                    # Clean up encryption metadata
                    decrypted_note.pop(encrypted_field, None)
                    decrypted_note.pop(salt_field, None)
                    decrypted_note.pop(is_encrypted_field, None)
                    
                except EncryptionError as e:
                    logger.error(f'Failed to decrypt {field} for user {user_id}: {e}')
                    pass
        
        return decrypted_note
    
    def is_note_encrypted(self, note_data: dict) -> bool:
        """Check if note data is encrypted."""
        encrypted_fields = [k for k in note_data.keys() if k.endswith('_encrypted')]
        return len(encrypted_fields) > 0


class EncryptionError(Exception):
    """Custom exception for encryption-related errors."""
    pass


# Global encryption service instance
encryption_service = EncryptionService()


def generate_master_key() -> str:
    """Generate a new master key."""
    key = Fernet.generate_key()
    return base64.urlsafe_b64encode(key).decode()


if __name__ == "__main__":
    print("Generated master key for FOCUSPAD_MASTER_KEY:")
    print(generate_master_key())
