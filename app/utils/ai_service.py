"""
AI service for content categorization using OpenAI.
"""

import os
import json
from flask import current_app

class AIService:
    """Service for AI-powered content categorization."""
    
    def __init__(self):
        self.client = None
        self._initialize_client()
    
    def _initialize_client(self):
        """Initialize OpenAI client with error handling."""
        try:
            api_key = os.environ.get('OPENAI_API_KEY')
            if not api_key:
                print("Warning: OPENAI_API_KEY not found in environment variables. AI features will be disabled.")
                self.client = None
                return
            
            from openai import OpenAI
            
            # Simple initialization without testing - avoid potential version compatibility issues
            try:
                self.client = OpenAI(api_key=api_key)
                print("✅ OpenAI client initialized successfully")
                return
            except Exception as e:
                print(f"Warning: OpenAI client initialization failed: {str(e)}")
                
            # If initialization fails, disable AI features
            self.client = None
            print("❌ AI features will be disabled due to OpenAI client initialization failure.")
            
        except ImportError as e:
            print(f"Warning: OpenAI package not available: {str(e)}. AI features will be disabled.")
            self.client = None
        except Exception as e:
            print(f"Warning: Unexpected error during OpenAI client initialization: {str(e)}. AI features will be disabled.")
            self.client = None
    
    def is_available(self):
        """Check if AI service is available."""
        return self.client is not None
    
    def categorize_content(self, text, categories):
        """
        Categorize given text into predefined categories using OpenAI.
        
        Args:
            text (str): The text content to categorize
            categories (list): List of category dictionaries with name and description
            
        Returns:
            dict: Categorized content with category names as keys
        """
        if not self.is_available():
            return self._fallback_categorization(text, categories)
        
        if not text.strip():
            return {}
        
        # Prepare categories for the prompt
        category_descriptions = []
        for cat in categories:
            category_descriptions.append(f"- {cat['name']}: {cat['description']}")
        
        categories_text = "\n".join(category_descriptions)
        
        # Create the prompt
        prompt = f"""
You are an AI assistant that helps organize notes by categorizing content. 

Given the following text, please categorize it into the appropriate sections. Each piece of content should go into the most suitable category.

Available categories:
{categories_text}

Text to categorize:
"{text}"

IMPORTANT CATEGORIZATION GUIDELINES:

Action Items should include:
- Tasks assigned to specific people (e.g., "John will review the code", "Sarah needs to call the client")
- Statements with deadlines or timeframes (e.g., "finish by Friday", "due next week", "by Monday")
- Commitments and responsibilities (e.g., "I will prepare the presentation", "we need to update the database")
- Todo items and follow-up actions (e.g., "need to schedule a meeting", "must complete testing")
- Any statement that indicates something needs to be done or someone will do something

Key Points should include:
- Important facts, insights, or highlights from discussions
- Decisions that were made (not actions to be taken)
- Significant information or conclusions
- Main themes or topics discussed
- Overview and summary information

Ideas should include:
- Brainstorming suggestions
- Creative concepts or proposals
- Future possibilities or considerations

References should include:
- Links, URLs, or external sources
- Documents or resources mentioned
- Contact information

Please respond with a JSON object where each category name is a key, and the value is an array of relevant content items from the text. If no content fits a category, use an empty array. Break down the text into logical chunks that fit each category.

Format your response as valid JSON only, no additional text.
"""

        try:
            # Check if we're using modern or legacy OpenAI client
            if hasattr(self.client, 'chat'):
                # Modern OpenAI client
                response = self.client.chat.completions.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that categorizes note content. Always respond with valid JSON only."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=1500,
                    temperature=0.3
                )
                content = response.choices[0].message.content.strip()
            else:
                # Legacy OpenAI client
                response = self.client.ChatCompletion.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that categorizes note content. Always respond with valid JSON only."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=1500,
                    temperature=0.3
                )
                content = response.choices[0].message.content.strip()
            
            # Parse the response
            # Try to parse as JSON
            try:
                categorized_content = json.loads(content)
                return self._format_categorized_content(categorized_content)
            except json.JSONDecodeError:
                # If JSON parsing fails, try to extract JSON from the response
                import re
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
                if json_match:
                    categorized_content = json.loads(json_match.group())
                    return self._format_categorized_content(categorized_content)
                else:
                    # Log error safely (handle missing app context)
                    error_msg = f"Failed to parse OpenAI response as JSON: {content}"
                    try:
                        current_app.logger.error(error_msg)
                    except RuntimeError:
                        print(f"AI Service Error: {error_msg}")
                    return self._fallback_categorization(text, categories)
                    
        except Exception as e:
            # Log error safely (handle missing app context)
            error_msg = f"OpenAI API error: {str(e)}"
            try:
                current_app.logger.error(error_msg)
            except RuntimeError:
                print(f"AI Service Error: {error_msg}")
            return self._fallback_categorization(text, categories)
    
    def _format_categorized_content(self, categorized_content):
        """Format the categorized content with proper structure."""
        formatted = {}
        
        for category, items in categorized_content.items():
            if isinstance(items, list):
                formatted[category] = items
            elif isinstance(items, str) and items.strip():
                formatted[category] = [items]
            else:
                formatted[category] = []
        
        return formatted
    
    def _fallback_categorization(self, text, categories):
        """Fallback categorization when AI fails."""
        # Simple keyword-based fallback with better text splitting
        fallback_result = {}
        text_lower = text.lower()
        
        # Initialize all categories
        for cat in categories:
            fallback_result[cat['name']] = []
        
        # Enhanced keyword matching for action items
        action_keywords = [
            'todo', 'task', 'action', 'need to', 'should', 'must', 'will',
            'needs to', 'has to', 'assigned to', 'responsible for', 
            'by monday', 'by tuesday', 'by wednesday', 'by thursday', 'by friday',
            'by weekend', 'next week', 'this week', 'tomorrow', 'today',
            'deadline', 'due', 'complete', 'finish', 'deliver', 'submit',
            'follow up', 'follow-up', 'call', 'email', 'contact', 'schedule',
            'prepare', 'create', 'update', 'review', 'check', 'verify'
        ]
        
        # Split text into sentences for better granularity
        import re
        
        # First, split by common sentence endings
        sentences = re.split(r'[.!?]+\s+', text.strip())
        
        # Clean up sentences and filter empty ones
        sentences = [s.strip() for s in sentences if s.strip()]
        
        # If we only got one sentence, try splitting by other delimiters
        if len(sentences) <= 1:
            # Try splitting by common separators
            sentences = re.split(r'[;\n]+', text.strip())
            sentences = [s.strip() for s in sentences if s.strip()]
        
        # If still only one item, try splitting by person names + action patterns
        if len(sentences) <= 1:
            # Look for patterns like "John will...", "Sarah needs to..."
            person_patterns = re.findall(r'[A-Z][a-z]+\s+(?:will|needs?\s+to|should|has\s+to|must|to)[^.]*', text)
            if person_patterns:
                sentences = person_patterns
            else:
                # Split by common connectors as last resort
                sentences = re.split(r'\.\s+|\s+and\s+|\s+also\s+|\s+additionally\s+', text.strip())
                sentences = [s.strip() for s in sentences if s.strip() and len(s) > 10]
        
        print(f"Fallback: Split text into {len(sentences)} sentences")
        
        # Categorize each sentence
        for sentence in sentences:
            if not sentence.strip():
                continue
                
            sentence = sentence.strip()
            sentence_lower = sentence.lower()
            
            # Check for action item patterns
            is_action_item = False
            
            # Check for simple keywords
            if any(word in sentence_lower for word in action_keywords):
                is_action_item = True
            
            # Check for person + will/needs patterns (e.g., "John will...", "Sarah needs to...")
            person_action_patterns = [
                r'\b[A-Z][a-z]+\s+will\b',  # "John will", "Sarah will"
                r'\b[A-Z][a-z]+\s+needs?\s+to\b',  # "John needs to", "Sarah need to"
                r'\b[A-Z][a-z]+\s+should\b',  # "John should", "Sarah should"
                r'\b[A-Z][a-z]+\s+has\s+to\b',  # "John has to", "Sarah has to"
                r'\b[A-Z][a-z]+\s+must\b',  # "John must", "Sarah must"
                r'\b[A-Z][a-z]+\s+to\s+\w+',  # "John to write", "Sarah to review"
            ]
            
            for pattern in person_action_patterns:
                if re.search(pattern, sentence):
                    is_action_item = True
                    break
            
            # Check for deadline patterns
            deadline_patterns = [
                r'by\s+\w+day',  # "by Monday", "by Friday"
                r'due\s+\w+',    # "due tomorrow", "due next"
                r'deadline',     # any mention of deadline
                r'finish\s+by',  # "finish by..."
                r'complete\s+by',# "complete by..."
                r'eta[:\s]+',    # "ETA: 06/10", "ETA 06/10"
            ]
            
            for pattern in deadline_patterns:
                if re.search(pattern, sentence_lower):
                    is_action_item = True
                    break
            
            # Categorize the sentence
            if is_action_item:
                fallback_result['Action Items'].append(sentence)
            elif any(word in sentence_lower for word in ['http', 'www', 'link', 'reference', 'source']):
                fallback_result['References'].append(sentence)
            elif any(word in sentence_lower for word in ['idea', 'thought', 'brainstorm', 'concept', 'option', 'exploring']):
                if 'Ideas' in fallback_result:
                    fallback_result['Ideas'].append(sentence)
                else:
                    fallback_result['Key Points'].append(sentence)
            else:
                # Default to Key Points for all other content
                fallback_result['Key Points'].append(sentence)
        
        # If no sentences were categorized but we have text, add it as Key Points
        if all(len(items) == 0 for items in fallback_result.values()) and text.strip():
            fallback_result['Key Points'] = [text.strip()]
        
        return fallback_result
    
    def suggest_title(self, text):
        """
        Suggest a title for the note based on its content.
        
        Args:
            text (str): The note content
            
        Returns:
            str: Suggested title
        """
        if not self.is_available():
            # Fallback: use first few words
            if not text.strip():
                return "Untitled Note"
            words = text.split()[:6]
            return " ".join(words) + ("..." if len(text.split()) > 6 else "")
        
        if not text.strip():
            return "Untitled Note"
        
        prompt = f"""
Based on the following text, suggest a concise and descriptive title (maximum 8 words):

"{text}"

Respond with only the title, no additional text.
"""
        
        try:
            # Check if we're using modern or legacy OpenAI client
            if hasattr(self.client, 'chat'):
                # Modern OpenAI client
                response = self.client.chat.completions.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that creates concise titles for notes."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=50,
                    temperature=0.3
                )
                title = response.choices[0].message.content.strip()
            else:
                # Legacy OpenAI client
                response = self.client.ChatCompletion.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that creates concise titles for notes."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=50,
                    temperature=0.3
                )
                title = response.choices[0].message.content.strip()
            
            # Remove quotes if present
            title = title.strip('"\'')
            
            return title[:100]  # Limit title length
            
        except Exception as e:
            # Log error safely (handle missing app context)
            error_msg = f"OpenAI API error for title suggestion: {str(e)}"
            try:
                current_app.logger.error(error_msg)
            except RuntimeError:
                print(f"AI Service Error: {error_msg}")
            # Fallback: use first few words
            words = text.split()[:6]
            return " ".join(words) + ("..." if len(text.split()) > 6 else "")

    def generate_text(self, prompt):
        """
        Generate text using OpenAI's API.
        
        Args:
            prompt (str): The prompt for text generation
            
        Returns:
            str: Generated text
        """
        if not self.is_available():
            raise Exception("AI service is not available. Please check your OpenAI API key configuration.")
        
        if not prompt.strip():
            raise Exception("Prompt cannot be empty")
        
        try:
            # Check if we're using modern or legacy OpenAI client
            if hasattr(self.client, 'chat'):
                # Modern OpenAI client
                response = self.client.chat.completions.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that organizes and summarizes content."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=2000,
                    temperature=0.5
                )
                return response.choices[0].message.content.strip()
            else:
                # Legacy OpenAI client
                response = self.client.ChatCompletion.create(
                    model="gpt-4",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that organizes and summarizes content."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=2000,
                    temperature=0.5
                )
                return response.choices[0].message.content.strip()
            
        except Exception as e:
            # Log error safely (handle missing app context)
            error_msg = f"OpenAI API error in generate_text: {str(e)}"
            try:
                current_app.logger.error(error_msg)
            except RuntimeError:
                print(f"AI Service Error: {error_msg}")
            raise Exception(f"AI text generation failed: {str(e)}")

# Global instance
ai_service = AIService() 