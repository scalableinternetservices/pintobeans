import type { ChatService } from '@/types';
import type {
  Conversation,
  CreateConversationRequest,
  UpdateConversationRequest,
  Message,
  SendMessageRequest,
  ExpertProfile,
  ExpertQueue,
  ExpertAssignment,
  UpdateExpertProfileRequest,
} from '@/types';
import TokenManager from '@/services/TokenManager';

interface ApiChatServiceConfig {
  baseUrl: string;
  timeout: number;
  retryAttempts: number;
}

/**
 * API implementation of ChatService for production use
 * Uses fetch for HTTP requests
 */
export class ApiChatService implements ChatService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: ApiChatServiceConfig) {
    this.baseUrl = config.baseUrl;
    this.tokenManager = TokenManager.getInstance();
  }

private async makeRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${this.baseUrl}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;
  const token = this.tokenManager.getToken();

  let headers: any = { 'Content-Type': 'application/json' };
  if (token) {
    headers['Authorization'] = 'Bearer ' + token;
  }
  if (options.headers) {
    for (const key in options.headers) {
      headers[key] = (options.headers as any)[key];
    }
  }

  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: headers,
    body: options.body,
    credentials: 'include',
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message =
      data?.error ||
      (Array.isArray(data?.errors) ? data.errors.join(', ') : '') ||
      `HTTP ${response.status} ${response.statusText}`;
    throw new Error(message);
  }

  return data as T;
}


  // Conversations
  async getConversations(): Promise<Conversation[]> {
    // TODO: Implement getConversations method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of conversations
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<Conversation[]>('/conversations', { method: 'GET' });
  }

  async getConversation(_id: string): Promise<Conversation> {
    // TODO: Implement getConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the conversation object
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<Conversation>(`/conversations/${_id}`, { method: 'GET' });
  }

  async createConversation(
    request: CreateConversationRequest
  ): Promise<Conversation> {
    // TODO: Implement createConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created conversation object
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<Conversation>('/conversations', {
      method: 'POST',
      body: JSON.stringify({ title: request.title }),
    });
  }

  async updateConversation(
    id: string,
    request: UpdateConversationRequest
  ): Promise<Conversation> {
    // SKIP, not currently used by application

    throw new Error('updateConversation method not implemented');
  }

  async deleteConversation(id: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('deleteConversation method not implemented');
  }

  // Messages
  async getMessages(conversationId: string): Promise<Message[]> {
    // TODO: Implement getMessages method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of messages
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<Message[]>(`/conversations/${conversationId}/messages`, {
      method: 'GET',
    });
  }

  async sendMessage(request: SendMessageRequest): Promise<Message> {
    // TODO: Implement sendMessage method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created message object
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<Message>('/messages', {
      method: 'POST',
      body: JSON.stringify({
        conversation_id: request.conversationId,
        content: request.content,
      }),
    });
  }

  async markMessageAsRead(messageId: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('markMessageAsRead method not implemented');
  }

  // Expert-specific operations
  async getExpertQueue(): Promise<ExpertQueue> {
    // TODO: Implement getExpertQueue method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert queue object with waitingConversations and assignedConversations
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<ExpertQueue>('/expert/queue', { method: 'GET' });
  }

  async claimConversation(conversationId: string): Promise<void> {
    // TODO: Implement claimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details

    await this.makeRequest(`/expert/conversations/${conversationId}/claim`, {
      method: 'POST',
    });
  }

  async unclaimConversation(conversationId: string): Promise<void> {
    // TODO: Implement unclaimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details

    await this.makeRequest(`/expert/conversations/${conversationId}/unclaim`, {
      method: 'POST',
    });
  }

  async getExpertProfile(): Promise<ExpertProfile> {
    // TODO: Implement getExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<ExpertProfile>('/expert/profile', { method: 'GET' });
  }

  async updateExpertProfile(
    request: UpdateExpertProfileRequest
  ): Promise<ExpertProfile> {
    // TODO: Implement updateExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the updated expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details

    // Convert camelCase to snake_case for Rails backend
    const snakeCaseRequest: any = {};
    if (request.bio !== undefined) snakeCaseRequest.bio = request.bio;
    if (request.knowledgeBaseLinks !== undefined) {
      snakeCaseRequest.knowledge_base_links = request.knowledgeBaseLinks;
    }
    if (request.faq !== undefined) snakeCaseRequest.faq = request.faq;

    return this.makeRequest<ExpertProfile>('/expert/profile', {
      method: 'PUT',
      body: JSON.stringify({ expert_profile: snakeCaseRequest }),
    });
  }

  async getExpertAssignmentHistory(): Promise<ExpertAssignment[]> {
    // TODO: Implement getExpertAssignmentHistory method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of expert assignments
    //
    // See API_SPECIFICATION.md for endpoint details

    return this.makeRequest<ExpertAssignment[]>('/expert/assignments/history', {
      method: 'GET',
    });
  }
}
