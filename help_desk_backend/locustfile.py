"""
Locust load test for chat-backend-rails application.

User personas:
1. IdleUser - Polls for updates every 5 seconds (10% of users)
2. ActiveUser - Creates conversations, sends messages, browses (70% of users)
3. ExpertUser - Responds to messages, manages queue (15% of users)
4. NewUser - Registers for the first time (5% of users)
"""

import random
import threading
from datetime import datetime
from locust import HttpUser, task, between


# Configuration
MAX_USERS = 10000
CONVERSATION_TOPICS = ["Technical Support", "Account Help", "Billing Question", "Feature Request", "Bug Report"]


class UserNameGenerator:
    PRIME_NUMBERS = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]

    def __init__(self, max_users=MAX_USERS, seed=None, prime_number=None):
        self.seed = seed or random.randint(0, max_users)
        self.prime_number = prime_number or random.choice(self.PRIME_NUMBERS)
        self.current_index = -1
        self.max_users = max_users
    
    def generate_username(self):
        self.current_index += 1
        return f"user_{(self.seed + self.current_index * self.prime_number) % self.max_users}"


class UserStore:
    def __init__(self):
        self.used_usernames = {}
        self.expert_usernames = {}
        self.conversations = {}
        self.username_lock = threading.Lock()

    def get_random_user(self):
        with self.username_lock:
            if not self.used_usernames:
                return None
            random_username = random.choice(list(self.used_usernames.keys()))
            return self.used_usernames[random_username]

    def get_random_expert(self):
        with self.username_lock:
            if not self.expert_usernames:
                return None
            random_username = random.choice(list(self.expert_usernames.keys()))
            return self.expert_usernames[random_username]

    def store_user(self, username, auth_token, user_id, is_expert=False):
        with self.username_lock:
            user_data = {
                "username": username,
                "auth_token": auth_token,
                "user_id": user_id,
                "is_expert": is_expert
            }
            self.used_usernames[username] = user_data
            if is_expert:
                self.expert_usernames[username] = user_data
            return user_data

    def store_conversation(self, conversation_id, user_id, expert_id=None):
        with self.username_lock:
            self.conversations[conversation_id] = {
                "id": conversation_id,
                "user_id": user_id,
                "expert_id": expert_id,
                "message_count": 0
            }
            return self.conversations[conversation_id]

    def get_random_conversation(self, user_id=None):
        with self.username_lock:
            if not self.conversations:
                return None
            if user_id:
                user_convos = [c for c in self.conversations.values() if c["user_id"] == user_id]
                return random.choice(user_convos) if user_convos else None
            return random.choice(list(self.conversations.values()))


def auth_headers(token):
    """Helper function to create authorization headers."""
    return {"Authorization": f"Bearer {token}"}


# Global shared instances
user_store = UserStore()
user_name_generator = UserNameGenerator(max_users=MAX_USERS)


class ChatBackend:
    """
    Base class for all user personas.
    Provides common authentication and API interaction methods.
    """
    
    def login(self, username, password):
        """Login an existing user."""
        response = self.client.post(
            "/auth/login",
            json={"username": username, "password": password},
            name="/auth/login"
        )
        if response.status_code == 200:
            data = response.json()
            user_data = data.get("user", {})
            return user_store.store_user(
                username, 
                data.get("token"), 
                user_data.get("id"),
                user_data.get("is_expert", False)
            )
        return None
        
    def register(self, username, password, is_expert=False):
        """Register a new user."""
        response = self.client.post(
            "/auth/register",
            json={
                "username": username, 
                "password": password,
                "email": f"{username}@loadtest.com",
                "is_expert": is_expert
            },
            name="/auth/register"
        )
        if response.status_code == 201:
            data = response.json()
            user_data = data.get("user", {})
            return user_store.store_user(
                username, 
                data.get("token"), 
                user_data.get("id"),
                is_expert
            )
        return None

    def check_conversation_updates(self, user):
        """Check for conversation updates."""
        params = {"userId": user.get("user_id")}
        if hasattr(self, 'last_check_time') and self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        
        response = self.client.get(
            "/api/conversations/updates",
            params=params,
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations/updates"
        )
        
        return response.status_code == 200
    
    def check_message_updates(self, user):
        """Check for new messages in user's conversations."""
        params = {"userId": user.get("user_id")}
        if hasattr(self, 'last_check_time') and self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        
        response = self.client.get(
            "/api/messages/updates",
            params=params,
            headers=auth_headers(user.get("auth_token")),
            name="/api/messages/updates"
        )
        
        return response.status_code == 200
    
    def check_expert_queue_updates(self, user):
        """Check for updates in expert queue."""
        if not user.get("is_expert"):
            return True  # Skip for non-experts
            
        response = self.client.get(
            "/api/expert/queue",
            headers=auth_headers(user.get("auth_token")),
            name="/api/expert/queue"
        )
        
        return response.status_code == 200

    def create_conversation(self, user, topic=None):
        """Create a new conversation."""
        response = self.client.post(
            "/api/conversations",
            json={
                "user_id": user.get("user_id"),
                "topic": topic or random.choice(CONVERSATION_TOPICS)
            },
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations"
        )
        
        if response.status_code == 201:
            data = response.json()
            conversation = data.get("conversation", {})
            return user_store.store_conversation(
                conversation.get("id"),
                user.get("user_id")
            )
        return None

    def send_message(self, user, conversation_id, message_text):
        """Send a message to a conversation."""
        response = self.client.post(
            f"/api/conversations/{conversation_id}/messages",
            json={
                "user_id": user.get("user_id"),
                "message": message_text
            },
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations/:id/messages"
        )
        
        return response.status_code == 201

    def get_conversation_messages(self, user, conversation_id):
        """Retrieve messages from a conversation."""
        response = self.client.get(
            f"/api/conversations/{conversation_id}/messages",
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations/:id/messages [GET]"
        )
        
        return response.status_code == 200

    def list_conversations(self, user):
        """List user's conversations."""
        response = self.client.get(
            "/api/conversations",
            params={"userId": user.get("user_id")},
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations [LIST]"
        )
        
        if response.status_code == 200:
            return response.json().get("conversations", [])
        return []


class IdleUser(HttpUser, ChatBackend):
    """
    Persona: A user that logs in and is idle but their browser polls for updates.
    Checks for message updates, conversation updates, and expert queue updates every 5 seconds.
    Weight: 10% of users
    """
    weight = 10
    wait_time = between(5, 5)  # Check every 5 seconds

    def on_start(self):
        """Called when a simulated user starts."""
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        if not self.user:
            raise Exception(f"Failed to login or register user {username}")

    @task
    def poll_for_updates(self):
        """Poll for all types of updates."""
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.check_expert_queue_updates(self.user)
        self.last_check_time = datetime.utcnow()


class ActiveUser(HttpUser, ChatBackend):
    """
    Persona: An active user who creates conversations, sends messages, and browses.
    Simulates realistic user behavior with varied actions.
    Weight: 70% of users
    """
    weight = 70
    wait_time = between(2, 10)  # Variable wait time for realistic behavior

    def on_start(self):
        """Called when a simulated user starts."""
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        if not self.user:
            raise Exception(f"Failed to login or register user {username}")
        self.my_conversations = []

    @task(5)
    def browse_conversations(self):
        """Browse and list existing conversations."""
        self.my_conversations = self.list_conversations(self.user)

    @task(3)
    def create_new_conversation(self):
        """Create a new conversation with a random topic."""
        conversation = self.create_conversation(self.user)
        if conversation:
            self.my_conversations.append(conversation)

    @task(10)
    def send_message_to_conversation(self):
        """Send a message to an existing conversation."""
        # Try to use own conversation first, fallback to any conversation
        conversation = user_store.get_random_conversation(self.user.get("user_id"))
        if not conversation and self.my_conversations:
            conversation = random.choice(self.my_conversations)
        
        if conversation:
            messages = [
                "Hi, I need help with my account",
                "Can you assist me with this issue?",
                "Thank you for your help",
                "I'm experiencing a problem",
                "Could you clarify this for me?",
                "This is urgent, please respond",
                "I have a follow-up question"
            ]
            self.send_message(self.user, conversation.get("id"), random.choice(messages))

    @task(7)
    def read_messages(self):
        """Read messages from a conversation."""
        conversation = user_store.get_random_conversation(self.user.get("user_id"))
        if not conversation and self.my_conversations:
            conversation = random.choice(self.my_conversations)
            
        if conversation:
            self.get_conversation_messages(self.user, conversation.get("id"))

    @task(2)
    def check_updates(self):
        """Periodically check for updates."""
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.last_check_time = datetime.utcnow()


class ExpertUser(HttpUser, ChatBackend):
    """
    Persona: An expert who responds to user messages and manages their queue.
    Simulates expert behavior including queue management and response patterns.
    Weight: 15% of users
    """
    weight = 15
    wait_time = between(3, 8)  # Experts respond relatively quickly

    def on_start(self):
        """Called when a simulated expert starts."""
        self.last_check_time = None
        username = f"expert_{user_name_generator.generate_username()}"
        password = username
        self.user = self.login(username, password) or self.register(username, password, is_expert=True)
        if not self.user:
            raise Exception(f"Failed to login or register expert {username}")
        self.assigned_conversations = []

    @task(8)
    def check_expert_queue(self):
        """Check for new conversations in the expert queue."""
        self.check_expert_queue_updates(self.user)

    @task(5)
    def claim_conversation(self):
        """Claim an unassigned conversation from the queue."""
        response = self.client.post(
            "/api/expert/queue/claim",
            headers=auth_headers(self.user.get("auth_token")),
            name="/api/expert/queue/claim"
        )
        
        if response.status_code == 200:
            data = response.json()
            conversation = data.get("conversation", {})
            if conversation:
                conv_data = user_store.store_conversation(
                    conversation.get("id"),
                    conversation.get("user_id"),
                    self.user.get("user_id")
                )
                self.assigned_conversations.append(conv_data)

    @task(10)
    def respond_to_message(self):
        """Respond to a user message in assigned conversations."""
        # Get a conversation assigned to this expert
        conversation = None
        if self.assigned_conversations:
            conversation = random.choice(self.assigned_conversations)
        else:
            # Try to get any conversation from the store
            conversation = user_store.get_random_conversation()
        
        if conversation:
            expert_responses = [
                "Thank you for reaching out. I'm here to help.",
                "I understand your concern. Let me look into this.",
                "That's a great question. Here's what I recommend...",
                "I've reviewed your account and here's what I found...",
                "Let me assist you with that right away.",
                "I can definitely help you resolve this issue.",
                "That should be fixed now. Please let me know if you need anything else."
            ]
            self.send_message(self.user, conversation.get("id"), random.choice(expert_responses))

    @task(3)
    def review_conversation_history(self):
        """Review messages in assigned conversations."""
        if self.assigned_conversations:
            conversation = random.choice(self.assigned_conversations)
            self.get_conversation_messages(self.user, conversation.get("id"))

    @task(2)
    def check_updates(self):
        """Check for updates across all assigned conversations."""
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.last_check_time = datetime.utcnow()


class NewUser(HttpUser, ChatBackend):
    """
    Persona: A brand new user registering and exploring the platform.
    Simulates onboarding flow and initial user actions.
    Weight: 5% of users
    """
    weight = 5
    wait_time = between(1, 5)

    def on_start(self):
        """Register a completely new user."""
        self.username = f"new_{user_name_generator.generate_username()}"
        self.password = self.username
        self.user = self.register(self.username, self.password)
        if not self.user:
            raise Exception(f"Failed to register new user {self.username}")

    @task(1)
    def onboarding_flow(self):
        """Simulate a complete onboarding experience."""
        # Create first conversation
        conversation = self.create_conversation(self.user, "Getting Started")
        
        if conversation:
            # Send initial message
            self.send_message(
                self.user, 
                conversation.get("id"), 
                "Hi, I'm new here. How does this work?"
            )
            
            # Browse available conversations
            self.list_conversations(self.user)
            
            # Check for responses
            self.check_message_updates(self.user)
            
        # After onboarding, stop this user (they become regular users)
        self.stop()