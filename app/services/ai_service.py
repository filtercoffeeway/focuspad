import os
import json
from openai import OpenAI

class AIService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
    
    def categorize_content(self, content, categories):
        """Categorize content using OpenAI's API."""
        try:
            categories_list = ', '.join(categories)
            
            prompt = f"""
Categorize the following content into these categories: {categories_list}

Content: {content}

Return a JSON object where each category is a key and the value is an array of relevant content items from the input. Only include categories that have relevant content.

Example format:
{{
    "Key Points": ["Important point 1", "Important point 2"],
    "Action Items": ["Task 1", "Task 2"]
}}
"""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that categorizes content. Always return valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=500,
                temperature=0.3
            )
            
            result = response.choices[0].message.content.strip()
            
            # Parse the JSON response
            try:
                categorized_content = json.loads(result)
                return categorized_content
            except json.JSONDecodeError as e:
                print(f"JSON decode error: {e}")
                print(f"Raw result: {result}")
                # Fallback: return content in first category
                return {categories[0]: [content]}
            
        except Exception as e:
            print(f"Error in categorize_content: {e}")
            # Fallback: return content in first category
            return {categories[0]: [content]}
    
    def suggest_title(self, content):
        """Suggest a title for the given content."""
        try:
            prompt = f"""
Based on the following content, suggest a concise and descriptive title (maximum 50 characters):

Content: {content[:500]}...

Respond with only the title, no quotes or additional text.
"""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that creates concise titles for content."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=20,
                temperature=0.3
            )
            
            title = response.choices[0].message.content.strip().strip('"\'')
            return title[:50]  # Ensure maximum length
            
        except Exception as e:
            print(f"Error in suggest_title: {e}")
            return "New Note"
    
    def generate_text(self, prompt, max_tokens=500):
        """Generate text using OpenAI's API - for summarization and other text generation tasks."""
        try:
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant that creates well-organized content."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=max_tokens,
                temperature=0.7
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            print(f"Error in generate_text: {e}")
            return "Error generating content"

    def extract_action_items(self, content, note_title, note_id):
        """Extract action items from note content using AI."""
        try:
            prompt = f"""
Analyze the following note content and extract any actionable tasks or to-do items. Look for:
- Explicit tasks (TODO, tasks, action items)
- Implicit actions (things that need to be done)
- Commitments or responsibilities mentioned
- Follow-up actions
- Deadlines or time-sensitive items

Note Title: {note_title}
Content:
{content}

Return a JSON array of action items. Each item should have:
- task_name: Clear, actionable description
- due_date: If mentioned (YYYY-MM-DD format, or null)
- priority: "high", "medium", or "low" based on urgency/importance
- status: "not-started" (default), "in-progress", or "completed"
- context: Brief context from the note

Only include genuine action items that require action. Avoid duplicates.
If no action items are found, return an empty array.

Example format:
[
    {{
        "task_name": "Review budget proposal",
        "due_date": "2024-01-15",
        "priority": "high",
        "status": "not-started",
        "context": "Meeting discussion about Q1 budget"
    }}
]
"""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are an expert at identifying actionable tasks from text. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=1000,
                temperature=0.3
            )
            
            result = response.choices[0].message.content.strip()
            
            # Parse the JSON response
            try:
                action_items_raw = json.loads(result)
                
                # Process and validate each item
                action_items = []
                for item in action_items_raw:
                    if isinstance(item, dict) and 'task_name' in item:
                        processed_item = {
                            'task_name': item.get('task_name', '').strip(),
                            'due_date': item.get('due_date'),
                            'priority': item.get('priority', 'medium'),
                            'status': item.get('status', 'not-started'),
                            'context': item.get('context', ''),
                            'note_id': note_id,
                            'note_title': note_title
                        }
                        
                        # Validate required fields
                        if processed_item['task_name']:
                            action_items.append(processed_item)
                
                return action_items
                
            except json.JSONDecodeError as e:
                print(f"JSON decode error in action item extraction: {e}")
                print(f"Raw result: {result}")
                return []
            
        except Exception as e:
            print(f"Error in extract_action_items: {e}")
            return [] 