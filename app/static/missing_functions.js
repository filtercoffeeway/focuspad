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
                    <button class="markdown-control-btn ai-summarize-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-control-btn" onclick="exportNoteToPDF()" title="Export as PDF">
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
                    <button class="markdown-control-btn ai-summarize-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-control-btn" onclick="exportNoteToPDF()" title="Export as PDF">
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
                    <button class="markdown-control-btn ai-summarize-btn" onclick="aiSummarizeNote()" title="AI Organize Note Content">
                        🤖 AI Organize
                    </button>
                    <button class="markdown-control-btn" onclick="exportNoteToPDF()" title="Export as PDF">
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

// AI Summarize function (updated with correct implementation)
async function aiSummarizeNote() {
    console.log('AI Organize function called');
    
    if (!currentNote) {
        alert('Please select a note first.');
        return;
    }
    
    // Check if access token is available
    if (!accessToken || accessToken === 'None' || accessToken === '') {
        console.error('No access token available for AI organization');
        alert('Authentication required. Please log in again.');
        window.location.href = '/login';
        return;
    }
    
    // Get current markdown content
    const markdownEditor = document.getElementById('markdownEditor');
    const currentContent = markdownEditor ? markdownEditor.value : (currentNote.markdown_content || '');
    
    if (!currentContent || currentContent.trim().length === 0) {
        alert('Please add some content to your note before organizing.');
        return;
    }
    
    // Update button state
    const aiButton = document.querySelector('.markdown-control-btn.ai-summarize-btn');
    const originalButtonText = aiButton ? aiButton.innerHTML : '';
    if (aiButton) {
        aiButton.innerHTML = '🤖 Organizing...';
        aiButton.disabled = true;
    }
    
    try {
        console.log('Sending content to AI for organization...');
        console.log('Content length:', currentContent.length);
        console.log('Using access token:', accessToken ? 'Available' : 'Missing');
        
        const response = await fetch(`/api/notes/${currentNote.id}/ai-summarize`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                content: currentContent
            })
        });
        
        console.log('AI Organize response status:', response.status);
        
        if (handleTokenExpiration(response)) return;
        
        if (response.ok) {
            const responseData = await response.json();
            console.log('AI Organize response:', responseData);
            
            // Update the markdown content with AI-organized content
            const organizedContent = responseData.summarized_content || responseData.content;
            
            if (organizedContent) {
                // Update local content
                currentNote.markdown_content = organizedContent;
                
                // Update editor if in edit mode
                if (markdownEditor) {
                    markdownEditor.value = organizedContent;
                }
                
                // Update view
                const view = document.getElementById('markdownView');
                if (view) {
                    view.innerHTML = renderMarkdown(organizedContent);
                }
                
                // Refresh notes list
                await loadNotes();
                
                // Show success feedback
                if (aiButton) {
                    aiButton.innerHTML = '✅ Organized!';
                    aiButton.style.background = 'linear-gradient(135deg, #10b981, #059669)';
                }
                
                setTimeout(() => {
                    if (aiButton) {
                        aiButton.innerHTML = originalButtonText;
                        aiButton.style.background = '';
                        aiButton.disabled = false;
                    }
                }, 3000);
                
                console.log('Content organized successfully');
            } else {
                throw new Error('No organized content received from AI service');
            }
        } else {
            const errorData = await response.json().catch(() => ({}));
            const errorMessage = errorData.error || `API Error: ${response.status}`;
            
            console.error('AI Organization failed:', errorMessage);
            
            // Provide specific error messages based on status code
            if (response.status === 503) {
                alert('AI service is currently unavailable. Please check your OpenAI API key configuration or try again later.');
            } else if (response.status === 400) {
                alert('Invalid content provided for organization. Please check your note content.');
            } else if (response.status === 404) {
                alert('Note not found. Please refresh the page and try again.');
            } else if (response.status === 500) {
                alert('AI organization failed due to a server error. Please try again or contact support if the issue persists.');
            } else {
                alert(`AI Organization failed: ${errorMessage}`);
            }
            
            throw new Error(errorMessage);
        }
    } catch (error) {
        console.error('AI Organization error:', error);
        alert('AI organization failed. Please check your connection and try again.');
    } finally {
        // Restore button state
        if (aiButton) {
            aiButton.innerHTML = originalButtonText;
            aiButton.disabled = false;
        }
    }
}

// Export to PDF function (updated with full implementation)
async function exportNoteToPDF() {
    console.log('PDF download function called');
    
    // Check if libraries are loaded with multiple fallbacks
    let jsPDF = null;
    
    if (typeof window.jspdf !== 'undefined' && window.jspdf.jsPDF) {
        jsPDF = window.jspdf.jsPDF;
        console.log('Found jsPDF via window.jspdf.jsPDF');
    } else if (typeof window.jsPDF !== 'undefined') {
        jsPDF = window.jsPDF;
        console.log('Found jsPDF via window.jsPDF');
    } else if (typeof jsPDF !== 'undefined') {
        // Sometimes it's available globally
        console.log('Found jsPDF globally');
    } else {
        console.error('jsPDF library not found in any expected location');
        console.log('Available on window:', Object.keys(window).filter(key => key.toLowerCase().includes('pdf')));
        alert('PDF library not loaded. Please refresh the page and try again.\n\nIf the problem persists, there may be a network issue preventing the library from loading.');
        return;
    }
    
    if (typeof html2canvas === 'undefined') {
        console.error('html2canvas library not loaded');
        alert('Canvas library not loaded. Please refresh the page and try again.');
        return;
    }
    
    const noteContentElement = document.getElementById('noteDisplay') || document.getElementById('noteContentForPdf');
    
    if (!noteContentElement) {
        console.error('noteContentForPdf element not found');
        alert('Could not find note content to export.');
        return;
    }
    
    if (!currentNote) {
        alert('No note selected to export.');
        return;
    }

    const noteTitle = getFirstLineAsTitle(currentNote) || 'FocusPad_Note';
    const safeNoteTitle = noteTitle.replace(/[^a-z0-9]/gi, '_').toLowerCase();
    
    console.log('Starting PDF generation for:', noteTitle);

    // Update button state
    const pdfButton = document.querySelector('.markdown-control-btn[onclick*="exportNoteToPDF"]');
    const originalButtonText = pdfButton ? pdfButton.innerHTML : '';
    if (pdfButton) {
        pdfButton.innerHTML = '📄 Generating...';
        pdfButton.disabled = true;
    }

    try {
        console.log('Hiding action elements...');
        // Hide action buttons and interactive elements
        const actionElements = noteContentElement.querySelectorAll('.category-actions-inline, .item-actions, .note-actions-bar, .markdown-controls, .note-actions');
        const clickableElements = noteContentElement.querySelectorAll('.clickable span');
        
        actionElements.forEach(el => {
            el.style.setProperty('visibility', 'hidden', 'important');
        });
        clickableElements.forEach(el => {
            if (el.style.color && el.style.color.includes('--text-muted')) {
                el.style.setProperty('visibility', 'hidden', 'important');
            }
        });

        // Temporarily disable contenteditable
        const editableFields = noteContentElement.querySelectorAll('[contenteditable="true"]');
        editableFields.forEach(el => el.setAttribute('contenteditable', 'false'));

        console.log('Capturing content with html2canvas...');
        
        const canvas = await html2canvas(noteContentElement, {
            scale: 2,
            useCORS: true,
            logging: true, // Enable logging for debugging
            backgroundColor: '#ffffff',
            width: noteContentElement.scrollWidth,
            height: noteContentElement.scrollHeight,
            onclone: (clonedDoc) => {
                console.log('html2canvas onclone called');
                // Ensure good styling for PDF
                const clonedElement = clonedDoc.getElementById('noteDisplay') || clonedDoc.getElementById('noteContentForPdf');
                if (clonedElement) {
                    clonedElement.style.background = '#ffffff';
                    clonedElement.style.color = '#000000';
                }
            }
        });
        
        console.log('Canvas created:', canvas.width + 'x' + canvas.height);
        
        // Restore visibility and editability
        actionElements.forEach(el => el.style.visibility = 'visible');
        clickableElements.forEach(el => el.style.visibility = 'visible');
        editableFields.forEach(el => el.setAttribute('contenteditable', 'true'));

        console.log('Creating PDF document...');
        
        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'pt',
            format: 'a4'
        });

        const pdfWidth = pdf.internal.pageSize.getWidth();
        const pdfHeight = pdf.internal.pageSize.getHeight();
        const margin = 40;
        
        // Calculate scaling to fit page
        const availableWidth = pdfWidth - (2 * margin);
        const availableHeight = pdfHeight - (2 * margin);
        
        const imgAspectRatio = canvas.width / canvas.height;
        let imgWidth = availableWidth;
        let imgHeight = availableWidth / imgAspectRatio;
        
        // If image is too tall, scale to fit height
        if (imgHeight > availableHeight) {
            imgHeight = availableHeight;
            imgWidth = availableHeight * imgAspectRatio;
        }
        
        // Center the image
        const x = (pdfWidth - imgWidth) / 2;
        const y = (pdfHeight - imgHeight) / 2;
        
        // Convert canvas to image data
        const imgData = canvas.toDataURL('image/png');
        console.log('Image data created, adding to PDF...');
        
        // Add image to PDF
        pdf.addImage(imgData, 'PNG', x, y, imgWidth, imgHeight);
        
        console.log('Saving PDF as:', safeNoteTitle + '.pdf');
        
        // Save the PDF
        pdf.save(safeNoteTitle + '.pdf');
        
        console.log('PDF generation completed successfully');

    } catch (error) {
        console.error('Error generating PDF:', error);
        
        // Fallback: Create a text-based PDF if html2canvas fails
        console.log('Attempting fallback text-based PDF...');
        try {
            const pdf = new jsPDF({
                orientation: 'portrait',
                unit: 'pt',
                format: 'a4'
            });
            
            let yPosition = 50;
            const lineHeight = 20;
            const margin = 40;
            const pageWidth = pdf.internal.pageSize.getWidth();
            const maxWidth = pageWidth - (2 * margin);
            
            // Add title
            pdf.setFontSize(18);
            pdf.text(noteTitle, margin, yPosition);
            yPosition += lineHeight * 2;
            
            // Add date
            pdf.setFontSize(12);
            if (currentNote.created_at) {
                const dateStr = new Date(currentNote.created_at).toLocaleDateString();
                pdf.text('Date: ' + dateStr, margin, yPosition);
                yPosition += lineHeight;
            }
            
            // Add attendees if present
            if (currentNote.attendees) {
                pdf.text('Attendees: ' + currentNote.attendees, margin, yPosition);
                yPosition += lineHeight;
            }
            
            yPosition += lineHeight; // Extra space
            
            // Add markdown content if available
            if (currentNote.markdown_content) {
                pdf.setFontSize(14);
                pdf.text('Content:', margin, yPosition);
                yPosition += lineHeight;
                
                pdf.setFontSize(11);
                const lines = pdf.splitTextToSize(currentNote.markdown_content, maxWidth);
                for (let i = 0; i < lines.length; i++) {
                    if (yPosition > pdf.internal.pageSize.getHeight() - 50) {
                        pdf.addPage();
                        yPosition = 50;
                    }
                    pdf.text(lines[i], margin, yPosition);
                    yPosition += lineHeight;
                }
            }
            
            // Add raw content if available and no markdown content
            if (!currentNote.markdown_content && currentNote.raw_content) {
                pdf.setFontSize(14);
                pdf.text('Content:', margin, yPosition);
                yPosition += lineHeight;
                
                pdf.setFontSize(11);
                const lines = pdf.splitTextToSize(currentNote.raw_content, maxWidth);
                for (let i = 0; i < lines.length; i++) {
                    if (yPosition > pdf.internal.pageSize.getHeight() - 50) {
                        pdf.addPage();
                        yPosition = 50;
                    }
                    pdf.text(lines[i], margin, yPosition);
                    yPosition += lineHeight;
                }
            }
            
            pdf.save(safeNoteTitle + '_text.pdf');
            console.log('Fallback text-based PDF generated successfully');
            alert('PDF generated successfully (text-only fallback due to rendering issue).');
            
        } catch (fallbackError) {
            console.error('Fallback PDF generation also failed:', fallbackError);
            alert('Error generating PDF: ' + error.message + '\nFallback also failed: ' + fallbackError.message + '\nCheck the browser console for more details.');
        }
    } finally {
        // Restore button state
        if (pdfButton) {
            pdfButton.innerHTML = originalButtonText;
            pdfButton.disabled = false;
        }
        
        // Ensure elements are restored even if there was an error
        const allActionElements = noteContentElement.querySelectorAll('.category-actions-inline, .item-actions, .note-actions-bar, .clickable span, .markdown-controls, .note-actions');
        allActionElements.forEach(el => el.style.visibility = 'visible');
        
        const allEditableFields = noteContentElement.querySelectorAll('[contenteditable="false"]');
        allEditableFields.forEach(el => el.setAttribute('contenteditable', 'true'));
        
        console.log('PDF generation cleanup completed');
    }
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

// Delete note function
async function deleteNote(noteId, event) {
    // Prevent the click event from bubbling up to selectNote
    event.stopPropagation();
    
    console.log('Deleting note with ID:', noteId);
    
    if (!noteId || noteId === 'undefined') {
        console.error('Invalid note ID:', noteId);
        alert('Invalid note ID. Please try refreshing the page.');
        return;
    }
    
    // Find the note to get its title for confirmation - with error handling
    let noteTitle = 'this note';
    try {
        const noteToDelete = notes.find(note => note.id === noteId);
        if (noteToDelete) {
            // Use only the first line as title, don't use the stored title field
            noteTitle = getFirstLineAsTitle(noteToDelete) || `Note ${noteId}`;
        }
    } catch (error) {
        console.warn('Error getting note title for deletion:', error);
        noteTitle = `Note ${noteId}`;
    }
    
    // Confirm deletion
    if (!confirm(`Are you sure you want to delete "${noteTitle}"? This action cannot be undone.`)) {
        return;
    }
    
    try {
        console.log('Sending delete request...');
        const response = await fetch(`/api/notes/${noteId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${accessToken}`
            }
        });
        
        console.log('Delete note response status:', response.status);
        console.log('Response ok:', response.ok);
        
        if (handleTokenExpiration(response)) {
            console.log('Token expiration handled, returning...');
            return;
        }
        
        if (response.ok) {
            console.log('Delete response was ok, processing...');
            
            try {
                // Remove note from local array
                const noteIndex = notes.findIndex(note => note.id === noteId);
                if (noteIndex !== -1) {
                    notes.splice(noteIndex, 1);
                    console.log(`Removed note from local array at index ${noteIndex}`);
                } else {
                    console.warn('Note not found in local array');
                }
            } catch (error) {
                console.error('Error removing note from local array:', error);
            }
            
            try {
                // Clear the display if this was the current note
                if (currentNote && currentNote.id === noteId) {
                    currentNote = null;
                    renderNoteDisplay();
                    console.log('Cleared current note display');
                }
            } catch (error) {
                console.error('Error clearing current note display:', error);
            }
            
            try {
                // Update the notes list display
                console.log('Refreshing notes list...');
                renderNotesList();
            } catch (error) {
                console.error('Error rendering notes list:', error);
            }
            
            console.log('✅ Note deleted successfully');
        } else {
            console.error('Delete request failed with status:', response.status);
            
            let errorMessage = 'Failed to delete note.';
            try {
                const errorText = await response.text();
                console.log('Error response text:', errorText);
                
                try {
                    const errorJson = JSON.parse(errorText);
                    if (errorJson.error) {
                        errorMessage += ' ' + errorJson.error;
                    }
                } catch (parseError) {
                    console.log('Error response is not JSON:', parseError);
                    errorMessage += ' ' + errorText;
                }
            } catch (textError) {
                console.error('Failed to read error response:', textError);
                errorMessage += ' Unknown server error.';
            }
            
            console.error('Final error message:', errorMessage);
            alert(errorMessage);
        }
    } catch (error) {
        console.error('Network/unexpected error deleting note:', error);
        alert('Network error deleting note. Please check your connection and try again.');
    }
}

// Delete todo function
function deleteTodo(todoId) {
    console.log('Deleting todo with ID:', todoId);
    
    if (!todoId) {
        console.error('Invalid todo ID:', todoId);
        alert('Invalid todo ID. Please try refreshing the page.');
        return;
    }
    
    // Find the todo to get its name for confirmation
    let todoName = 'this task';
    try {
        const todoToDelete = todos.find(todo => todo.id === todoId);
        if (todoToDelete) {
            todoName = todoToDelete.taskName || 'this task';
        }
    } catch (error) {
        console.warn('Error getting todo name for deletion:', error);
        todoName = 'this task';
    }
    
    // Confirm deletion
    if (!confirm(`Are you sure you want to delete "${todoName}"? This action cannot be undone.`)) {
        return;
    }
    
    try {
        // Remove todo from local array
        const todoIndex = todos.findIndex(todo => todo.id === todoId);
        if (todoIndex !== -1) {
            todos.splice(todoIndex, 1);
            console.log(`Removed todo from local array at index ${todoIndex}`);
            
            // Save updated todos to localStorage
            saveTodosToStorage();
            
            // Re-render the todo table
            renderTodoTable();
            
            console.log('✅ Todo deleted successfully');
        } else {
            console.warn('Todo not found in local array');
            alert('Todo not found. Please try refreshing the page.');
        }
    } catch (error) {
        console.error('Error deleting todo:', error);
        alert('Error deleting todo. Please try again.');
    }
}

// Helper function to get first line as title (should already exist but adding for safety)
function getFirstLineAsTitle(note) {
    // First try markdown_content as it's the primary content
    if (note.markdown_content && note.markdown_content.trim()) {
        let text = note.markdown_content.trim();
        // Remove markdown formatting
        text = text.replace(/#+\s+/g, '');  // Remove headers
        text = text.replace(/\*\*([^*]+)\*\*/g, '$1');  // Remove bold
        text = text.replace(/\*([^*]+)\*/g, '$1');  // Remove italic
        text = text.replace(/`([^`]+)`/g, '$1');  // Remove code
        text = text.replace(/^[\-\*]\s+/gm, '');  // Remove bullet points
        text = text.replace(/^\>\s+/gm, '');  // Remove blockquotes
        
        // Get the first line
        const firstLine = text.split('\n')[0].trim();
        if (firstLine) {
            return firstLine.length > 50 ? firstLine.substring(0, 50) + '...' : firstLine;
        }
    }
    
    // Fallback to raw_content if no markdown content
    if (note.raw_content && note.raw_content.trim()) {
        const firstLine = note.raw_content.trim().split('\n')[0];
        return firstLine.length > 50 ? firstLine.substring(0, 50) + '...' : firstLine;
    }
    
    // Final fallback
    return 'Untitled Note';
}

// Helper function to save todos to localStorage
function saveTodosToStorage() {
    try {
        localStorage.setItem('focuspad_todos', JSON.stringify(todos));
    } catch (error) {
        console.error('Error saving todos to localStorage:', error);
    }
}

// Helper function to load todos from localStorage
function loadTodosFromStorage() {
    try {
        const storedTodos = localStorage.getItem('focuspad_todos');
        if (storedTodos) {
            todos = JSON.parse(storedTodos);
        }
    } catch (error) {
        console.error('Error loading todos from localStorage:', error);
        todos = [];
    }
}

// Function to handle token expiration and redirect to login
function handleTokenExpiration(response) {
    if (response.status === 401) {
        // Clone the response to avoid consuming the original stream
        const clonedResponse = response.clone();
        
        // Check if the error message indicates token expiration
        clonedResponse.json().then(data => {
            if (data.msg && data.msg.includes('expired')) {
                console.log('Token has expired, redirecting to login...');
                alert('Your session has expired. Please log in again.');
                window.location.href = '/';
            }
        }).catch(() => {
            // If we can't parse the response, just redirect anyway for 401
            console.log('401 error detected, redirecting to login...');
            alert('Your session has expired. Please log in again.');
            window.location.href = '/';
        });
        return true; // Token expired
    }
    return false; // Token still valid
}

// Render notes list in sidebar
function renderNotesList() {
    const notesList = document.getElementById('notesList');
    
    if (notes.length === 0) {
        notesList.innerHTML = '<div style="padding: 20px; color: #999; text-align: center;">No notes yet.<br>Create your first note!</div>';
        return;
    }

    // Sort by updated_at (most recent first)
    const sortedNotes = [...notes].sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));

    notesList.innerHTML = sortedNotes.map(note => `
        <div class="note-item" onclick="selectNote(${note.id})" data-note-id="${note.id}">
            <div class="note-header-row">
                <div class="note-title">${escapeHtml(getFirstLineAsTitle(note))}</div>
                <div class="note-actions">
                    <button class="delete-btn" onclick="deleteNote(${note.id}, event)" title="Delete note">🗑️</button>
                </div>
            </div>
            <div class="note-preview">${escapeHtml(getPreviewText(note))}</div>
            <div class="note-date">${formatDate(note.updated_at)}</div>
        </div>
    `).join('');
}

// Get preview text from note content
function getPreviewText(note) {
    // First try markdown_content
    if (note.markdown_content && note.markdown_content.trim()) {
        let text = note.markdown_content.trim();
        // Remove markdown formatting
        text = text.replace(/#+\s+/g, '');  // Remove headers
        text = text.replace(/\*\*([^*]+)\*\*/g, '$1');  // Remove bold
        text = text.replace(/\*([^*]+)\*/g, '$1');  // Remove italic
        text = text.replace(/`([^`]+)`/g, '$1');  // Remove code
        text = text.replace(/^[\-\*]\s+/gm, '');  // Remove bullet points
        text = text.replace(/^\>\s+/gm, '');  // Remove blockquotes
        
        // Get first few lines, skip the first line if it's already used as title
        const lines = text.split('\n').filter(line => line.trim());
        const preview = lines.slice(1).join(' ').trim();
        return preview.length > 100 ? preview.substring(0, 100) + '...' : preview;
    }
    
    // Fallback to raw_content
    if (note.raw_content && note.raw_content.trim()) {
        const lines = note.raw_content.trim().split('\n').filter(line => line.trim());
        const preview = lines.slice(1).join(' ').trim();
        return preview.length > 100 ? preview.substring(0, 100) + '...' : preview;
    }
    
    return 'No content';
}

// Format date for display
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays === 1) {
        return 'Today';
    } else if (diffDays === 2) {
        return 'Yesterday';
    } else if (diffDays <= 7) {
        return `${diffDays - 1} days ago`;
    } else {
        return date.toLocaleDateString();
    }
}

// Select note function
function selectNote(noteId) {
    const note = notes.find(n => n.id === noteId);
    if (note) {
        currentNote = note;
        renderNoteDisplay();
        
        // Update active state in sidebar
        document.querySelectorAll('.note-item').forEach(item => {
            item.classList.remove('active');
        });
        
        const activeItem = document.querySelector(`[data-note-id="${noteId}"]`);
        if (activeItem) {
            activeItem.classList.add('active');
        }
    }
}

// Render todo table
function renderTodoTable() {
    const container = document.getElementById('todoTableContainer');
    if (!container) return; // Exit if container doesn't exist
    
    const filteredTodos = showCompleted ? todos : todos.filter(todo => todo.status !== 'completed');
    
    if (filteredTodos.length === 0) {
        container.innerHTML = `
            <div class="empty-todo-state">
                <div class="empty-todo-icon">📋</div>
                <h3>${todos.length > 0 ? 'All Tasks Completed!' : 'No Tasks Yet'}</h3>
                <p>${todos.length > 0 ? 
                    'Great job! All your tasks are completed.<br>Toggle "Show completed" to see them.' : 
                    'Create notes with to-do items and they will automatically appear here.<br>Use formats like:<br>• "TODO: Task description"<br>• "[ ] Task to complete"<br>• "- [ ] Another task format"<br><br>Or click "Add Task" to create tasks manually.'
                }</p>
            </div>
        `;
        return;
    }
    
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];
    const tomorrowStr = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    container.innerHTML = `
        <table class="todo-table">
            <thead>
                <tr>
                    <th>Task Name</th>
                    <th>Due Date</th>
                    <th>Status</th>
                    <th>Comments</th>
                    <th style="width: 60px;">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${filteredTodos.map(todo => {
                    let dueDateClass = '';
                    let dueDateText = todo.dueDate || '-';
                    
                    if (todo.dueDate) {
                        // Format date without timezone conversion
                        const dateStr = todo.dueDate;
                        dueDateText = new Date(dateStr + 'T00:00:00').toLocaleDateString();
                        
                        if (todo.dueDate < todayStr) {
                            dueDateClass = 'overdue';
                        } else if (todo.dueDate === todayStr || todo.dueDate === tomorrowStr) {
                            dueDateClass = 'due-soon';
                        }
                    }
                    
                    const clickHandler = todo.isManual ? '' : 
                        (todo.noteId ? `onclick="handleTodoRowClick(event, '${todo.noteId}')"` : '');
                    const cursorStyle = (todo.isManual || !todo.noteId) ? '' : 'style="cursor: pointer;"';
                    
                    return `
                        <tr ${clickHandler} ${cursorStyle}>
                            <td class="todo-task-name">
                                <div class="todo-task-editable" 
                                     data-todo-id="${todo.id}"
                                     data-field="taskName"
                                     onclick="event.stopPropagation(); startEditingField(this, 'taskName')"
                                     onblur="saveField(this, 'taskName')"
                                     onkeydown="handleFieldKeydown(event, this, 'taskName')"
                                     title="Click to edit task name">${escapeHtml(todo.taskName)}</div>
                            </td>
                            <td class="todo-due-date ${dueDateClass}">
                                <div class="todo-due-date-editable" 
                                     data-todo-id="${todo.id}"
                                     data-field="dueDate"
                                     onclick="event.stopPropagation(); startEditingDate(this)"
                                     title="Click to edit due date">${dueDateText}</div>
                            </td>
                            <td>
                                <div class="todo-status-editable todo-status ${todo.status}" 
                                     data-todo-id="${todo.id}"
                                     data-field="status"
                                     onclick="event.stopPropagation(); startEditingStatus(this)"
                                     title="Click to change status">${todo.status.replace('-', ' ')}</div>
                            </td>
                            <td class="todo-comments">
                                <div class="todo-comments-editable" 
                                     data-todo-id="${todo.id}"
                                     onclick="event.stopPropagation(); startEditingComment(this)"
                                     onblur="saveComment(this)"
                                     onkeydown="handleCommentKeydown(event, this)"
                                     title="Click to edit comments">${escapeHtml(todo.comments || '')}</div>
                            </td>
                            <td class="todo-actions">
                                <button class="delete-todo-btn" onclick="event.stopPropagation(); deleteTodo('${todo.id}')" title="Delete task">🗑️</button>
                            </td>
                        </tr>
                    `;
                }).join('')}
            </tbody>
        </table>
    `;
}

// Load notes from API
async function loadNotes() {
    console.log('Loading notes...');
    try {
        const response = await fetch('/api/notes/', {
            headers: {
                'Authorization': `Bearer ${accessToken}`
            }
        });
        
        console.log('Notes response status:', response.status);
        
        if (handleTokenExpiration(response)) return Promise.reject(new Error('Token expired'));
        
        if (response.ok) {
            const data = await response.json();
            notes = data.notes || [];
            console.log('Loaded notes:', notes.length);
            renderNotesList();
            return Promise.resolve();
        } else {
            console.error('Failed to load notes, status:', response.status);
            const errorText = await response.text();
            console.error('Error response:', errorText);
            const notesList = document.getElementById('notesList');
            if (notesList) {
                notesList.innerHTML = '<div style="padding: 20px; color: #999;">Failed to load notes. Try refreshing the page.</div>';
            }
            return Promise.reject(new Error('Failed to load notes'));
        }
    } catch (error) {
        console.error('Error loading notes:', error);
        const notesList = document.getElementById('notesList');
        if (notesList) {
            notesList.innerHTML = '<div style="padding: 20px; color: #999;">Error loading notes. Check your connection.</div>';
        }
        return Promise.reject(error);
    }
} 