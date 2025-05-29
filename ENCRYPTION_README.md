# FocusPad Server-Side Encryption

This document describes the server-side encryption implementation for FocusPad, which provides end-to-end protection for sensitive note data.

## Overview

FocusPad implements robust server-side encryption to protect user data at rest. All sensitive note content is encrypted before being stored in the database and decrypted only when needed for authorized users.

## Features

- **AES-256 Encryption**: Uses industry-standard AES-256 encryption via the Fernet symmetric encryption scheme
- **User-Specific Keys**: Each user's data is encrypted with a unique key derived from a master key and user ID
- **Salt-Based Security**: Each encrypted field uses a unique salt for additional security
- **Transparent Operation**: Encryption/decryption happens automatically in the API layer
- **Graceful Fallback**: System continues to work even if encryption fails

## Encrypted Fields

The following note fields are encrypted:

- `title` - Note title
- `content` - Structured note content (JSON)
- `raw_content` - Raw unstructured content
- `attendees` - Meeting attendees information
- `description` - Note description

## Database Schema

For each encrypted field, three additional columns are added:

- `{field}_encrypted` - The encrypted data (TEXT)
- `{field}_salt` - The encryption salt (VARCHAR(255))
- `{field}_is_encrypted` - Encryption status flag (BOOLEAN)

Example for the `title` field:
- `title_encrypted`
- `title_salt`
- `title_is_encrypted`

## Architecture

### Encryption Service (`app/utils/encryption_service.py`)

The `EncryptionService` class provides:

- **Master Key Management**: Secure handling of the master encryption key
- **User Key Derivation**: PBKDF2-based key derivation for user-specific encryption
- **Text Encryption/Decryption**: High-level methods for encrypting and decrypting text
- **Note Data Processing**: Specialized methods for handling note data structures

### Model Integration (`app/models/note.py`)

The `Note` model includes:

- **Encryption Methods**: `encrypt_sensitive_data()` and `decrypt_sensitive_data()`
- **Transparent Access**: Standard model methods work with decrypted data
- **Database Fields**: Additional columns for encrypted data storage

### API Integration (`app/routes/notes.py`)

All note API endpoints automatically:

- **Decrypt on Read**: Decrypt data before returning to client
- **Encrypt on Write**: Encrypt data before saving to database
- **Handle Errors**: Graceful fallback if encryption/decryption fails

## Setup Instructions

### 1. Environment Configuration

Add the master encryption key to your environment:

```bash
# Generate a new key (run this once)
python3 -c "from cryptography.fernet import Fernet; import base64; key = Fernet.generate_key(); print('FOCUSPAD_MASTER_KEY=' + base64.urlsafe_b64encode(key).decode())"

# Add to .env file
FOCUSPAD_MASTER_KEY=your_generated_key_here
```

### 2. Database Migration

Run the setup script to add encryption fields and encrypt existing data:

```bash
cd focuspad
python3 scripts/setup_encryption.py
```

This script will:
- Add encryption fields to the database
- Encrypt all existing note data
- Verify the encryption setup

### 3. Manual Steps (if needed)

If you prefer to run steps manually:

```bash
# Add encryption fields
python3 scripts/add_encryption_fields.py

# Encrypt existing data
python3 scripts/encrypt_existing_data.py
```

## Security Considerations

### Key Management

- **Master Key**: Store securely in environment variables, never in code
- **Key Rotation**: Plan for periodic master key rotation (requires data re-encryption)
- **Backup**: Ensure master key is backed up securely - data cannot be recovered without it

### User Key Derivation

- Uses PBKDF2 with SHA-256 and 100,000 iterations
- Each user gets a unique encryption key derived from master key + user ID
- Salts are generated randomly for each encrypted field

### Data Protection

- **At Rest**: All sensitive data encrypted in database
- **In Transit**: Use HTTPS for all API communications
- **In Memory**: Data decrypted only when needed, not cached

## Performance Considerations

- **Encryption Overhead**: Minimal impact on API response times
- **Database Size**: Encrypted fields are larger than plaintext (base64 encoding)
- **CPU Usage**: Encryption/decryption adds computational overhead

## Monitoring and Logging

The system logs encryption operations:

- Successful encryption/decryption operations
- Encryption failures (with fallback to unencrypted operation)
- Key derivation and master key loading

Log levels:
- `INFO`: Successful operations
- `ERROR`: Encryption/decryption failures
- `WARNING`: Fallback operations

## Troubleshooting

### Common Issues

1. **Missing Master Key**
   ```
   Error: FOCUSPAD_MASTER_KEY environment variable not set
   ```
   Solution: Set the `FOCUSPAD_MASTER_KEY` environment variable

2. **Decryption Failures**
   ```
   Error: Failed to decrypt data
   ```
   Possible causes:
   - Master key changed
   - Corrupted encrypted data
   - Wrong user ID for decryption

3. **Database Migration Issues**
   ```
   Error: Column already exists
   ```
   Solution: Encryption fields already added, safe to ignore

### Recovery Procedures

1. **Lost Master Key**: Data cannot be recovered without the master key
2. **Corrupted Data**: System falls back to unencrypted data if available
3. **Migration Rollback**: Remove encryption fields and restore from backup

## API Behavior

### Transparent Operation

From the client perspective, the API works exactly the same:

```javascript
// Create note (data automatically encrypted)
POST /api/notes/
{
  "title": "My Note",
  "content": "Secret content"
}

// Get note (data automatically decrypted)
GET /api/notes/1
{
  "title": "My Note",
  "content": "Secret content"
}
```

### Error Handling

If encryption fails, the system:
1. Logs the error
2. Continues operation with unencrypted data
3. Returns appropriate error messages to client

## Testing

### Verify Encryption

```bash
# Run the setup script with verification
python3 scripts/setup_encryption.py

# Check database directly
psql -d focuspad -c "SELECT title, title_encrypted IS NOT NULL as encrypted FROM notes LIMIT 5;"
```

### Test API Endpoints

```bash
# Create a note
curl -X POST http://localhost:5000/api/notes/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Note", "description": "Test content"}'

# Verify it's encrypted in database
psql -d focuspad -c "SELECT title, title_encrypted FROM notes WHERE title = 'Test Note';"
```

## Compliance

This encryption implementation helps meet:

- **GDPR**: Data protection and privacy requirements
- **HIPAA**: Healthcare data protection (if applicable)
- **SOC 2**: Security controls for service organizations
- **Industry Standards**: Follows encryption best practices

## Future Enhancements

Potential improvements:

1. **Client-Side Encryption**: Additional layer of encryption in the browser
2. **Key Rotation**: Automated master key rotation with data re-encryption
3. **Hardware Security Modules**: Integration with HSMs for key management
4. **Audit Logging**: Detailed audit trail for all encryption operations
5. **Performance Optimization**: Caching and optimization for high-volume usage

## Support

For questions or issues with encryption:

1. Check the logs for error messages
2. Verify environment configuration
3. Run the verification script
4. Contact the development team with specific error details

---

**⚠️ Important**: Never lose the master encryption key - encrypted data cannot be recovered without it! 