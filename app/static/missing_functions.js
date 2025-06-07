// Missing functions for dashboard.html

// Create new note function
async function createNewNote() {
    console.log('Creating new note...');
    
    // Create completely empty note content
    const defaultMarkdownContent = '';
    
    try {
        const response = await fetch('/api/notes/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                title: 'New Note',
                description: '',
                attendees: '',
                markdown_content: defaultMarkdownContent
            })
        });

        if (handleTokenExpiration(response)) return;

        if (response.ok) {
            const data = await response.json();
            const newNote = data.note;
            
            // Add to notes array and refresh display
            notes.unshift(newNote);
            renderNotesList();
            
            // Select the new note
            currentNote = newNote;
            renderNoteDisplay();
            
            // Force it into edit mode immediately
            setTimeout(() => {
                const container = document.getElementById('markdownContainer');
                const editor = document.getElementById('markdownEditor');
                if (container && editor) {
                    container.classList.add('edit-mode');
                    editor.focus();
                }
            }, 100);
            
            console.log('New note created successfully:', newNote.id);
        } else {
            const errorData = await response.json().catch(() => ({}));
            console.error('Failed to create note:', errorData);
            alert('Failed to create note: ' + (errorData.error || 'Unknown error'));
        }
    } catch (error) {
        console.error('Error creating note:', error);
        alert('Error creating note. Please check your connection.');
    }
}

// Render note in main display area
function renderNoteDisplay() {
    const noteDisplay = document.getElementById('noteDisplay');
    
    if (!currentNote) {
        noteDisplay.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">📝</div>
                <h3>Welcome to FocusPad</h3>
                <p>Select a note from the sidebar or create a new one to get started.</p>
            </div>
        `;
        return;
    }

    // Always show the markdown editor - keep it simple like the old dashboard
    noteDisplay.innerHTML = `
        <div class="markdown-container" id="markdownContainer">
            <div class="markdown-header">
                <div style="visibility: hidden;"></div>
                <div class="markdown-controls">
                    <button class="markdown-help-btn" onclick="showMarkdownHelp()" title="Markdown syntax help">
                        ❓ Help
                    </button>
                    <button class="markdown-mode-toggle" onclick="toggleMarkdownMode()">
                        📝 Edit
                    </button>
                    <button class="markdown-help-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-help-btn" onclick="exportNoteToPDF()" title="Export as PDF">
                        📄 Export PDF
                    </button>
                </div>
            </div>
            <div class="markdown-content">
                <div class="markdown-view" id="markdownView" onclick="toggleMarkdownMode()">
                    ${renderMarkdown(currentNote.markdown_content || '')}
                </div>
                <div class="markdown-edit" id="markdownEdit">
                    <textarea class="markdown-editor" id="markdownEditor" placeholder="Start writing your note using Markdown..." onblur="autoSaveMarkdown()" onkeydown="handleMarkdownKeydown(event)">${escapeHtml(currentNote.markdown_content || '')}</textarea>
                </div>
            </div>
        </div>
    `;
    
    // Auto-focus the editor if the note is empty
    if (!currentNote.markdown_content || currentNote.markdown_content.trim() === '') {
        setTimeout(() => {
            const container = document.getElementById('markdownContainer');
            const editor = document.getElementById('markdownEditor');
            if (container && editor) {
                container.classList.add('edit-mode');
                editor.focus();
            }
        }, 100);
    }
}

// Modern note display with markdown support
function renderModernNoteDisplay() {
    const noteDisplay = document.getElementById('noteDisplay');
    
    noteDisplay.innerHTML = `
        ${currentNote.markdown_content ? `
        <div class="markdown-container" id="markdownContainer">
            <div class="markdown-header">
                <div style="visibility: hidden;"></div>
                <div class="markdown-controls">
                    <button class="markdown-help-btn" onclick="showMarkdownHelp()" title="Markdown syntax help">
                        ❓ Help
                    </button>
                    <button class="markdown-mode-toggle" onclick="toggleMarkdownMode()">
                        📝 Edit
                    </button>
                    <button class="markdown-help-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-help-btn" onclick="exportNoteToPDF()" title="Export as PDF">
                        📄 Export PDF
                    </button>
                </div>
            </div>
            <div class="markdown-content">
                <div class="markdown-view" id="markdownView" onclick="toggleMarkdownMode()">
                    ${renderMarkdown(currentNote.markdown_content)}
                </div>
                <div class="markdown-edit" id="markdownEdit">
                    <textarea class="markdown-editor" id="markdownEditor" placeholder="Write your content using Markdown..." onblur="autoSaveMarkdown()" onkeydown="handleMarkdownKeydown(event)">${escapeHtml(currentNote.markdown_content || '')}</textarea>
                </div>
            </div>
        </div>
        ` : ''}

        ${currentNote.raw_content && !currentNote.markdown_content ? `
        <div class="content-section" onclick="convertToMarkdown()">
            <h4 style="margin: 0 0 12px 0; color: var(--text-muted); font-size: 0.875rem;">
                📄 Raw Content (Click to convert to Markdown)
            </h4>
            ${formatRawContentAsParagraphs(currentNote.raw_content)}
        </div>
        ` : ''}
        
        ${!currentNote.markdown_content && !currentNote.raw_content ? `
        <div class="markdown-container" id="markdownContainer">
            <div class="markdown-header">
                <div style="visibility: hidden;"></div>
                <div class="markdown-controls">
                    <button class="markdown-help-btn" onclick="showMarkdownHelp()" title="Markdown syntax help">
                        ❓ Help
                    </button>
                    <button class="markdown-help-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-help-btn" onclick="exportNoteToPDF()" title="Export as PDF">
                        📄 Export PDF
                    </button>
                </div>
            </div>
            <div class="markdown-content">
                <div class="markdown-edit" style="display: block;">
                    <textarea class="markdown-editor" id="markdownEditor" placeholder="Start writing your note using Markdown..." onblur="autoSaveMarkdown()" onkeydown="handleMarkdownKeydown(event)" onclick="this.focus()"></textarea>
                </div>
            </div>
        </div>
        ` : ''}
    `;
    
    // Auto-focus the editor if in a new note
    if (!currentNote.markdown_content && !currentNote.raw_content) {
        setTimeout(() => {
            const editor = document.getElementById('markdownEditor');
            if (editor) editor.focus();
        }, 100);
    }
}

// Legacy note display for older notes with categorized content
function renderLegacyNoteDisplay() {
    const noteDisplay = document.getElementById('noteDisplay');
    const categorizedContent = currentNote.content || {};
    
    noteDisplay.innerHTML = `
        <div class="categories-grid">
            ${renderCategorizedContent(categorizedContent)}
        </div>
    `;
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Format raw content as proper paragraphs
function formatRawContentAsParagraphs(rawContent) {
    if (!rawContent || !rawContent.trim()) {
        return '<p><em>No content yet.</em></p>';
    }

    const lines = rawContent
        .split(/\n/)
        .map(line => line.trim())
        .filter(line => line.length > 0);

    if (lines.length === 0) {
        return '<p><em>No content yet.</em></p>';
    }

    const formattedLines = lines.map(line => {
        const endsWithPunctuation = /[.!?:;,]$/.test(line);
        return endsWithPunctuation ? line : line + '.';
    });

    const paragraph = formattedLines.join(' ');
    return `<p>${escapeHtml(paragraph)}</p>`;
}

// Format date relative to now
function formatRelativeDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
    if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
    if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;
    if (days < 30) return `${Math.floor(days / 7)} week${Math.floor(days / 7) === 1 ? '' : 's'} ago`;
    return date.toLocaleDateString();
}

// Simple markdown renderer
function renderMarkdown(content) {
    if (!content) return '<p><em>No content yet.</em></p>';

    // Use marked.js if available, otherwise fall back to simple rendering
    if (typeof marked !== 'undefined') {
        return marked.parse(content);
    } else {
        // Simple fallback markdown rendering
        return content
            .replace(/^### (.*$)/gim, '<h3>$1</h3>')
            .replace(/^## (.*$)/gim, '<h2>$1</h2>')
            .replace(/^# (.*$)/gim, '<h1>$1</h1>')
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/`(.*?)`/g, '<code>$1</code>')
            .replace(/\n/g, '<br>');
    }
}

// Markdown helper functions
function toggleMarkdownMode() {
    const container = document.getElementById('markdownContainer');
    const isEditing = container.classList.contains('edit-mode');
    
    if (isEditing) {
        // Exit edit mode and auto-save
        autoSaveMarkdown();
    } else {
        // Switch to edit mode
        container.classList.add('edit-mode');
        const editor = document.getElementById('markdownEditor');
        editor.focus();
    }
}

// Handle keyboard shortcuts in markdown editor
function handleMarkdownKeydown(event) {
    if (event.key === 'Escape') {
        event.preventDefault();
        autoSaveMarkdown();
    }
}

// Auto-save markdown content
function autoSaveMarkdown() {
    const editor = document.getElementById('markdownEditor');
    const container = document.getElementById('markdownContainer');
    
    if (!editor || !container.classList.contains('edit-mode')) {
        return; // Not in edit mode
    }
    
    const content = editor.value;
    
    // Save to server
    saveNoteContent(content);
}

// Save note content to server
async function saveNoteContent(content) {
    if (!currentNote || !currentNote.id) {
        return;
    }
    
    try {
        const response = await fetch(`/api/notes/${currentNote.id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                markdown_content: content
            })
        });

        if (handleTokenExpiration(response)) return;

        if (response.ok) {
            currentNote.markdown_content = content;
            
            // Update the display immediately
            const view = document.getElementById('markdownView');
            if (view) {
                view.innerHTML = renderMarkdown(content);
            }
            
            // Exit edit mode
            const container = document.getElementById('markdownContainer');
            container.classList.remove('edit-mode');
            
            // Refresh sidebar
            loadNotes();
            
            console.log('Note content saved successfully');
        } else {
            console.error('Failed to save note content');
            // Don't show alert for auto-save failures, just log them
        }
    } catch (error) {
        console.error('Error saving note content:', error);
        // Don't show alert for auto-save failures, just log them
    }
}

// Convert raw content to markdown
async function convertToMarkdown() {
    if (!currentNote || !currentNote.raw_content) return;
    
    const confirmed = confirm('Convert this raw content to editable Markdown format?');
    if (!confirmed) return;
    
    // Simple conversion: just use the raw content as markdown
    const markdownContent = currentNote.raw_content;
    
    try {
        const response = await fetch(`/api/notes/${currentNote.id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                markdown_content: markdownContent
            })
        });

        if (handleTokenExpiration(response)) return;

        if (response.ok) {
            currentNote.markdown_content = markdownContent;
            renderNoteDisplay(); // Re-render with markdown editor
            loadNotes(); // Refresh sidebar
        } else {
            alert('Failed to convert content. Please try again.');
        }
    } catch (error) {
        console.error('Error converting content:', error);
        alert('Error converting content. Please check your connection.');
    }
}

// Show markdown help (placeholder)
function showMarkdownHelp() {
    alert('Markdown Help:\n\n# Heading 1\n## Heading 2\n### Heading 3\n\n**Bold text**\n*Italic text*\n`Code`\n\n- Bullet point\n1. Numbered list\n\n> Quote\n\n[Link](url)');
}

// AI Summarize function (placeholder)
async function aiSummarizeNote() {
    const btn = document.querySelector('.ai-summarize-btn');
    const originalText = btn.innerHTML;
    
    btn.innerHTML = '🤖 Organizing...';
    btn.disabled = true;
    
    try {
        const response = await fetch(`/api/notes/${currentNote.id}/summarize`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (handleTokenExpiration(response)) return;
        
        if (response.ok) {
            const data = await response.json();
            if (data.organized_content) {
                currentNote.markdown_content = data.organized_content;
                renderNoteDisplay();
                loadNotes();
                alert('Note organized successfully!');
            } else {
                alert('AI organization completed, but no changes were made.');
            }
        } else {
            const errorData = await response.json().catch(() => ({}));
            alert('AI organization failed: ' + (errorData.error || 'Unknown error'));
        }
    } catch (error) {
        console.error('AI summarize error:', error);
        alert('AI organization failed. Please check your connection.');
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
}

// Export to PDF function (placeholder)
function exportNoteToPDF() {
    alert('PDF export feature coming soon!');
}

// Legacy categorized content renderer
function renderCategorizedContent(categorizedContent) {
    if (!categorizedContent || Object.keys(categorizedContent).length === 0) {
        return `
            <div class="empty-category-section">
                <p>No content yet. This appears to be a legacy note format.</p>
            </div>
        `;
    }

    return Object.entries(categorizedContent).map(([category, categoryData]) => {
        let items = categoryData;
        
        if (categoryData && typeof categoryData === 'object' && categoryData.items) {
            items = categoryData.items;
        }

        if (!Array.isArray(items)) {
            items = [];
        }

        return `
            <div class="category-section">
                <div class="category-heading-wrapper">
                    <h3 class="category-heading">${escapeHtml(category)} <span class="category-item-count">(${items.length})</span></h3>
                </div>
                <div class="category-items-list">
                    ${renderCategoryItems(items, category)}
                </div>
            </div>
        `;
    }).join('');
}

// Render items within a category
function renderCategoryItems(items, category) {
    if (!items || items.length === 0) {
        return `<div class="empty-category"><p>No items in ${category} yet.</p></div>`;
    }

    const itemsHtml = items.map((item, index) => {
        let text = '';
        if (typeof item === 'string') {
            text = item;
        } else if (item && typeof item === 'object') {
            text = item.text || item.content || JSON.stringify(item);
        }

        return `
            <div class="category-list-item">
                <span class="item-bullet">•</span>
                <span class="item-text">${escapeHtml(text)}</span>
            </div>
        `;
    }).join('');

    return `<div class="category-list">${itemsHtml}</div>`;
} 