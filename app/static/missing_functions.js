// Missing functions for dashboard.html

// Note: Global editing variables (editingStatusElement, editingCommentElement, etc.) 
// are already declared in the HTML file to avoid duplicate declarations

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
    const originalContent = currentNote ? currentNote.markdown_content : '';
    
    // Always update local content and UI
    if (currentNote) {
        currentNote.markdown_content = content;
    }
    
    // Update the display immediately
    const view = document.getElementById('markdownView');
    if (view) {
        view.innerHTML = renderMarkdown(content);
    }
    
    // Always exit edit mode
    container.classList.remove('edit-mode');
    
    // Only save to server if content has actually changed from what was originally loaded
    if (originalContent !== content) {
        saveNoteContentToServer(content);
    }
}

// Save note content to server only (separated from UI logic)
async function saveNoteContentToServer(content) {
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
            // Refresh sidebar to show updated timestamp
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

// Save note content to server (original function for backward compatibility)
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
                
                // Extract action items from this specific note only
                await extractActionItemsFromCurrentNote();
                
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

// Export to PDF function (updated with proper markdown-to-PDF conversion)
async function exportNoteToPDF() {
    console.log('PDF download function called');
    
    // Check if jsPDF library is loaded
    let jsPDF = null;
    
    if (typeof window.jspdf !== 'undefined' && window.jspdf.jsPDF) {
        jsPDF = window.jspdf.jsPDF;
        console.log('Found jsPDF via window.jspdf.jsPDF');
    } else if (typeof window.jsPDF !== 'undefined') {
        jsPDF = window.jsPDF;
        console.log('Found jsPDF via window.jsPDF');
    } else if (typeof jsPDF !== 'undefined') {
        console.log('Found jsPDF globally');
    } else {
        console.error('jsPDF library not found');
        alert('PDF library not loaded. Please refresh the page and try again.');
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
        // Create PDF document
        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'pt',
            format: 'a4'
        });

        const pageWidth = pdf.internal.pageSize.getWidth();
        const pageHeight = pdf.internal.pageSize.getHeight();
        const margin = 50;
        const maxWidth = pageWidth - (2 * margin);
        const maxHeight = pageHeight - (2 * margin);
        let yPosition = margin;

        // Function to add a new page if needed
        function checkPageBreak(requiredHeight = 20) {
            if (yPosition + requiredHeight > pageHeight - margin) {
                pdf.addPage();
                yPosition = margin;
                return true;
            }
            return false;
        }

        // Function to add text with word wrapping and pagination
        function addTextToPDF(text, fontSize = 11, fontStyle = 'normal', lineHeight = 16) {
            pdf.setFontSize(fontSize);
            pdf.setFont('helvetica', fontStyle);
            
            const lines = pdf.splitTextToSize(text, maxWidth);
            
            for (let i = 0; i < lines.length; i++) {
                checkPageBreak(lineHeight);
                pdf.text(lines[i], margin, yPosition);
                yPosition += lineHeight;
            }
            
            return yPosition;
        }

        // Add title
        addTextToPDF(noteTitle, 20, 'bold', 28);
        yPosition += 10;

        // Add metadata
        if (currentNote.created_at) {
            const dateStr = new Date(currentNote.created_at).toLocaleDateString();
            addTextToPDF('Date: ' + dateStr, 10, 'normal', 14);
        }

        if (currentNote.updated_at && currentNote.updated_at !== currentNote.created_at) {
            const updatedStr = new Date(currentNote.updated_at).toLocaleDateString();
            addTextToPDF('Last Updated: ' + updatedStr, 10, 'normal', 14);
        }

        if (currentNote.attendees) {
            addTextToPDF('Attendees: ' + currentNote.attendees, 10, 'normal', 14);
        }

        yPosition += 20; // Extra space before content

        // Get the content to export
        let contentToExport = '';
        
        if (currentNote.markdown_content && currentNote.markdown_content.trim()) {
            contentToExport = currentNote.markdown_content.trim();
        } else if (currentNote.raw_content && currentNote.raw_content.trim()) {
            contentToExport = currentNote.raw_content.trim();
        } else {
            contentToExport = 'No content available.';
        }

        // Parse and render markdown content
        function parseAndRenderMarkdown(content) {
            const lines = content.split('\n');
            let isCodeBlock = false;
            let codeBlockContent = '';
            let listLevel = 0;
            
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i];
                
                // Handle code blocks
                if (line.trim().startsWith('```')) {
                    if (isCodeBlock) {
                        // End of code block
                        if (codeBlockContent.trim()) {
                            checkPageBreak(20);
                            yPosition += 5;
                            // Add code block background (light gray)
                            pdf.setFillColor(245, 245, 245);
                            const codeHeight = codeBlockContent.split('\n').length * 12 + 10;
                            pdf.rect(margin - 5, yPosition - 5, maxWidth + 10, codeHeight, 'F');
                            
                            // Reset to normal style before adding code
                            pdf.setFontSize(9);
                            pdf.setFont('helvetica', 'normal');
                            const codeLines = pdf.splitTextToSize(codeBlockContent.trim(), maxWidth);
                            for (let j = 0; j < codeLines.length; j++) {
                                checkPageBreak(12);
                                pdf.text(codeLines[j], margin, yPosition);
                                yPosition += 12;
                            }
                            yPosition += 5;
                        }
                        isCodeBlock = false;
                        codeBlockContent = '';
                    } else {
                        // Start of code block
                        isCodeBlock = true;
                        codeBlockContent = '';
                    }
                    continue;
                }
                
                if (isCodeBlock) {
                    codeBlockContent += line + '\n';
                    continue;
                }
                
                // Handle headers
                if (line.match(/^#{1,6}\s/)) {
                    const headerLevel = line.match(/^#+/)[0].length;
                    const headerText = line.replace(/^#+\s*/, '');
                    
                    checkPageBreak(25);
                    yPosition += (headerLevel === 1) ? 15 : 10;
                    
                    const fontSize = headerLevel === 1 ? 18 : headerLevel === 2 ? 16 : 14;
                    addTextToPDF(headerText, fontSize, 'bold', fontSize + 5);
                    yPosition += 5;
                    continue;
                }
                
                // Handle bullet points
                if (line.match(/^\s*[-*+]\s/)) {
                    const indent = (line.length - line.trimLeft().length) / 2;
                    const bulletText = line.replace(/^\s*[-*+]\s/, '');
                    
                    checkPageBreak(16);
                    const indentSpace = margin + (indent * 20);
                    
                    // Reset font style for bullet and text
                    pdf.setFontSize(11);
                    pdf.setFont('helvetica', 'normal');
                    pdf.text('•', indentSpace, yPosition);
                    
                    const bulletLines = pdf.splitTextToSize(bulletText, maxWidth - (indent * 20) - 15);
                    for (let j = 0; j < bulletLines.length; j++) {
                        if (j > 0) checkPageBreak(14);
                        pdf.text(bulletLines[j], indentSpace + 15, yPosition);
                        if (j < bulletLines.length - 1) yPosition += 14;
                    }
                    yPosition += 16;
                    continue;
                }
                
                // Handle numbered lists
                if (line.match(/^\s*\d+\.\s/)) {
                    const listMatch = line.match(/^\s*(\d+)\.\s(.*)$/);
                    if (listMatch) {
                        const indent = (line.length - line.trimLeft().length) / 2;
                        const number = listMatch[1];
                        const listText = listMatch[2];
                        
                        checkPageBreak(16);
                        const indentSpace = margin + (indent * 20);
                        
                        // Reset font style for number and text
                        pdf.setFontSize(11);
                        pdf.setFont('helvetica', 'normal');
                        pdf.text(number + '.', indentSpace, yPosition);
                        
                        const listLines = pdf.splitTextToSize(listText, maxWidth - (indent * 20) - 25);
                        for (let j = 0; j < listLines.length; j++) {
                            if (j > 0) checkPageBreak(14);
                            pdf.text(listLines[j], indentSpace + 25, yPosition);
                            if (j < listLines.length - 1) yPosition += 14;
                        }
                        yPosition += 16;
                        continue;
                    }
                }
                
                // Handle blockquotes
                if (line.match(/^\s*>\s/)) {
                    const quoteText = line.replace(/^\s*>\s*/, '');
                    checkPageBreak(16);
                    
                    // Add vertical line for blockquote
                    pdf.setLineWidth(2);
                    pdf.setDrawColor(180, 180, 180);
                    pdf.line(margin, yPosition - 5, margin, yPosition + 10);
                    
                    // Set italic style for blockquote
                    pdf.setFontSize(11);
                    pdf.setFont('helvetica', 'italic');
                    const quoteLines = pdf.splitTextToSize(quoteText, maxWidth - 20);
                    for (let j = 0; j < quoteLines.length; j++) {
                        if (j > 0) checkPageBreak(14);
                        pdf.text(quoteLines[j], margin + 15, yPosition);
                        if (j < quoteLines.length - 1) yPosition += 14;
                    }
                    yPosition += 16;
                    // Reset font style back to normal after blockquote
                    pdf.setFont('helvetica', 'normal');
                    continue;
                }
                
                // Handle inline code
                if (line.includes('`')) {
                    line = line.replace(/`([^`]+)`/g, (match, code) => {
                        return code; // For now, just remove the backticks
                    });
                }
                
                // Handle bold and italic text (basic) - just remove formatting for now
                line = line.replace(/\*\*([^*]+)\*\*/g, '$1'); // Remove ** for bold
                line = line.replace(/\*([^*]+)\*/g, '$1'); // Remove * for italic
                
                // Handle empty lines
                if (line.trim() === '') {
                    yPosition += 8;
                    continue;
                }
                
                // Regular paragraph text - ensure normal font style
                if (line.trim()) {
                    // Always reset to normal style for regular text
                    addTextToPDF(line.trim(), 11, 'normal', 16);
                }
            }
        }

        // Process the content
        parseAndRenderMarkdown(contentToExport);

        // Add footer with page numbers
        const totalPages = pdf.internal.getNumberOfPages();
        for (let i = 1; i <= totalPages; i++) {
            pdf.setPage(i);
            pdf.setFontSize(8);
            pdf.setFont('helvetica', 'normal');
            pdf.text(`Page ${i} of ${totalPages}`, pageWidth - margin - 50, pageHeight - 20);
        }

        console.log('Saving PDF as:', safeNoteTitle + '.pdf');
        pdf.save(safeNoteTitle + '.pdf');
        
        console.log('PDF generation completed successfully');

    } catch (error) {
        console.error('Error generating PDF:', error);
        alert('Error generating PDF: ' + error.message + '\nCheck the browser console for more details.');
    } finally {
        // Restore button state
        if (pdfButton) {
            pdfButton.innerHTML = originalButtonText;
            pdfButton.disabled = false;
        }
        
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
                console.log('Notes array length before render:', notes.length);
                renderNotesList();
                
                // Force a small delay and re-render to ensure DOM updates
                setTimeout(() => {
                    console.log('Force re-rendering notes list after delay...');
                    renderNotesList();
                }, 100);
                
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

// Extract action items from the current note only
async function extractActionItemsFromCurrentNote() {
    if (!currentNote) {
        console.warn('No current note selected for action item extraction');
        return;
    }

    try {
        console.log('Extracting action items from current note:', currentNote.id);
        
        const response = await fetch('/api/notes/extract-action-items', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                note_id: currentNote.id
            })
        });

        if (handleTokenExpiration(response)) return;

        if (response.ok) {
            const data = await response.json();
            
            if (data.action_items && data.action_items.length > 0) {
                // Convert AI extracted items to our todo format
                const aiTodos = data.action_items.map(item => ({
                    id: `ai-${item.note_id}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
                    taskName: item.task_name,
                    dueDate: item.due_date,
                    status: item.status,
                    comments: `${item.context} (Priority: ${item.priority})`,
                    noteId: item.note_id,
                    noteName: item.note_title,
                    isAI: true,
                    priority: item.priority
                }));
                
                // Remove existing AI-extracted todos from this specific note to avoid duplicates
                if (typeof todos !== 'undefined' && Array.isArray(todos)) {
                    todos = todos.filter(todo => !(todo.isAI && todo.noteId === currentNote.id));
                    
                    // Add new AI-extracted todos
                    todos.push(...aiTodos);
                    
                    // Sort todos and save to storage
                    if (typeof sortTodos === 'function') {
                        todos = sortTodos(todos);
                    }
                    if (typeof saveTodosToStorage === 'function') {
                        saveTodosToStorage();
                    }
                    
                    // Update display if todo table is visible
                    if (typeof renderTodoTable === 'function' && document.getElementById('todoTableContainer')) {
                        renderTodoTable();
                    }
                }
                
                console.log(`✅ Extracted ${data.items_found} action items from current note`);
            } else {
                console.log('No action items found in current note');
            }
        } else {
            const errorData = await response.json().catch(() => ({}));
            console.error('Failed to extract action items:', errorData.error || 'Unknown error');
        }
        
    } catch (error) {
        console.error('Error extracting action items from current note:', error);
    }
}

// Extract action items from markdown content
function extractActionItemsFromMarkdown(markdownContent) {
    const actionItems = [];
    const actionItemPattern = /- \[ \] (.*)/g;
    let match;
    
    while ((match = actionItemPattern.exec(markdownContent)) !== null) {
        const actionItem = match[1].trim();
        if (actionItem) {
            actionItems.push(actionItem);
        }
    }
    
    return actionItems;
}

// Save action items to server
async function saveActionItemsToServer(actionItems) {
    if (!currentNote || !currentNote.id) {
        console.warn('No current note or no note ID to save action items');
        return;
    }

    try {
        const response = await fetch(`/api/notes/${currentNote.id}/action-items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                actionItems: actionItems
            })
        });

        if (handleTokenExpiration(response)) return;

        if (response.ok) {
            console.log('Action items saved successfully');
        } else {
            console.error('Failed to save action items');
        }
    } catch (error) {
        console.error('Error saving action items:', error);
        alert('Error saving action items. Please check the browser console for more details.');
    }
}

// Clear all todos function
function clearAllTodos() {
    if (!confirm('Are you sure you want to clear all tasks? This action cannot be undone.')) {
        return;
    }
    
    try {
        // Clear the todos array
        todos = [];
        
        // Save empty array to storage
        saveTodosToStorage();
        
        // Set the cleared flag
        localStorage.setItem('focuspad-todos-cleared', 'true');
        
        // Re-render the todo table
        renderTodoTable();
        
        console.log('✅ All todos cleared successfully');
    } catch (error) {
        console.error('Error clearing todos:', error);
        alert('Error clearing todos. Please try again.');
    }
}

function startEditingStatus(element) {
    // Close any open editing
    closeAllEditing();

    editingStatusElement = element;
    
    // Get current status from todo object
    const todoId = element.getAttribute('data-todo-id');
    const todo = todos.find(t => t.id === todoId);
    const status = todo ? todo.status : 'not-started';
    
    element.classList.add('editing');
    
    // Get element position for fixed positioning
    const rect = element.getBoundingClientRect();
    
    // Create dropdown
    const dropdown = document.createElement('div');
    dropdown.className = 'todo-status-dropdown show';
    
    // Position the dropdown using fixed positioning
    dropdown.style.top = (rect.bottom + 4) + 'px';
    dropdown.style.left = rect.left + 'px';
    
    dropdown.innerHTML = `
        <div class="todo-status-option not-started ${status === 'not-started' ? 'selected' : ''}" data-status="not-started">Not Started</div>
        <div class="todo-status-option in-progress ${status === 'in-progress' ? 'selected' : ''}" data-status="in-progress">In Progress</div>
        <div class="todo-status-option completed ${status === 'completed' ? 'selected' : ''}" data-status="completed">Completed</div>
    `;
    
    // Add click handlers to the options
    const options = dropdown.querySelectorAll('.todo-status-option');
    
    options.forEach(option => {
        option.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            const selectedStatus = this.getAttribute('data-status');
            selectStatus(this, selectedStatus);
        });
    });
    
    // Append to body instead of element for fixed positioning
    document.body.appendChild(dropdown);
    
    // Force a reflow to ensure the dropdown is properly rendered
    dropdown.offsetHeight;
    
    // Add class to container to handle overflow if needed
    const container = document.querySelector('.todo-table-container');
    if (container) {
        container.classList.add('dropdown-open');
    }
}

function closeStatusEditing() {
    if (editingStatusElement) {
        // Remove dropdown from body (since we're now appending to body)
        const dropdown = document.querySelector('.todo-status-dropdown');
        if (dropdown) {
            dropdown.remove();
        }
        editingStatusElement.classList.remove('editing');
        editingStatusElement = null;
        
        // Remove overflow class from container
        const container = document.querySelector('.todo-table-container');
        if (container) {
            container.classList.remove('dropdown-open');
        }
    }
}

function selectStatus(optionElement, status) {
    console.log('selectStatus called with status:', status);
    
    // Since dropdown is now in body, we need to get the editing element directly
    if (!editingStatusElement) {
        console.error('No editing status element found');
        return;
    }
    
    const todoId = editingStatusElement.getAttribute('data-todo-id');
    console.log('Updating todo with ID:', todoId, 'to status:', status);
    
    // Update todo object
    const todoIndex = todos.findIndex(todo => todo.id === todoId);
    if (todoIndex !== -1) {
        console.log('Found todo at index:', todoIndex);
        todos[todoIndex].status = status;
        
        // Save to storage for all todos
        saveTodosToStorage();
        
        // Update UI inline instead of re-rendering
        editingStatusElement.className = `todo-status-editable todo-status ${status}`;
        editingStatusElement.textContent = status.replace('-', ' ');
        
        console.log('Updated UI element with new status');
        
        // Show saved feedback
        showSavedFeedback(editingStatusElement);
    } else {
        console.error('Todo not found with ID:', todoId);
    }
    
    closeStatusEditing();
}

function showSavedFeedback(element) {
    element.classList.add('saved');
    setTimeout(() => {
        element.classList.remove('saved');
    }, 1000);
}

function closeAllEditing() {
    // Close comment editing
    if (typeof editingCommentElement !== 'undefined' && editingCommentElement) {
        if (typeof exitEditMode === 'function') {
            exitEditMode(editingCommentElement);
        }
    }
    
    // Close field editing
    if (typeof editingElement !== 'undefined' && editingElement) {
        if (typeof exitFieldEditMode === 'function') {
            exitFieldEditMode(editingElement);
        }
    }
    
    // Close date editing  
    if (typeof editingDateElement !== 'undefined' && editingDateElement) {
        if (typeof closeDateEditing === 'function') {
            closeDateEditing();
        }
    }
    
    // Close status editing
    if (typeof editingStatusElement !== 'undefined' && editingStatusElement) {
        closeStatusEditing();
    }
}

// Enhanced global click handler for external JS file functions
document.addEventListener('click', function(event) {
    // Handle status editing with fixed positioning
    if (editingStatusElement) {
        const dropdown = document.querySelector('.todo-status-dropdown');
        const clickedInDropdown = dropdown && dropdown.contains(event.target);
        const clickedOnEditingElement = editingStatusElement.contains(event.target);
        
        // Only close if clicking outside both the dropdown and the editing element
        if (!clickedInDropdown && !clickedOnEditingElement) {
            closeStatusEditing();
        }
    }
}, true); // Use capture phase to ensure we get the event first 