# Search Functionality Documentation

## Overview

FocusPad now includes comprehensive search functionality that allows users to search across all their notes, including encrypted content. The search feature provides real-time results with highlighted matches and supports searching through all note fields.

## Features

### 🔍 **Full-Text Search**
- Search across all note fields: title, description, content, raw content, and attendees
- Case-insensitive search
- Minimum 2 characters required for search
- Real-time search with 300ms debounce
- Search works with encrypted data (decrypted server-side for searching)

### 🎯 **Smart Results**
- Highlighted search terms in results using `<mark>` tags
- Context snippets showing surrounding text
- Field-specific match indicators (title, content, description, etc.)
- Category information for content matches
- Relevance sorting by match count and recency

### 🎨 **User Interface**
- Clean search box in the sidebar
- Auto-showing/hiding clear button
- Search status messages
- Keyboard shortcuts (Escape to clear)
- Responsive design with dark mode support

## API Endpoint

### GET `/api/notes/search`

**Parameters:**
- `q` (required): Search query string (minimum 2 characters)
- `include_archived` (optional): Include archived notes (`true`/`false`, default: `false`)

**Headers:**
- `Authorization: Bearer <JWT_TOKEN>` (required)

**Response Format:**
```json
{
  "query": "search term",
  "results": [
    {
      "note": {
        "id": 1,
        "title": "Meeting Notes",
        "description": "Weekly team meeting",
        "created_at": "2023-05-29T12:00:00Z",
        "updated_at": "2023-05-29T12:30:00Z",
        "is_archived": false,
        "template_name": "Meeting Template"
      },
      "matches": [
        {
          "field": "title",
          "text": "Meeting Notes",
          "highlight": "<mark>Meeting</mark> Notes"
        },
        {
          "field": "content",
          "category": "Action Items",
          "text": "Schedule follow-up meeting",
          "highlight": "Schedule follow-up <mark>meeting</mark>",
          "item_id": 1,
          "timestamp": "2023-05-29T12:15:00Z"
        }
      ],
      "match_count": 2
    }
  ],
  "total_results": 1,
  "total_matches": 2
}
```

**Error Responses:**
- `400`: Missing or invalid search query
- `401`: Missing or invalid authentication
- `500`: Server error during search

## Technical Implementation

### Backend Components

1. **Search Route** (`app/routes/notes.py`)
   - `/api/notes/search` endpoint
   - JWT authentication required
   - Query validation and sanitization
   - Encrypted data decryption for searching
   - Result highlighting and formatting

2. **Highlight Function** (`_highlight_text`)
   - Creates context snippets around matches
   - Adds `<mark>` tags for highlighting
   - Handles case-insensitive matching
   - Limits snippet length for performance

3. **Security Features**
   - Server-side decryption for search
   - User isolation (only search own notes)
   - SQL injection prevention
   - XSS protection in highlights

### Frontend Components

1. **Search Interface** (`dashboard.html`)
   - Search input with real-time feedback
   - Clear button with dynamic visibility
   - Search status messages
   - Keyboard navigation support

2. **JavaScript Functions**
   - `initializeSearch()`: Setup event listeners
   - `performSearch()`: API call with debouncing
   - `renderSearchResults()`: Display results with highlighting
   - `clearSearch()`: Reset to normal view

3. **CSS Styling**
   - Responsive search box design
   - Highlighted match styling
   - Dark mode support
   - Search result cards with context

## Security Considerations

### 🔐 **Encryption Compatibility**
- Search works transparently with encrypted notes
- Data is decrypted server-side only for authorized users
- No plaintext data exposed in search indexes
- Encrypted data remains encrypted at rest

### 🛡️ **Access Control**
- JWT authentication required for all searches
- User can only search their own notes
- No cross-user data leakage
- Session timeout handling

### 🔒 **Input Validation**
- Minimum query length enforcement
- SQL injection prevention
- XSS protection in search results
- Rate limiting through debouncing

## Usage Examples

### Basic Search
```
Search: "meeting"
Results: All notes containing "meeting" in any field
```

### Multi-word Search
```
Search: "action items"
Results: Notes containing both "action" and "items"
```

### Category-specific Results
```
Search: "budget"
Results: Shows which category contains the match
- Title: "Q4 Budget Review"
- Content (Financial): "Budget projections for next quarter"
```

## Performance Considerations

### ⚡ **Optimization Features**
- 300ms debounce prevents excessive API calls
- Minimum 2-character requirement reduces server load
- Fresh database queries avoid session conflicts
- Efficient text highlighting with regex

### 📊 **Scalability**
- Currently uses in-memory search (suitable for moderate note counts)
- Can be upgraded to full-text search engines (Elasticsearch, PostgreSQL FTS)
- Pagination support ready for large result sets
- Caching opportunities for frequent searches

## Future Enhancements

### 🚀 **Planned Features**
- Advanced search operators (AND, OR, NOT)
- Date range filtering
- Search within specific categories
- Search result pagination
- Search history and suggestions
- Saved searches
- Export search results

### 🔧 **Technical Improvements**
- Full-text search engine integration
- Search result caching
- Advanced highlighting (whole word, phrase matching)
- Search analytics and metrics
- Performance monitoring

## Testing

### ✅ **Verified Functionality**
- Search endpoint responds correctly (401 without auth)
- Frontend integration complete
- Encryption compatibility confirmed
- Cross-browser compatibility
- Dark mode styling verified

### 🧪 **Test Scenarios**
```bash
# Test authentication requirement
curl -X GET "http://localhost:5000/api/notes/search?q=test"
# Response: 401 Missing Authorization Header

# Test with valid token (replace with actual token)
curl -X GET "http://localhost:5000/api/notes/search?q=meeting" \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## Troubleshooting

### Common Issues

1. **"Search failed" error**
   - Check JWT token validity
   - Verify server connectivity
   - Check browser console for details

2. **No results found**
   - Ensure minimum 2 characters
   - Check for typos in search term
   - Verify notes exist and aren't archived

3. **Search not highlighting**
   - Check if JavaScript is enabled
   - Verify CSS mark styling loaded
   - Check for content security policy issues

### Debug Mode
Enable debug logging in Flask to see detailed search operations:
```python
app.logger.setLevel(logging.DEBUG)
```

## Changelog

### Version 1.0.0 (Initial Release)
- Full-text search across all note fields
- Real-time search with debouncing
- Encrypted data compatibility
- Responsive UI with dark mode
- Context highlighting
- JWT authentication
- Search status feedback
- Keyboard navigation support

---

*This search functionality enhances FocusPad's usability by making note retrieval fast and intuitive while maintaining the security and encryption standards of the application.* 