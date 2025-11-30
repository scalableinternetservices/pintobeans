# Help Desk Application with AI Features

A full-stack help desk application with AI-powered features including auto-assignment, auto-response, and conversation summarization.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Project Overview](#project-overview)
- [AI Features](#ai-features)
- [Setup Guide](#setup-guide)
- [API Documentation](#api-documentation)
- [Frontend UI](#frontend-ui)
- [Implementation Details](#implementation-details)
- [Background Jobs](#background-jobs)
- [Testing](#testing)
- [Deployment](#deployment)

---

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for frontend)
- AWS credentials (optional, for real LLM features)

### Start Backend

```bash
cd help_desk_backend
docker-compose up -d
docker-compose exec web bin/rails db:create db:migrate
docker-compose exec web bin/rails server -b 0.0.0.0
```

Backend runs at: `http://localhost:3000`

### Start Frontend

```bash
cd front-end
npm install
npm run dev
```

Frontend runs at: `http://localhost:5173`

### Quick Test

1. **Register:** Create a user account
2. **Create conversation:** Start a new help request
3. **Expert features:** Login as expert to manage conversations
4. **AI features:** Add FAQ to see auto-responses, view AI summaries

---

## 📖 Project Overview

### Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   React/Vite    │ ◄─────► │   Rails API     │
│   Frontend      │   REST  │   Backend       │
└─────────────────┘         └─────────────────┘
                                    │
                            ┌───────┴────────┐
                            │                │
                     ┌──────▼─────┐   ┌─────▼──────┐
                     │   MySQL    │   │   AWS      │
                     │  Database  │   │  Bedrock   │
                     └────────────┘   └────────────┘
```

### Tech Stack

**Backend:**
- Ruby on Rails 8.1
- MySQL 8.0
- JWT Authentication
- AWS SDK for Bedrock
- Solid Queue (background jobs)

**Frontend:**
- React 18
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui components

---

## 🤖 AI Features

Three AI-powered features using Amazon Bedrock (Claude 3.5 Haiku):

### 1. Auto-Assignment of Conversations

**How it works:**
- LLM analyzes conversation title
- Matches against expert profiles/bios
- Automatically assigns to best expert
- Falls back to least-busy expert if LLM unavailable

**Example:**
```
Title: "Database connection issues"
Expert 1: "I specialize in frontend development"
Expert 2: "Backend and database specialist"
→ Assigns to Expert 2
```

### 2. Auto-Response Based on FAQ

**How it works:**
- Experts create FAQ (Question + Answer pairs)
- When user asks question, LLM matches against FAQ
- If match found, generates natural response
- Response is sent automatically from expert

**Example:**
```
FAQ:
Q: "How do I reset my password?"
A: "Click Forgot Password on login page"

User asks: "Can't remember my password"
Auto-response: "You can reset your password by clicking
               'Forgot Password' on the login page!"
```

### 3. Conversation Summarization

**How it works:**
- Analyzes first 20 messages of conversation
- Generates 2-3 sentence summary using LLM
- Cached in database for performance
- Displayed in conversation list and header

**Example:**
```
Summary: "User experiencing login issues due to forgotten
password. Expert provided password reset instructions
and verified email address."
```

### LLM Fallback Behavior

**Without AWS credentials:**
- ✅ Auto-assignment: Uses round-robin (least busy expert)
- ❌ Auto-response: Not triggered
- ✅ Summary: Uses first message truncated

**During load testing:**
- Fake responses with simulated delay (0.8-3.5s)
- Prevents API quota exhaustion
- Controlled by user agent detection

---

## 🛠️ Setup Guide

### Local Development Setup

#### 1. Copy AWS Credentials (Optional)

```bash
scp project2backend@ec2.cs291.com:~/.aws/credentials ~/.aws/credentials
```

#### 2. Configure Docker Compose

**Backend (`docker-compose.yml`):**
```yaml
services:
  web:
    environment:
      - AWS_SHARED_CREDENTIALS_FILE=/app/.aws/credentials
      - AWS_PROFILE=default
      - AWS_REGION=us-west-2
      - AWS_SDK_LOAD_CONFIG=1
      - ALLOW_BEDROCK_CALL=true
    volumes:
      - ${HOME}/.aws:/app/.aws:ro
```

#### 3. Run Database Migration

```bash
docker-compose exec web bin/rails db:migrate
```

Migration adds:
- `conversations.summary` (text) - AI-generated summaries
- `expert_profiles.faq` (json) - Expert FAQ for auto-response

#### 4. Start Services

```bash
# Backend
docker-compose up -d
docker-compose exec web bin/rails server -b 0.0.0.0

# Frontend
cd front-end
npm install
npm run dev
```

#### 5. Test LLM Features

```bash
docker-compose exec web bin/rails console
```

```ruby
# Test BedrockClient
client = BedrockClient.new(model_id: "anthropic.claude-3-5-haiku-20241022-v1:0")
response = client.call(
  system_prompt: "You are helpful",
  user_prompt: "Say hello",
  max_tokens: 20
)
puts response[:output_text]
# Real LLM: "Hello! How can I assist you today?"
# Fake mode: "This is a fake response from the LLM."
```

### AWS Credentials Configuration

**Option 1: File-based (Recommended)**
```yaml
# docker-compose.yml
environment:
  - AWS_SHARED_CREDENTIALS_FILE=/app/.aws/credentials
volumes:
  - ${HOME}/.aws:/app/.aws:ro
```

**Option 2: Environment Variables**
```yaml
# docker-compose.yml
environment:
  - AWS_ACCESS_KEY_ID=your_key_here
  - AWS_SECRET_ACCESS_KEY=your_secret_here
  - AWS_REGION=us-west-2
```

### Elastic Beanstalk Deployment

```bash
eb create helpdesk-llm-prod \
  --envvars "ALLOW_BEDROCK_CALL=true" \
  --profile eb-with-bedrock-ec2-profile \
  --instance-type t3.small

# Run migration
eb ssh
cd /var/app/current
bin/rails db:migrate RAILS_ENV=production
```

---

## 📚 API Documentation

### Base URL
```
Local: http://localhost:3000
Production: https://your-app.elasticbeanstalk.com
```

### Authentication

All endpoints (except `/auth/register` and `/auth/login`) require JWT authentication:

```http
Authorization: Bearer <jwt_token>
```

### Core Endpoints

#### Authentication

**Register**
```http
POST /auth/register
Content-Type: application/json

{
  "user": {
    "username": "john_doe",
    "password": "password123",
    "password_confirmation": "password123"
  }
}

Response 201:
{
  "user": {
    "id": "1",
    "username": "john_doe",
    "created_at": "2025-11-30T10:00:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Login**
```http
POST /auth/login
Content-Type: application/json

{
  "user": {
    "username": "john_doe",
    "password": "password123"
  }
}

Response 200:
{
  "user": { ... },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

#### Conversations

**List Conversations**
```http
GET /conversations
Authorization: Bearer <token>

Response 200:
[
  {
    "id": "1",
    "title": "Password Reset Help",
    "status": "active",
    "questionerId": "1",
    "questionerUsername": "john_doe",
    "assignedExpertId": "2",
    "assignedExpertUsername": "expert_jane",
    "createdAt": "2025-11-30T10:00:00Z",
    "updatedAt": "2025-11-30T10:30:00Z",
    "lastMessageAt": "2025-11-30T10:30:00Z",
    "unreadCount": 2,
    "summary": "User unable to reset password. Expert provided steps..."
  }
]
```

**Create Conversation**
```http
POST /conversations
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Database connection issues"
}

Response 201:
{
  "id": "2",
  "title": "Database connection issues",
  "status": "active",
  "assignedExpertId": "3",  // Auto-assigned by AI!
  ...
}
```

#### Messages

**Get Messages**
```http
GET /conversations/:conversation_id/messages
Authorization: Bearer <token>

Response 200:
[
  {
    "id": "1",
    "conversationId": "1",
    "senderId": "1",
    "senderUsername": "john_doe",
    "senderRole": "initiator",
    "content": "How do I reset my password?",
    "timestamp": "2025-11-30T10:00:00Z",
    "isRead": false
  },
  {
    "id": "2",
    "conversationId": "1",
    "senderId": "2",
    "senderUsername": "expert_jane",
    "senderRole": "expert",
    "content": "You can reset your password by...",
    "timestamp": "2025-11-30T10:01:00Z",
    "isRead": false
  }
]
```

**Send Message**
```http
POST /messages
Authorization: Bearer <token>
Content-Type: application/json

{
  "conversation_id": "1",
  "content": "How do I reset my password?"
}

Response 201:
{
  "id": "1",
  "conversationId": "1",
  "content": "How do I reset my password?",
  ...
}

Note: If expert has FAQ, auto-response may be generated within seconds!
```

#### Expert Features

**Get Expert Profile**
```http
GET /expert/profile
Authorization: Bearer <token>

Response 200:
{
  "id": "1",
  "bio": "Database and backend specialist",
  "knowledgeBaseLinks": ["https://docs.example.com"],
  "faq": [
    {
      "question": "How do I reset my password?",
      "answer": "Click Forgot Password on login page"
    }
  ]
}
```

**Update Expert Profile (with FAQ)**
```http
PUT /expert/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "expert_profile": {
    "bio": "Database and backend specialist",
    "knowledge_base_links": ["https://docs.example.com"],
    "faq": [
      {
        "question": "How do I reset my password?",
        "answer": "Click Forgot Password on login page"
      }
    ]
  }
}

Response 200:
{
  "id": "1",
  "bio": "Database and backend specialist",
  ...
}
```

**Expert Queue**
```http
GET /expert/queue
Authorization: Bearer <token>

Response 200:
{
  "waitingConversations": [
    {
      "id": "3",
      "title": "Need help with API",
      "summary": "User asking about API authentication...",
      ...
    }
  ],
  "assignedConversations": [
    {
      "id": "1",
      "title": "Password Reset Help",
      "summary": "User unable to reset password...",
      ...
    }
  ]
}
```

**Claim Conversation**
```http
POST /expert/conversations/:conversation_id/claim
Authorization: Bearer <token>

Response 200:
{
  "success": true
}
```

---

## 🎨 Frontend UI

### Summary Display

**Location 1: Conversation List (Sidebar)**
- Small gray italic text (2 lines max)
- Below conversation title
- Quick preview when scanning

**Location 2: Conversation Header**
- Blue highlighted box
- Full summary text
- Below title, above messages

### Auto-Response Indicators

**Message Styling:**
- Expert messages: Blue left border
- User messages: Plain
- Role badges: "Expert" (blue) or "User" (gray)
- AI Response: Green "🤖 AI Response" badge

**Detection:**
Messages from experts sent within 5 seconds of user message show AI badge.

### FAQ Editor

**Location:** Expert Profile → Edit mode

**Features:**
- Add/Edit/Delete FAQ items
- Question + Answer fields
- Visual "🤖 AI Auto-Response FAQ" section
- Helpful instructions
- Save together with profile

---

## 🔧 Implementation Details

### Service Architecture

```
app/services/
├── bedrock_client.rb           # AWS Bedrock API wrapper
├── expert_assignment_service.rb # Auto-assignment logic
├── auto_response_service.rb     # FAQ-based auto-response
└── conversation_summary_service.rb # Summary generation
```

### BedrockClient

```ruby
client = BedrockClient.new(
  model_id: "anthropic.claude-3-5-haiku-20241022-v1:0"
)

response = client.call(
  system_prompt: "You are helpful",
  user_prompt: "Hello",
  max_tokens: 100,
  temperature: 0.7
)
```

**Features:**
- Automatic fake responses during load testing
- Environment variable gating (`ALLOW_BEDROCK_CALL`)
- Error handling with graceful fallback
- Configurable model, temperature, max_tokens

### Expert Assignment Logic

```ruby
def assign_best_expert
  experts = User.joins(:expert_profile).includes(:expert_profile)

  return nil if experts.empty?
  return experts.first if experts.count == 1

  # Use LLM to choose best expert
  response = @bedrock_client.call(...)
  expert_number = response[:output_text].to_i

  if valid_number?(expert_number)
    experts[expert_number - 1]
  else
    # Fallback: least busy expert
    experts.min_by { |e|
      Conversation.where(assigned_expert_id: e.id, status: "active").count
    }
  end
end
```

### Auto-Response Logic

```ruby
def generate_response
  return nil unless @conversation.assigned_expert

  faq = @conversation.assigned_expert.expert_profile.faq
  return nil unless faq.present?

  # Build FAQ context
  faq_context = faq.map { |item|
    "Q: #{item['question']}\nA: #{item['answer']}"
  }.join("\n\n")

  # Ask LLM to match and rephrase
  response = @bedrock_client.call(
    system_prompt: "Rephrase FAQ answers naturally...",
    user_prompt: "User question: #{@message_content}"
  )

  return nil if response[:output_text] == "NO_ANSWER"
  response[:output_text]
end
```

### Database Schema Changes

```ruby
# Migration
add_column :conversations, :summary, :text
add_column :expert_profiles, :faq, :json
```

### Frontend State Management

**ChatContext:**
- Manages conversations, messages, expert queue
- Polling updates every 5 seconds
- Merges updates to preserve summaries

**AuthContext:**
- JWT token management
- Persists in localStorage
- Auto-refresh on mount

---

## ⚙️ Background Jobs

### Summary Generation Job

```ruby
class GenerateSummaryJob < ApplicationJob
  SYNCHRONOUS_MODE = true  # Toggle sync/async

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    return if conversation.summary.present?

    summary_service = ConversationSummaryService.new(conversation)
    summary_service.update_summary
  end
end
```

### Modes

**Synchronous (Current):**
```ruby
SYNCHRONOUS_MODE = true
```
- Blocks request but works immediately
- No background worker needed
- Good for development

**Asynchronous:**
```ruby
SYNCHRONOUS_MODE = false
```
- Requires Solid Queue worker
- Non-blocking, better performance
- Good for production

### Running Workers

**Add to docker-compose.yml:**
```yaml
worker:
  build:
    context: .
    dockerfile: Dockerfile
  environment:
    # Same as web service
  command: bundle exec rake solid_queue:start
```

**Check job status:**
```ruby
SolidQueue::Job.pending.count
SolidQueue::Job.failed.count
```

---

## 🧪 Testing

### Backend Tests

```bash
docker-compose exec web bin/rails test

# Specific tests
docker-compose exec web bin/rails test test/controllers/conversations_controller_test.rb
docker-compose exec web bin/rails test test/controllers/messages_controller_test.rb
```

### Test LLM Features

```ruby
# Mock LLM in tests
BedrockClient.any_instance.stubs(:call).returns({
  output_text: "Test response",
  raw_response: nil
})
```

### Manual Testing

```ruby
# Rails console
docker-compose exec web bin/rails console

# Test auto-assignment
conversation = Conversation.create!(
  title: "Medical question",
  initiator: User.first
)
# Should auto-assign to doctor

# Test auto-response
expert = User.find_by(username: "doctor")
expert.expert_profile.update!(
  faq: [{
    question: "How to reset password?",
    answer: "Click Forgot Password"
  }]
)

Message.create!(
  conversation: conversation,
  sender: conversation.initiator,
  sender_role: "initiator",
  content: "How do I reset my password?"
)
# Auto-response should be created

# Test summary
GenerateSummaryJob.perform_now(conversation.id)
conversation.reload.summary
# Should show AI-generated summary
```

---

## 🚢 Deployment

### Elastic Beanstalk

**Create environment with Bedrock access:**
```bash
eb create helpdesk-prod \
  --envvars "ALLOW_BEDROCK_CALL=true,SECRET_KEY_BASE=$(rails secret)" \
  --profile eb-with-bedrock-ec2-profile \
  --instance-type t3.small \
  --database.engine mysql \
  --database.username admin \
  --database.password yourpassword
```

**Run migrations:**
```bash
eb ssh
cd /var/app/current
bin/rails db:migrate RAILS_ENV=production
```

**Environment variables:**
```
ALLOW_BEDROCK_CALL=true
SECRET_KEY_BASE=<generate with: rails secret>
AWS_REGION=us-west-2
RAILS_ENV=production
```

### Docker Production

```bash
docker-compose -f docker-compose.prod.yml up -d
```

---

## 🐛 Troubleshooting

### LLM Not Working

**Check credentials:**
```bash
docker-compose exec web cat /app/.aws/credentials
```

**Check environment:**
```bash
docker-compose exec web env | grep ALLOW_BEDROCK_CALL
# Should output: ALLOW_BEDROCK_CALL=true
```

**Test directly:**
```ruby
client = BedrockClient.new(model_id: "anthropic.claude-3-5-haiku-20241022-v1:0")
client.send(:should_fake_llm_call?)
# Should return: false (for real calls)
```

### Summary Disappearing

**Fixed in latest version!** Summaries now persist across polling updates.

**Manual fix if needed:**
```ruby
conversation = Conversation.find(id)
conversation.update(summary: nil)
GenerateSummaryJob.perform_now(conversation.id)
```

### Session/Auth Issues

**Fixed in latest version!** Tokens now persist in localStorage.

**Clear old tokens:**
```javascript
// Browser console
localStorage.clear()
```

### Auto-Response Not Natural

**Check prompt configuration in:**
`app/services/auto_response_service.rb`

Temperature should be 0.3 for consistent, focused responses.

---

## 📊 Performance Considerations

### Expected Latency Impact

- **Auto-assignment:** +1-3 seconds per conversation creation
- **Auto-response:** +1-3 seconds per message (when FAQ exists)
- **Summary:** +1-3 seconds on first view (then cached)

### During Load Testing

- Automatic fake responses (0.8-3.5s simulated)
- No real API calls
- No cost impact

### Cost Estimate

**Claude 3.5 Haiku pricing:**
- Input: $0.25 per million tokens
- Output: $1.25 per million tokens

**Typical usage (100 conversations/day):**
- ~$0.075/day
- ~$2.25/month

---

## 👥 Contributors

- **Backend:** Che, Katie
- **AI Features:** Implemented for Project 5
- **Frontend:** React/TypeScript implementation

---

## 📝 License

[Add your license here]

---

## 🔗 Additional Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude 3.5 Model Details](https://www.anthropic.com/claude)
- [Rails 8.1 Guides](https://guides.rubyonrails.org/)
- [React Documentation](https://react.dev/)

---

**Last Updated:** November 30, 2025

For questions or issues, please open a GitHub issue or contact the development team.

