"""
Locust load test for chat-backend-rails application.

User personas:
1. IdleUser - Polls for updates every 5 seconds (10% of users)
2. ActiveUser - Creates conversations, sends messages, browses (70% of users)
3. ExpertUser - Responds to messages, manages queue (15% of users)
4. NewUser - Registers for the first time (5% of users)

Debug mode: Set DEBUG_MODE = True to see all HTTP requests and responses
"""

import random
import threading
from datetime import datetime
from locust import HttpUser, task, between, events


# Configuration
MAX_USERS = 10000
CONVERSATION_TOPICS = ["Technical Support", "Account Help", "Billing Question", "Feature Request", "Bug Report"]
DEBUG_MODE = True  # Set to False to reduce logging


# Debug event listeners
@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kwargs):
    if DEBUG_MODE and exception:
        print(f"REQUEST FAILED: {request_type} {name} - Exception: {exception}")


@events.request.add_listener  
def on_request_success(request_type, name, response_time, response_length, **kwargs):
    if DEBUG_MODE:
        print(f"REQUEST OK: {request_type} {name} - {response_time}ms")


class UserNameGenerator:
    """Generates deterministic but distributed usernames using prime number stepping."""
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
    """Thread-safe storage for user credentials and metadata."""
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
        try:
            with self.client.post(
                "/auth/login",
                json={
                    "user": {
                        "username": username, 
                        "password": password
                    }
                },
                name="/auth/login",
                catch_response=True
            ) as response:
                if response.status_code == 200:
                    data = response.json()
                    user_data = data.get("user", {})
                    token = data.get("token")
                    user_id = user_data.get("id")
                    
                    if not token or not user_id:
                        print(f"Login response missing token or user_id for {username}")
                        print(f"Response: {response.text[:300]}")
                        response.failure("Missing token or user_id")
                        return None
                    
                    response.success()
                    return user_store.store_user(
                        username, 
                        token, 
                        user_id,
                        user_data.get("is_expert", False)
                    )
                else:
                    # User doesn't exist yet, this is expected
                    response.failure(f"Login failed (expected for new users): {response.status_code}")
        except Exception as e:
            print(f"Login exception for {username}: {e}")
            import traceback
            traceback.print_exc()
        return None
        
    def register(self, username, password, is_expert=False):
        """Register a new user."""
        try:
            with self.client.post(
                "/auth/register",
                json={
                    "user": {
                        "username": username, 
                        "password": password,
                        "password_confirmation": password
                    }
                },
                name="/auth/register",
                catch_response=True
            ) as response:
                if response.status_code == 201 or response.status_code == 200:
                    try:
                        data = response.json()
                        user_data = data.get("user", {})
                        token = data.get("token")
                        user_id = user_data.get("id")
                        
                        if not token or not user_id:
                            print(f"Registration response missing token or user_id for {username}")
                            print(f"Response: {response.text[:300]}")
                            response.failure("Missing token or user_id")
                            return None
                        
                        response.success()
                        return user_store.store_user(
                            username, 
                            token, 
                            user_id,
                            is_expert
                        )
                    except Exception as e:
                        print(f"Registration response parsing failed for {username}: {e}")
                        print(f"Response text: {response.text[:500]}")
                        response.failure(f"Failed to parse registration response")
                else:
                    print(f"Registration failed for {username}: {response.status_code}")
                    print(f"Response body: {response.text[:500]}")
                    response.failure(f"Registration failed: {response.status_code}")
        except Exception as e:
            print(f"Registration exception for {username}: {e}")
            import traceback
            traceback.print_exc()
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
            "/api/expert-queue/updates",
            headers=auth_headers(user.get("auth_token")),
            name="/api/expert-queue/updates"
        )
        
        return response.status_code == 200

    def create_conversation(self, user, topic=None):
        """Create a new conversation."""
        response = self.client.post(
            "/conversations",
            json={
                "title": topic or random.choice(CONVERSATION_TOPICS),
                "status": "waiting"
            },
            headers=auth_headers(user.get("auth_token")),
            name="/conversations"
        )
        
        if response.status_code == 201:
            data = response.json()
            # Response is the conversation object directly (not nested under 'conversation')
            return user_store.store_conversation(
                data.get("id"),
                user.get("user_id")
            )
        else:
            if DEBUG_MODE:
                print(f"Conversation creation failed: {response.status_code}")
                print(f"Response: {response.text[:200]}")
        return None

    def send_message(self, user, conversation_id, message_text):
        """Send a message to a conversation."""
        response = self.client.post(
            "/messages",
            json={
                "conversation_id": conversation_id,
                "user_id": user.get("user_id"),
                "message": message_text
            },
            headers=auth_headers(user.get("auth_token")),
            name="/messages"
        )
        
        return response.status_code == 201

    def get_conversation_messages(self, user, conversation_id):
        """Retrieve messages from a conversation."""
        response = self.client.get(
            f"/conversations/{conversation_id}/messages",
            headers=auth_headers(user.get("auth_token")),
            name="/conversations/:id/messages"
        )
        
        return response.status_code == 200

    def list_conversations(self, user):
        """List user's conversations."""
        response = self.client.get(
            "/conversations",
            params={"userId": user.get("user_id")},
            headers=auth_headers(user.get("auth_token")),
            name="/conversations"
        )
        
        if response.status_code == 200:
            # Rails returns array directly, not nested under 'conversations'
            conversations = response.json()
            if isinstance(conversations, list):
                return conversations
            else:
                # Fallback if format is different
                return conversations.get("conversations", [])
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
        
        # Try to login first (user might already exist from previous test runs)
        try:
            self.user = self.login(username, password)
            if not self.user:
                # User doesn't exist, register them
                self.user = self.register(username, password)
            
            if not self.user:
                print(f"FAILED: Could not login or register user {username}")
                print(f"Check your backend server at the host URL")
                self.environment.runner.quit()
                return
            
            print(f"SUCCESS: IdleUser {username} ready (ID: {self.user.get('user_id')}, Token: {self.user.get('auth_token')[:20] if self.user.get('auth_token') else 'None'}...)")
        except Exception as e:
            print(f"ERROR in on_start for {username}: {str(e)}")
            import traceback
            traceback.print_exc()
            self.environment.runner.quit()

    @task
    def poll_for_updates(self):
        """Poll for all types of updates."""
        try:
            self.check_conversation_updates(self.user)
            self.check_message_updates(self.user)
            self.check_expert_queue_updates(self.user)
            self.last_check_time = datetime.utcnow()
        except Exception as e:
            print(f"ERROR in poll_for_updates: {e}")
            import traceback
            traceback.print_exc()


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
        
        try:
            # Check if user already exists in our store (from previous spawns)
            existing_user = None
            with user_store.username_lock:
                existing_user = user_store.used_usernames.get(username)
            
            if existing_user:
                # User was already registered by another instance, try login
                self.user = self.login(username, password)
            else:
                # New user, register directly without trying to login first
                self.user = self.register(username, password)
            
            # If both failed, try the other method as fallback
            if not self.user:
                if existing_user:
                    self.user = self.register(username, password)
                else:
                    self.user = self.login(username, password)
            
            if not self.user:
                print(f"FAILED: ActiveUser {username} could not authenticate")
                self.environment.runner.quit()
                return
                
            self.my_conversations = []
            print(f"SUCCESS: ActiveUser {username} ready")
        except Exception as e:
            print(f"ERROR in ActiveUser.on_start for {username}: {str(e)}")
            import traceback
            traceback.print_exc()
            self.environment.runner.quit()

    @task(5)
    def browse_conversations(self):
        """Browse and list existing conversations."""
        try:
            self.my_conversations = self.list_conversations(self.user)
        except Exception as e:
            print(f"ERROR in browse_conversations: {e}")

    @task(3)
    def create_new_conversation(self):
        """Create a new conversation with a random topic."""
        try:
            conversation = self.create_conversation(self.user)
            if conversation:
                self.my_conversations.append(conversation)
        except Exception as e:
            print(f"ERROR in create_new_conversation: {e}")

    @task(10)
    def send_message_to_conversation(self):
        """Send a message to an existing conversation."""
        try:
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
            else:
                # No conversations available, create one first
                self.create_new_conversation()
        except Exception as e:
            print(f"ERROR in send_message_to_conversation: {e}")

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
        
        try:
            # Check if expert already exists in our store
            existing_user = None
            with user_store.username_lock:
                existing_user = user_store.used_usernames.get(username)
            
            if existing_user:
                # Expert was already registered, try login
                self.user = self.login(username, password)
            else:
                # New expert, register directly
                self.user = self.register(username, password, is_expert=True)
            
            # Fallback to the other method if needed
            if not self.user:
                if existing_user:
                    self.user = self.register(username, password, is_expert=True)
                else:
                    self.user = self.login(username, password)
            
            if not self.user:
                print(f"FAILED: ExpertUser {username} could not authenticate")
                self.environment.runner.quit()
                return
                
            self.assigned_conversations = []
            print(f"SUCCESS: ExpertUser {username} ready")
        except Exception as e:
            print(f"ERROR in ExpertUser.on_start for {username}: {str(e)}")
            import traceback
            traceback.print_exc()
            self.environment.runner.quit()

    @task(8)
    def check_expert_queue(self):
        """Check for new conversations in the expert queue."""
        response = self.client.get(
            "/expert/queue",
            headers=auth_headers(self.user.get("auth_token")),
            name="/expert/queue"
        )
        return response.status_code == 200

    @task(5)
    def claim_conversation(self):
        """Claim an unassigned conversation from the queue."""
        # First get the queue to find a conversation ID
        queue_response = self.client.get(
            "/expert/queue",
            headers=auth_headers(self.user.get("auth_token")),
            name="/expert/queue [for claiming]"
        )
        
        if queue_response.status_code == 200:
            queue_data = queue_response.json()
            conversations = queue_data.get("conversations", [])
            
            if conversations:
                # Pick a random conversation to claim
                conversation = random.choice(conversations)
                conversation_id = conversation.get("id")
                
                response = self.client.post(
                    f"/expert/conversations/{conversation_id}/claim",
                    headers=auth_headers(self.user.get("auth_token")),
                    name="/expert/conversations/:id/claim"
                )
                
                if response.status_code == 200:
                    conv_data = user_store.store_conversation(
                        conversation_id,
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
        
        try:
            # NewUser always registers directly (never tries to login first)
            self.user = self.register(self.username, self.password)
            if not self.user:
                print(f"FAILED: NewUser {self.username} registration failed")
                self.environment.runner.quit()
                return
            print(f"SUCCESS: NewUser {self.username} registered")
        except Exception as e:
            print(f"ERROR in NewUser.on_start for {self.username}: {str(e)}")
            import traceback
            traceback.print_exc()
            self.environment.runner.quit()

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